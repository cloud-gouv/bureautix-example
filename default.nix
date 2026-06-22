# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs { config.allowUnfree = true; },
  lib ? pkgs.lib,
  # Use this input to co-develop Securix.
  securixSrc ? sources.securix,
  # TODO: this will disappear once we use mDNS for netboot.
  netbootIP ? "169.254.1.1",
}:
let
  inherit (lib)
    concatStringsSep
    filter
    attrNames
    mapAttrs'
    isFunction
    nameValuePair
    removeSuffix
    mapAttrs
    ;

  defaultEdition = "acmecorp-bureautix";

  securix = import securixSrc {
    edition = defaultEdition;
    defaultTags = [ defaultEdition ];
    inherit pkgs;
    # We override to use our own Disko which contains a patch for the office_v1 layout.
    sourcesOverrides =
      sources':
      sources'
      // {
        inherit (sources) disko;
      };
  };

  # Default system closure
  # This is the system that gets installed by default automatically without any user customization.
  defaultSystem = securix.lib.mkTerminal {
    name = "default";
    edition = defaultEdition;
    userSpecificModule = { };
    vpnProfiles = { };
    modules = [
      ./common
      {
        securix = {
          self = {
            mainDisk = "/dev/nvme0n1";
            machine = {
              hardwareSKU = "x280";
              serialNumber = "000000";
            };
          };
          graphical-interface.variant = "kde";
        };
      }
    ];
  };

  # CI workflows
  nix-reuse = ((import sources.nix-reuse { }).override { input = _: { nixpkgs = pkgs; }; }).output;
  nix-actions = import sources.nix-actions { inherit pkgs; };

  git-checks = (import sources.git-hooks).run {
    src = ./.;

    hooks = {
      statix = {
        enable = true;
        stages = [ "pre-push" ];
        settings.ignore = [
          "**/npins/*"
        ];
      };

      nixfmt-rfc-style = {
        enable = true;
        stages = [ "pre-push" ];
        package = pkgs.nixfmt-rfc-style;
      };

      reuse = nix-reuse.gitHook { };
    };
  };

  reuse = nix-reuse.run {
    defaultLicense = "MIT";
    defaultCopyright = "Sécurix project authors";

    downloadLicenses = true;
    generatedPaths = [
      "**/.envrc"
      ".gitignore"
      "REUSE.toml"
      "shell.nix"
      "treefmt.toml"

      ".github/workflows/*"
      "**/npins/*"
    ];
  };

  workflows = nix-actions.install {
    src = ./.;
    platform = "github";

    workflows = mapAttrs' (
      name: _:
      nameValuePair (removeSuffix ".nix" name) (
        let
          w = import ./workflows/${name};
          args = {
            inherit nix-actions;
            inherit (pkgs) lib;
          };
        in
        if (isFunction w) then (w args) else w
      )
    ) (builtins.readDir ./workflows);
  };

  preprovisionOptions = {
    secureBoot = "self-contained";
    tpm2HostKeys = true;
    ageHostKeys = true;
  };
in
rec {
  # Generic installer for any laptops.
  # There's a netboot installer, see `netboot/README.md` for documentation.
  # There's an USB generic installer that will install a default system.

  net-installer = securix.lib.buildNetbootInstaller {
    # This is the system model that is used for the partitioning.
    # We only want to extract the formatting and mounting script, we should not take MORE than that with us.
    baseModules = defaultSystem.partitioningModules ++ [
      {
        securix = {
          self.mainDisk = "/dev/nvme0n1";
          filesystems.layout = "office_v1";
        };
      }
    ];

    inherit preprovisionOptions;
    postInstallScript = ''
      # We will submit to a Grist form various information about the system to automatically fill the inventory after installation.
      # An admin will validate or throwaway the registration.
      (
        box_message "Submitting data about this installation to the inventory system..."
        GRIST_FORM_URI="https://grist.lahfa.xyz/o/lahfa/api/s/duF8dgSMH3PiHRdnEJqKHn/tables/Test_inventory/records?utm_source=bureautix-install"
        SERIAL_NUMBER=$(${pkgs.dmidecode}/bin/dmidecode -s system-serial-number)
        AGE_PUBLIC_KEY=$(cat /mnt/etc/ssh/ssh_host_ed25519_key.pub)
        TPM2_PUBLIC_KEY=$(cat /mnt/etc/ssh/ssh_tpm_host_ecdsa_key.pub)
        json_data='{
          "records": [{
            "fields": {
              "Serial_number": "'"$SERIAL_NUMBER"'",
              "Age_public_key": "'"$AGE_PUBLIC_KEY"'",
              "TPM2_public_key": "'"$TPM2_PUBLIC_KEY"'"
            }
          }]
        }'

        curl -X POST \
          "$GRIST_FORM_URI" \
          -H "Content-Type: application/json" \
          -d "$json_data"
        log_info "Submitted data about this installation to the inventory system."
      )
    '';
    extraInstallerModules = [
      "${sources.snowboot}/nix-modules/fetch-system-from-binary-cache.nix"
      {
        boot = {
          initrd = {
            availableKernelModules = [
              "cdc_ncm"
              "virtio-pci"
              "virtio-net"
            ];
            systemd.enable = true;
          };
          snowboot.fetch-system-from-binary-cache.enable = true;
        };
        # Use mDNS here instead.
        nix.settings.substituters = lib.mkForce [ "http://${netbootIP}:8000?trusted=1" ];
        fileSystems."/" = {
          fsType = "tmpfs";
          device = "tmpfs";
          options = [ "mode=0755" ];
        };

        networking.hostName = "netboot-installer-v1";
        environment.systemPackages = [
          (pkgs.writers.writePython3Bin "nixos-installer" {
            flakeIgnore = [
              "E501"
              "E302"
              "E305"
              "E124"
              "E265"
              "E303"
            ];
          } ./pkgs/nixos-installer/installer.py)
        ];
      }
    ];
    # NOTE: `unsafeDiscardStringContext` is used here to avoid to bring with us the full default system toplevel.
    # On a netboot system, you live in RAM and if your default system contains a bunch of things, you can saturate the RAM during the installation.
    # This is not a problem on a USB stick.
    installScript = ''
      nixos-installer --toplevel-registry-uri http://${netbootIP}:8000/snowboot/toplevel/toplevels --default-toplevel ${builtins.unsafeDiscardStringContext defaultSystem.system.toplevel}
    '';
  };

  usb-installer = securix.lib.buildUSBInstallerISO {
    # We can include the whole default system in the USB stick to accelerate installation.
    inherit (defaultSystem) modules;

    extraInstallerModules = [
      {
        networking.hostName = "generic-installer-v1";
        environment.systemPackages = [
          (pkgs.writers.writePython3Bin "nixos-installer" {
            flakeIgnore = [
              "E501"
              "E302"
              "E305"
              "E124"
              "E265"
              "E303"
            ];
          } ./pkgs/nixos-installer/installer.py)
        ];
      }
    ];
    installScript = ''
      nixos-installer --default-toplevel ${defaultSystem.system.toplevel}
    '';
  };

  # { <serial number1>, <serial number2>, ... }
  terminals = mapAttrs (
    serial:
    { machineModule, userModules }:
    securix.lib.mkTerminal {
      name = serial;
      userSpecificModule = { };
      vpnProfiles = { };
      modules = [
        machineModule
        ./common
      ]
      ++ userModules;
    }
  ) (securix.lib.readInventory2 { dir = ./inventory; });

  # Toplevel registry:
  # iterate over all terminals and perform: $serial  $toplevel generation.
  # This builds ALL system configurations.
  toplevelRegistry =
    let
      toplevels = map (serial: "${serial} ${terminals.${serial}.system.config.system.build.toplevel}") (
        attrNames terminals
      );
    in
    pkgs.writeText "toplevels" (concatStringsSep "\n" toplevels);

  shell = pkgs.mkShell {
    # Inspired by DGNum's infrastructure.
    shellHook = builtins.concatStringsSep "\n" [
      git-checks.shellHook
      reuse.shellHook
      workflows.shellHook
      "unset shellHook # do not contaminate nested shells"
    ];
    preferLocalBuild = true;
    packages = [
      pkgs.treefmt
      pkgs.nixfmt-rfc-style
      pkgs.npins
      pkgs.reuse
    ];
  };
}

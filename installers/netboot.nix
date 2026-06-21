# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

# There's a netboot installer, see `netboot/README.md` for documentation.
{ lib, pkgs, sources, securix, defaultSystem, netbootIP, ... }:

securix.lib.buildNetbootInstaller {
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
        } ../pkgs/nixos-installer/installer.py)
      ];
    }
  ];
  # NOTE: `unsafeDiscardStringContext` is used here to avoid to bring with us the full default system toplevel.
  # On a netboot system, you live in RAM and if your default system contains a bunch of things, you can saturate the RAM during the installation.
  # This is not a problem on a USB stick.
  installScript = ''
    nixos-installer --toplevel-registry-uri http://${netbootIP}:8000/snowboot/toplevel/toplevels --default-toplevel ${builtins.unsafeDiscardStringContext defaultSystem.system.toplevel}
  '';
}

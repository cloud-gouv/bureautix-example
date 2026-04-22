# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
# SPDX-FileContributor: 2026 Mattias Kockum <mattias@kockum.net>
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
    filter
    mapAttrs'
    isFunction
    nameValuePair
    removeSuffix
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

  moduleArgs = {
    inherit
      sources
      pkgs
      lib
      securix
      defaultSystem
      netbootIP
      ;
  };

  installers = import ./installers moduleArgs;
  registry = import ./registry moduleArgs;
in
rec {
  inherit (installers) net-installer usb-installer;
  inherit (registry) terminals toplevelRegistry;

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

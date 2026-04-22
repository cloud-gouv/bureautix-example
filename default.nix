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
  dev = import ./dev moduleArgs;
in
rec {
  inherit (installers) net-installer usb-installer;
  inherit (registry) terminals toplevelRegistry;
  inherit (dev) shell;
}

# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ lib, pkgs, securix, ... }:
let
  inherit (lib) mapAttrs attrNames;
  inherit (builtins) concatStringsSep;

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
        ../common
      ]
      ++ userModules;
    }
  ) (securix.lib.readInventory2 { dir = ../inventory; });

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
in
{
  inherit terminals toplevelRegistry;
}

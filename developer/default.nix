# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT
{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.bureautix.developer.enable = mkEnableOption "the developer profile";

  imports = [
    # This allows a developer to spawn his own virtual machines and do his own things.
    ./virtualisation.nix
  ];
}

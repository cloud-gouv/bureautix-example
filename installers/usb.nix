# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

# There's an USB generic installer that will install a default system.
{ pkgs, securix, defaultSystem, ... }:

securix.lib.buildUSBInstallerISO {
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
        } ../pkgs/nixos-installer/installer.py)
      ];
    }
  ];
  installScript = ''
    nixos-installer --default-toplevel ${defaultSystem.system.toplevel}
  '';
}

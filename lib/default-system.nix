# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

# Default system closure
# This is the system that gets installed by default automatically without any user customization.
{ securix, defaultEdition }:

securix.lib.mkTerminal {
  name = "default";
  edition = defaultEdition;
  userSpecificModule = { };
  vpnProfiles = { };
  modules = [
    ../common
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
}

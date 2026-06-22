# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  securix = {
    self.mainDisk = "/dev/nvme0n1";
    self.machine = {
      hardwareSKU = "x280"; # It's actually a VM.
      serialNumber = "PCALICE01";

      users = [
        "alice"
      ];
    };

    graphical-interface.variant = "cinnamon";
  };
}

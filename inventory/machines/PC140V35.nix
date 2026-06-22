# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  securix.self.mainDisk = "/dev/nvme0n1";
  securix.self.machine = {
    hardwareSKU = "x280";
    serialNumber = "PC140V35";

    users = [
      "heloise"
    ];
  };

  bureautix.developer.enable = true;
}

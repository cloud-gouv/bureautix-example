# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  securix.superadmins = {
    enable = true;
    keys = [ ];
  };

  # root has no password, remote access goes through the SSH keys above.
  users.users.root.hashedPassword = "!";
}

# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
# SPDX-FileContributor: 2026 Mattias Kockum <mattias@kockum.net>
#
# SPDX-License-Identifier: MIT

# Generic installer for any laptops.
args:
{
  net-installer = import ./netboot.nix args;
  usb-installer = import ./usb.nix args;
}

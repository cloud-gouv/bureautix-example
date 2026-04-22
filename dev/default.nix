# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
# SPDX-FileContributor: 2026 Mattias Kockum <mattias@kockum.net>
#
# SPDX-License-Identifier: MIT

args:
let
  ci = import ./ci.nix args;
in
{
  shell = import ./shell.nix (args // { inherit ci; });
}

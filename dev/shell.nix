# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ pkgs, ci, ... }:
pkgs.mkShell {
  # Inspired by DGNum's infrastructure.
  shellHook = builtins.concatStringsSep "\n" [
    ci.git-checks.shellHook
    ci.reuse.shellHook
    ci.workflows.shellHook
    "unset shellHook # do not contaminate nested shells"
  ];
  preferLocalBuild = true;
  packages = [
    pkgs.treefmt
    pkgs.nixfmt-rfc-style
    pkgs.npins
    pkgs.reuse
  ];
}

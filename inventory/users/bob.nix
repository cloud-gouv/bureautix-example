# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ pkgs, ... }:
{
  securix.self.user = {
    email = "bob@example.com";
    username = "bob";
    # Generated with pamu2fcfg --appid pam://bureautix-exemple --origin pam://bureautix-exemple --nouser
    u2f_keys = [ ];
    defaultLoginShell = pkgs.zsh;
  };
}

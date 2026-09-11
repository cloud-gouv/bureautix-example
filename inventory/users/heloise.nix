# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ pkgs, ... }:
{
  securix.self.user = {
    email = "heloise@example.com";
    username = "heloise";
    # Generated with pamu2fcfg --appid pam://bureautix-exemple --origin pam://bureautix-exemple --nouser
    u2f_keys = [ ];
    defaultLoginShell = pkgs.zsh;
  };
}

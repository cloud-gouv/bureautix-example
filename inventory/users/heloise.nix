# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ pkgs, ... }:
{
  securix.self.user = {
    email = "heloise@example.com";
    username = "heloise";
    # password is `test`
    hashedPassword = "$y$j9T$zk4xGLyshz7RzqnMX6M8O0$AybRelILMkQSWcQZV4s.ykRNi/UlgaCUaDwdee0n7N2";
    defaultLoginShell = pkgs.zsh;

    teams = [ "engineering" ];
  };
}

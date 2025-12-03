# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{
  pkgs ? import <nixpkgs> { },
}:
let
  generatedPixieScript = ''
    #!ipxe

    isset ''${ip} && goto netup

    :netup
    echo Network up with IP ''${ip}

    :menu
    menu Development boot menu
    item local          Boot from local disk
    item net_installer  Boot from network installer
    item shell          Enter into iPXE shell
    choose --timeout 5000 --default net_installer selected || goto menu

    goto ''${selected}

    :local
    exit

    :net_installer
    chain http://''${next-server}:8000/snowboot/toplevel/installer/boot.ipxe || shell

    :shell
    shell

    :failed
    echo Boot failed, going to menu again.
    goto menu
  '';
in
{
  pixiecore-response = pkgs.writeText "pixiecore.json" ''
    ${builtins.toJSON {
      message = "Welcome to snowboot-pixiecored";
      ipxe-script = generatedPixieScript;
    }}
  '';

  ipxe = pkgs.ipxe.override { };
  pixiecore = pkgs.pixiecore.override {
  };

  shell = pkgs.mkShell {
    packages = [
      pkgs.dnsmasq
      pkgs.harmonia
      pkgs.caddy
      pkgs.hivemind
    ];
  };
}

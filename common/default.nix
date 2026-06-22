# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ lib, ... }:
{
  imports = [
    # Filesystem configuration
    # This is a generic BTRFS system with 3 subvolumes:
    # - /home, /nix, /var.
    # It automatically configures unlocking the LUKS partition using FIDO2.
    # The swap is automatically encrypted at boot.
    ./filesystems.nix

    # Enable remote access for super administrators, this is useful for remote assistance.
    # This is highly privileged operation.
    ./superadmins.nix

    # Bureautix makes use of PAM U2F.
    ./pam_u2f.nix

    # Normal IT staff accounts.
    ./admins.nix

    # Automatic known hosts, e.g. GitHub.
    # You can add your certificate authorities here.
    ./known-hosts.nix

    # Generic office programs.
    ./tools.nix

    # Browser customization to put your bookmarks and so on.
    ./browser.nix

    # Printers
    ./printing.nix

    # Laptop: power optimizations, etc.
    ./laptop.nix

    # Allow the developer profile which is disabled by default.
    ../developer
  ];

  securix.self.machine = {
    # If you make use of the Securix built-in auto-update mechanism
    # This will store your own "bureautix-example" repository in /etc/bureautix.
    infraRepositoryPath = "/etc/bureautix";

    # Specify this if the definition of your systems lives in a sub directory of
    # your repository.
    # This is helpful if your definitions lives in a mono-repository.
    infraRepositorySubdir = "";
  };

  # It's mostly meant for French audiences, you can adapt
  # Better: you can let users override it!
  i18n.defaultLocale = lib.mkDefault "fr_FR.UTF-8";
  console = {
    keyMap = lib.mkDefault "fr";
  };

  # By default, Securix supports mostly KDE Plasma 6.
  # You can extend here to add more graphical interfaces.
  securix.graphical-interface = {
    variant = "kde";
    terminalVariant = "kitty";
  };
}

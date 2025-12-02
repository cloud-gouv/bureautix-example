# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

{ mkPlasmaLookAndFeelPackage }:
{
  example = mkPlasmaLookAndFeelPackage {
    name = "Example";
    version = "0.01";

    metadata = {
      id = "org.acmecorp.example";
      description = "Example - Example theme based on Breeze Light";

      # Credits:
      #
      # Wallpaper comes from https://unsplash.com/fr/@bernardhermant
      # https://unsplash.com/fr/photos/un-mur-blanc-avec-une-horloge-sur-le-cote-0D5KCGpz-_4
      # Icon comes from freepik.com

      authors = {
        rlahfa = {
          name = "Ryan Lahfa";
          email = "ryan.lahfa.ext@numerique.gouv.fr";
        };
      };

      # https://spdx.org/licenses/etalab-2.0.html
      license = "etalab-2.0";
    };

    defaults = {
      kdeglobals = {
        KDE.widgetStyle = "Breeze";
        General.ColorScheme = "BreezeLight";
        Icons.Theme = "breeze";
      };
      # Default wallpaper.
      Wallpaper.Image = "GeometricWhite";
      plasmarc.Theme = "default";
      kcminputrc.Mouse.cursorTheme = "breeze_cursors";
      kwinrc = {
        "org.kde.kdecoration2" = {
          library = "org.kde.breeze";
          theme = "Breeze";
        };
      };
      KSplash.Theme = "org.kde.Breeze";
    };

    icons = ./example-org/icons;
    wallpapers = ./example-org/wallpapers;
    launcherIcon = "example-launch";
    previews = ./example-org/previews;
    splash = null;
  };
}

# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

# CI workflows
{ pkgs, sources, lib, ... }:
let
  inherit (lib)
    mapAttrs'
    isFunction
    nameValuePair
    removeSuffix
    ;

  nix-reuse = ((import sources.nix-reuse { }).override { input = _: { nixpkgs = pkgs; }; }).output;
  nix-actions = import sources.nix-actions { inherit pkgs; };

  git-checks = (import sources.git-hooks).run {
    src = ../.;

    hooks = {
      statix = {
        enable = true;
        stages = [ "pre-push" ];
        settings.ignore = [
          "**/npins/*"
        ];
      };

      nixfmt-rfc-style = {
        enable = true;
        stages = [ "pre-push" ];
        package = pkgs.nixfmt-rfc-style;
      };

      reuse = nix-reuse.gitHook { };
    };
  };

  reuse = nix-reuse.run {
    defaultLicense = "MIT";
    defaultCopyright = "Sécurix project authors";

    downloadLicenses = true;
    generatedPaths = [
      "**/.envrc"
      ".gitignore"
      "REUSE.toml"
      "shell.nix"
      "treefmt.toml"

      ".github/workflows/*"
      "**/npins/*"
    ];
  };

  workflows = nix-actions.install {
    src = ../.;
    platform = "github";

    workflows = mapAttrs' (
      name: _:
      nameValuePair (removeSuffix ".nix" name) (
        let
          w = import ../workflows/${name};
          args = {
            inherit nix-actions;
            inherit (pkgs) lib;
          };
        in
        if (isFunction w) then (w args) else w
      )
    ) (builtins.readDir ../workflows);
  };
in
{
  inherit git-checks reuse workflows;
}

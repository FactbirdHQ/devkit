# The devenv module. Importing it declares every devkit hook disabled, and
# adds the devkit treefmt module to devenv's treefmt configuration.
#
# Enabling Biome in `treefmt.config` also writes `biome.json` to the
# project root, on shell entry and from the `biomeConfig` hook, and the
# `cdkactions` hook formats its output with the project's treefmt.
devkit: {
  config,
  lib,
  pkgs,
  ...
}: let
  treefmt = config.treefmt.config;
in {
  config = lib.mkMerge [
    {
      git-hooks.hooks = devkit.lib.hooks pkgs;
      treefmt.config.imports = [devkit.treefmtModules.default];
    }
    (lib.mkIf config.treefmt.enable {
      # cdkactions formats what it synthesizes with the project's treefmt,
      # the wrapper devenv gives its own treefmt hook.
      git-hooks.hooks.cdkactions.settings.treefmt = lib.mkDefault config.git-hooks.hooks.treefmt.package;
    })
    (lib.mkIf (config.treefmt.enable && treefmt.devkit.biome.enable) {
      git-hooks.hooks.biomeConfig = {
        enable = lib.mkDefault true;
        settings.configFile = treefmt.devkit.biome.configFile;
      };
      # A copy rather than devenv's default symlink into the store, so the
      # repository can commit the file and readers without devenv see the
      # same settings.
      files."biome.json" = {
        json = treefmt.programs.biome.settings;
        copyMode = "copy";
      };
    })
  ];
}

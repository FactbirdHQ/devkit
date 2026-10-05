# The devenv module. Importing it declares every devkit hook disabled, and
# adds the devkit treefmt module to devenv's treefmt configuration.
#
# Enabling Biome in `treefmt.config` also writes `biome.json` to the
# project root, on shell entry and from the `biomeConfig` hook.
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

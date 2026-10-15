# The devenv module. Importing it declares every devkit hook disabled, and
# adds the devkit treefmt module to devenv's treefmt configuration.
#
# Enabling Biome in `treefmt.config` also writes `biome.json` to the
# project root, and the `cdkactions` hook formats its output with the
# project's treefmt.
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
      # A copy while the biomeConfig hook keeps a committed file in step,
      # so readers without devenv see the same settings. Otherwise a
      # symlink into the store, which nobody commits.
      files."biome.json" = {
        json = treefmt.programs.biome.settings;
        copyMode =
          if config.git-hooks.hooks.biomeConfig.enable
          then "copy"
          else "symlink";
      };
    })
  ];
}

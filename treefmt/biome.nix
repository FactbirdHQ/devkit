{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.devkit.biome;
  biome = config.programs.biome;
  shared = import ../biome/settings.nix;
  defaults = lib.mapAttrsRecursive (_: lib.mkDefault);
in {
  options.devkit.biome = {
    enable = lib.mkEnableOption "Biome, with the settings in `biome/settings.nix`";

    linter.enable = lib.mkEnableOption "the shared Biome linter rules in `biome/settings.nix`";

    settings = lib.mkOption {
      inherit (pkgs.formats.json {}) type;
      description = ''
        Biome configuration, as `biome.json` holds it. devkit fills it from
        `biome/settings.nix` at default priority, so a value set here wins.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        `programs.biome.settings` rendered as `biome.json`. treefmt runs
        Biome with it, and the `biomeConfig` hook writes it to the
        repository root.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The biomeConfig hook writes biome.json from `configFile`, so a
    # formatter touching it would fight the hook the way one touching
    # Cargo.json fights the crate2nix hook.
    settings.global.excludes = ["biome.json"];

    devkit.biome.settings = lib.mkMerge [
      (defaults shared.base)
      {"$schema" = lib.mkDefault "https://biomejs.dev/schemas/${biome.package.version}/schema.json";}
      (lib.mkIf cfg.linter.enable {linter = defaults shared.linter;})
    ];

    programs.biome = {
      enable = true;
      inherit (cfg) settings;
      # treefmt-nix knows the schemas of a few Biome releases and falls back
      # to an older one otherwise. The schema in Biome's own source always
      # matches the Biome that runs.
      validate.schema = lib.mkDefault "${biome.package.src}/packages/@biomejs/biome/configuration_schema.json";
    };

    devkit.biome.configFile = (pkgs.formats.json {}).generate "biome.json" biome.settings;
  };
}

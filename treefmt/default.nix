# A treefmt-nix module. It sets nothing until a repository enables a
# program, then supplies the Factbird settings for it.
#
# Every Biome setting is a default, so a repository overrides any single
# value by defining it, without `lib.mkForce`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.devkit;
  biome = config.programs.biome;
  shared = import ../biome/settings.nix;
  defaults = lib.mapAttrsRecursive (_: lib.mkDefault);
in {
  options.devkit.biome = {
    linter.enable = lib.mkEnableOption "the shared Biome linter rules in `biome/settings.nix`";

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

  config = lib.mkMerge [
    {
      # crate2nix writes Cargo.json, and the cargoJsonSync hook rewrites it
      # on every manifest change. A formatter touching it as well means the
      # two never settle on one version.
      settings.global.excludes = ["Cargo.json" "**/Cargo.json"];
    }
    (lib.mkIf biome.enable {
      # The biomeConfig hook writes biome.json from `configFile`, so a
      # formatter touching it would fight the hook the same way.
      settings.global.excludes = ["biome.json"];

      programs.biome = {
        settings = lib.mkMerge [
          (defaults shared.base)
          {"$schema" = lib.mkDefault "https://biomejs.dev/schemas/${biome.package.version}/schema.json";}
          (lib.mkIf cfg.biome.linter.enable {linter = defaults shared.linter;})
        ];
        # treefmt-nix knows the schemas of a few Biome releases and falls back
        # to an older one otherwise. The schema in Biome's own source always
        # matches the Biome that runs.
        validate.schema = lib.mkDefault "${biome.package.src}/packages/@biomejs/biome/configuration_schema.json";
      };

      devkit.biome.configFile = (pkgs.formats.json {}).generate "biome.json" biome.settings;
    })
  ];
}

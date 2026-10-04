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
  defaults = lib.mapAttrsRecursive (_: lib.mkDefault);
  fromJSON = file: builtins.fromJSON (builtins.readFile file);
in {
  options.devkit.biome.linter.enable = lib.mkEnableOption "the shared Biome linter rules in `biome/linter.json`";

  config = lib.mkMerge [
    {
      # crate2nix writes Cargo.json, and the cargoJsonSync hook rewrites it
      # on every manifest change. A formatter touching it as well means the
      # two never settle on one version.
      settings.global.excludes = ["Cargo.json" "**/Cargo.json"];
    }
    (lib.mkIf config.programs.biome.enable {
      programs.biome = {
        settings = lib.mkMerge [
          (defaults (fromJSON ../biome/base.json))
          (lib.mkIf cfg.biome.linter.enable (defaults (fromJSON ../biome/linter.json)))
        ];
        # treefmt-nix knows the schemas of a few Biome releases and falls back
        # to an older one otherwise. The schema in Biome's own source always
        # matches the Biome that runs.
        validate.schema = lib.mkDefault "${config.programs.biome.package.src}/packages/@biomejs/biome/configuration_schema.json";
      };
    })
  ];
}

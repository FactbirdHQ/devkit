{
  pkgs,
  self,
  git-hooks,
}: let
  inherit (pkgs) lib;
  devkitHooks = self.lib.hooks pkgs;

  # A repository that enables Biome with the linter and overrides one base
  # setting. Every other base setting must survive the override.
  biome =
    (self.lib.treefmt pkgs {
      projectRootFile = "Cargo.toml";
      programs.biome.enable = true;
      devkit.biome.linter.enable = true;
      programs.biome.settings.formatter.lineWidth = 100;
    }).config.programs.biome.settings;
in {
  formatting = (self.lib.treefmt pkgs ../treefmt.nix).config.build.check self;

  biome-settings = assert biome.formatter.lineWidth == 100;
  assert biome.formatter.indentStyle == "space";
  assert biome.javascript.formatter.quoteStyle == "single";
  assert biome.linter.rules.style.useFilenamingConvention.options.filenameCases == ["kebab-case"];
    pkgs.emptyFile;

  # Both hooks against a fixture crate whose committed Cargo.json is what
  # crate2nix generates for it. The run fails if a hook rewrites a file.
  hooks = git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
    src = ./fixture;
    hooks = {
      cargoJsonSync = lib.mkMerge [devkitHooks.cargoJsonSync {enable = true;}];
      lsLint = lib.mkMerge [
        devkitHooks.lsLint
        {
          enable = true;
          settings = {
            ls = {
              ".dir" = "kebab-case";
              ".ts" = "kebab-case";
            };
            ignore = [".git" "target"];
          };
        }
      ];
    };
  };
}

{
  pkgs,
  self,
  git-hooks,
}: let
  inherit (pkgs) lib;
  devkitHooks = self.lib.hooks pkgs;

  # A repository that enables Biome with the linter and overrides one base
  # setting. Every other base setting must survive the override.
  treefmt =
    (self.lib.treefmt pkgs {
      projectRootFile = "Cargo.toml";
      programs.biome.enable = true;
      devkit.biome.linter.enable = true;
      programs.biome.settings.formatter.lineWidth = 100;
    }).config;
  biome = treefmt.programs.biome.settings;

  biomeConfig =
    (git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
      src = ./fixture;
      hooks.biomeConfig = lib.mkMerge [
        devkitHooks.biomeConfig
        {
          enable = true;
          settings.configFile = treefmt.devkit.biome.configFile;
        }
      ];
    }).config.hooks.biomeConfig;
in {
  formatting = (self.lib.treefmt pkgs ../treefmt.nix).config.build.check self;

  biome-settings = assert biome.formatter.lineWidth == 100;
  assert biome.formatter.indentStyle == "space";
  assert biome.javascript.formatter.quoteStyle == "single";
  assert biome.linter.rules.style.useFilenamingConvention.options.filenameCases == ["kebab-case"];
    pkgs.emptyFile;

  # The hook writes biome.json where there is none, byte for byte the
  # rendered settings, and leaves it alone once it matches.
  biome-config = pkgs.runCommand "biome-config" {nativeBuildInputs = [pkgs.git];} ''
    git init -q repo && cd repo
    ${biomeConfig.entry}
    cmp biome.json ${treefmt.devkit.biome.configFile}
    touch -d @0 biome.json
    ${biomeConfig.entry}
    test "$(stat -c %Y biome.json)" = 0
    touch $out
  '';

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

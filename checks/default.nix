{
  pkgs,
  self,
  git-hooks,
}: let
  inherit (pkgs) lib;
  devkitHooks = self.lib.hooks pkgs;

  # A repository that enables every tool and overrides one devkit default
  # of each. Every other default must survive the override.
  treefmt =
    (self.lib.treefmt pkgs {
      projectRootFile = "Cargo.toml";
      devkit = {
        biome = {
          enable = true;
          linter.enable = true;
          settings.formatter.lineWidth = 100;
        };
        rustfmt = {
          enable = true;
          settings.group_imports = "Preserve";
        };
        taplo = {
          enable = true;
          settings.formatting.column_width = 40;
        };
      };
    }).config;
  biome = treefmt.programs.biome.settings;
  rustfmt = treefmt.devkit.rustfmt.settings;

  # The devkit defaults alone, run over files they reformat.
  defaults =
    (self.lib.treefmt pkgs {
      projectRootFile = "Cargo.toml";
      devkit = {
        rustfmt.enable = true;
        taplo.enable = true;
      };
    }).config.build.wrapper;

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

  overrides = assert biome.formatter.lineWidth == 100;
  assert biome.formatter.indentStyle == "space";
  assert biome.javascript.formatter.quoteStyle == "single";
  assert biome.linter.rules.style.useFilenamingConvention.options.filenameCases == ["kebab-case"];
  assert rustfmt.group_imports == "Preserve";
  assert rustfmt.imports_granularity == "Module";
  assert rustfmt.style_edition == "2024";
  assert treefmt.programs.taplo.settings.formatting.column_width == 40;
    pkgs.emptyFile;

  # rustfmt merges and groups imports, and taplo keeps a dependency table
  # inline within 120 columns.
  rustfmt-taplo = pkgs.runCommand "rustfmt-taplo" {nativeBuildInputs = [pkgs.git];} ''
    mkdir repo && cd repo && git init -q
    touch Cargo.toml
    printf "%s\n" "use std::io;" "use crate::a::b;" "use serde::Serialize;" "use std::fmt;" > lib.rs
    printf "%s\n" "[dependencies]" "serde = {version=\"1\",features=[\"derive\"],default-features=false}" > deps.toml
    git add -A
    ${defaults}/bin/treefmt --no-cache
    diff -u - lib.rs <<'EOF'
    use std::{fmt, io};

    use serde::Serialize;

    use crate::a::b;
    EOF
    diff -u - deps.toml <<'EOF'
    [dependencies]
    serde = { version = "1", features = ["derive"], default-features = false }
    EOF
    touch $out
  '';

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
      crate2nix = lib.mkMerge [devkitHooks.crate2nix {enable = true;}];
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

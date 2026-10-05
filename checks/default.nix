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

  cdkactions =
    (git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
      src = ./cdkactions;
      hooks.cdkactions = lib.mkMerge [
        devkitHooks.cdkactions
        {
          enable = true;
          settings = {
            configFile = "ci-cd/cdkactions.yaml";
            yarnOfflineCache = pkgs.yarn-berry.fetchYarnBerryDeps {
              yarnLock = ./cdkactions/yarn.lock;
              hash = "sha256-G3IlUO3q8LFSqcrrOuWOOZjKTNO0t1DqRq/CxBnxGfM=";
            };
            treefmt =
              (self.lib.treefmt pkgs {
                projectRootFile = "package.json";
                devkit.githubWorkflows.enable = true;
              }).config.build.wrapper;
          };
        }
      ];
    }).config.hooks.cdkactions;

  lsLint =
    (git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
      src = ./fixture;
      hooks.lsLint = lib.mkMerge [
        devkitHooks.lsLint
        {
          enable = true;
          settings = {
            scopes.crates.".dir" = "snake_case | kebab-case";
            ignore = ["vendor"];
          };
        }
      ];
    }).config.hooks.lsLint;

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

  # A scope keeps every shared rule and changes only the keys it sets, the
  # ignore list keeps devkit's entries beside the repository's, what git
  # ignores is never checked, and a name outside the scope is still held to
  # the shared rules.
  ls-lint = pkgs.runCommand "ls-lint" {nativeBuildInputs = [pkgs.git pkgs.yq-go];} ''
    config=${lsLint.settings.generatedConfig}
    test "$(yq -r '.ls.crates.".dir"' $config)" = "snake_case | kebab-case"
    test "$(yq -r '.ls.crates.".ts"' $config)" = kebab-case
    test "$(yq -r '.ignore | contains(["vendor", "**/Cargo.json"])' $config)" = true

    mkdir repo && cd repo && git init -q
    mkdir -p crates/stop_registrar src vendor/Not_Ours outside .devenv
    touch crates/stop_registrar/mod.rs src/good-name.ts vendor/Not_Ours/Bad_Name.ts outside/Bad_Name.ts
    # What .gitignore covers is never seen, symlinks included: a link back
    # to / would otherwise be walked.
    printf "%s\n" outside .devenv > .gitignore
    ln -s / .devenv/root
    ln -s ../outside .devenv/profile
    ${lsLint.entry}
    touch src/Bad_Name.ts
    ! ${lsLint.entry}
    touch $out
  '';

  # Installs the fixture offline, synthesizes its workflow and formats it:
  # keys sorted with jobs last, and the emoji yq escapes written back. A
  # second run with the workflow staged passes and changes nothing.
  cdkactions = pkgs.runCommand "cdkactions" {nativeBuildInputs = [pkgs.git];} ''
    cp -r ${./cdkactions} repo && chmod -R u+w repo && cd repo
    git init -q
    export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR/cache
    git add -A
    # The first run adds the workflow, which fails until it is staged.
    ! ${cdkactions.entry}
    diff -u - .github/workflows/cdkactions_ci.yaml <<'EOF'
    # Generated by cdkactions. Do not modify
    # Generated as part of the 'fixture' stack.
    env:
      A: "2"
      B: "1"
    name: CI
    on: push
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - name: "🚀 Build"
            run: echo build
    EOF
    git add -A
    cp .github/workflows/cdkactions_ci.yaml $TMPDIR/first.yaml
    ${cdkactions.entry}
    cmp $TMPDIR/first.yaml .github/workflows/cdkactions_ci.yaml
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
      lsLint = lib.mkMerge [devkitHooks.lsLint {enable = true;}];
    };
  };
}

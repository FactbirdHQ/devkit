# devkit

Git hooks, Biome rules, ls-lint and treefmt configuration for Factbird
repositories, consumed as a flake input. Nothing is on by default: a
repository enables each hook and each formatter it wants.

## How to use it from devenv

Add the input to `devenv.yaml`:

```yaml
inputs:
  devkit:
    url: github:FactbirdHQ/devkit
    inputs:
      nixpkgs:
        follows: nixpkgs
```

Import the module in `devenv.nix`, then enable what the repository needs:

```nix
{inputs, ...}: {
  imports = [inputs.devkit.devenvModules.default];

  git-hooks.hooks.crate2nix.enable = true;
  git-hooks.hooks.lsLint.enable = true;

  git-hooks.hooks.treefmt.enable = true;
  treefmt = {
    enable = true;
    config.devkit = {
      biome = {
        enable = true;
        linter.enable = true;
      };
      rustfmt.enable = true;
      taplo.enable = true;
    };
  };
}
```

With Biome enabled, devenv writes `biome.json` to the project root on
shell entry and enables the `biomeConfig` hook, which writes it again on
commit. Commit the file: editors and a bare `biome` read it, and it is
never edited by hand.

To keep the repository's own crate2nix pin for `Cargo.json`:

```nix
git-hooks.hooks.crate2nix.package =
  inputs.crate2nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
```

## How to use it from a plain flake

Add the input:

```nix
inputs.devkit = {
  url = "github:FactbirdHQ/devkit";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Evaluate treefmt through devkit, and pass devkit's hooks to
`git-hooks.lib.run` with `lib.mkMerge`, so the hook module and the
repository's settings merge:

```nix
let
  treefmt = inputs.devkit.lib.treefmt pkgs {
    projectRootFile = "flake.nix";
    devkit = {
      biome = {
        enable = true;
        linter.enable = true;
      };
      rustfmt.enable = true;
      taplo.enable = true;
    };
  };
  hooks = inputs.devkit.lib.hooks pkgs;
in
  inputs.git-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
      crate2nix = lib.mkMerge [hooks.crate2nix {enable = true;}];
      biomeConfig = lib.mkMerge [
        hooks.biomeConfig
        {
          enable = true;
          settings.configFile = treefmt.config.devkit.biome.configFile;
        }
      ];
      treefmt = {
        enable = true;
        package = treefmt.config.build.wrapper;
      };
    };
  }
```

`biomeConfig` writes `biome.json` to the repository root from the same
settings treefmt runs Biome with. Commit the file, and change it through
`programs.biome.settings` rather than by hand.

`treefmt.config.build.wrapper` also serves as the flake's `formatter`, and
`treefmt.config.build.check self` as a flake check.

## How to override a devkit setting

Set the value in the tool's `devkit.<tool>.settings`. devkit defines
every value there at default priority, so the repository's definition
wins and the rest of devkit's settings stay:

```nix
devkit = {
  biome.settings.formatter.lineWidth = 100;
  rustfmt.settings.group_imports = "Preserve";
  taplo.settings.formatting.column_width = 100;
};
```

From devenv these sit under `treefmt.config`. A hook takes its overrides
on `git-hooks.hooks.<name>`, for instance `files` or `settings.root` on
`crate2nix`.

## Reference

### Flake outputs

| Output | What it is |
| --- | --- |
| `devenvModules.default` | devenv module. Declares every hook below under `git-hooks.hooks`, disabled, and imports `treefmtModules.default` into `treefmt.config`. When `treefmt.enable` and `treefmt.config.devkit.biome.enable` are both true, it also enables `biomeConfig` and writes `biome.json` through `files` with `copyMode = "copy"`. |
| `treefmtModules.default` | treefmt-nix module. See [treefmt module](#treefmt-module). |
| `lib.hooks pkgs` | Attribute set of git-hooks.nix hook modules: `biomeConfig`, `crate2nix`, `lsLint`. |
| `lib.treefmt pkgs module` | `treefmt-nix.lib.evalModule` with `treefmtModules.default` and `module` imported. |

### Hooks

Every hook takes the options every git-hooks.nix hook has (`enable`,
`package`, `files`, `stages`, and the rest), plus its own `settings`.

**`biomeConfig`.** Writes `settings.configFile` to `biome.json` at the
repository root when the two differ, on every commit.

| Option | Default |
| --- | --- |
| `settings.configFile` | none, required. The devenv module sets it to `treefmt.config.devkit.biome.configFile`. |
| `always_run` | `true` |

**`crate2nix`.** Runs `crate2nix generate --format json -o Cargo.json`
in the Cargo workspace whenever a `Cargo.toml`, `Cargo.lock` or
`Cargo.json` is staged.

| Option | Default |
| --- | --- |
| `package` | crate2nix at `b873ca5`, from devkit's `crate2nix` input |
| `files` | `Cargo\.(toml\|lock\|json)$` |
| `settings.root` | `"."`, the workspace root relative to the repository root |

**`lsLint`.** Runs `ls_lint` over the whole tree on every commit.

| Option | Default |
| --- | --- |
| `package` | `pkgs.ls-lint` |
| `always_run` | `true` |
| `settings` | `null`: ls-lint reads `.ls-lint.yml` at the repository root. An attribute set is rendered to YAML and passed with `--config`. |

### treefmt module

Each tool is off until its `enable` is set. Every value devkit puts in a
`settings` option is at `mkDefault`.

Always set:

| Option | Value |
| --- | --- |
| `settings.global.excludes` | adds `Cargo.json`, `**/Cargo.json` |

**`devkit.biome`**

| Option | Default | Effect |
| --- | --- | --- |
| `enable` | `false` | Enables `programs.biome` with `settings`, and adds `biome.json` to `settings.global.excludes`. |
| `linter.enable` | `false` | Adds `linter` from `biome/settings.nix` to `settings.linter`. |
| `settings` | `base` from `biome/settings.nix`, and `$schema` for the running Biome | Becomes `programs.biome.settings`. |
| `configFile` | read-only | `programs.biome.settings` rendered as `biome.json`. |

It also sets `programs.biome.validate.schema` to the schema in
`programs.biome.package.src`, at `mkDefault`.

**`devkit.rustfmt`**

| Option | Default | Effect |
| --- | --- | --- |
| `enable` | `false` | Enables `programs.rustfmt`, passing `settings` with one `--config`, which takes precedence over a `rustfmt.toml`. |
| `settings` | `style_edition = "2024"`, `imports_granularity = "Module"`, `group_imports = "StdExternalCrate"` | Values are booleans, integers or strings. |

`imports_granularity` and `group_imports` are unstable rustfmt options.
They take effect in a rustfmt that allows unstable features, as the
nixpkgs one does.

**`devkit.taplo`**

| Option | Default | Effect |
| --- | --- | --- |
| `enable` | `false` | Enables `programs.taplo` with `settings`. |
| `settings` | `formatting.column_width = 120` | Becomes `programs.taplo.settings`, rendered as `taplo.toml`. |

`biome/settings.nix` holds `base`, the formatter, quote style and import
groups, and `linter`, the contents of Biome's `linter` section.

## Explanation

### Why `Cargo.json` is excluded from every formatter

crate2nix writes `Cargo.json` in its own layout. If a formatter also
rewrites it, the formatter and the `crate2nix` hook take turns changing the
file, and a commit that stages it never passes both. The treefmt module
excludes it whether or not the repository enables the hook, because
crate2nix's own runs write the same layout.

### Why `biome.json` is generated and excluded from formatting

treefmt hands Biome its configuration as a store path, which editors and a
bare `biome` never see. Writing the same file to the repository root gives
them the settings treefmt runs with. The file is the output of the Nix
settings, so a formatter rewriting it would fight `biomeConfig` the way it
would fight the `crate2nix` hook over `Cargo.json`.

### Why every devkit setting is a default

A repository that disagrees with one shared value, a line width say,
defines just that value. Without `mkDefault` on every leaf, that
definition would collide with devkit's and need `lib.mkForce`, or would
replace the whole settings tree.

### Why crate2nix is pinned here

nixpkgs ships a crate2nix without `--format json`, so the hook needs one
from the crate2nix repository. devkit pins the commit governance and nest
already use, and a repository that pins its own overrides `package`.

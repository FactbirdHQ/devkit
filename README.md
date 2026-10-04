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

  git-hooks.hooks.cargoJsonSync.enable = true;
  git-hooks.hooks.lsLint.enable = true;

  git-hooks.hooks.treefmt.enable = true;
  treefmt = {
    enable = true;
    config.programs.biome.enable = true;
    config.devkit.biome.linter.enable = true;
  };
}
```

To keep the repository's own crate2nix pin for `Cargo.json`:

```nix
git-hooks.hooks.cargoJsonSync.package =
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
    programs.biome.enable = true;
    devkit.biome.linter.enable = true;
  };
  hooks = inputs.devkit.lib.hooks pkgs;
in
  inputs.git-hooks.lib.${system}.run {
    src = ./.;
    hooks = {
      cargoJsonSync = lib.mkMerge [hooks.cargoJsonSync {enable = true;}];
      treefmt = {
        enable = true;
        package = treefmt.config.build.wrapper;
      };
    };
  }
```

`treefmt.config.build.wrapper` also serves as the flake's `formatter`, and
`treefmt.config.build.check self` as a flake check.

## Reference

### Flake outputs

| Output | What it is |
| --- | --- |
| `devenvModules.default` | devenv module. Declares every hook below under `git-hooks.hooks`, disabled, and imports `treefmtModules.default` into `treefmt.config`. |
| `treefmtModules.default` | treefmt-nix module. See [treefmt module](#treefmt-module). |
| `lib.hooks pkgs` | Attribute set of git-hooks.nix hook modules: `cargoJsonSync`, `lsLint`. |
| `lib.treefmt pkgs module` | `treefmt-nix.lib.evalModule` with `treefmtModules.default` and `module` imported. |

### Hooks

Both hooks take the options every git-hooks.nix hook has (`enable`,
`package`, `files`, `stages`, and the rest), plus their own `settings`.

**`cargoJsonSync`.** Runs `crate2nix generate --format json -o Cargo.json`
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

| Option | Default | Effect |
| --- | --- | --- |
| `settings.global.excludes` | adds `Cargo.json`, `**/Cargo.json` | Always set. |
| `programs.biome.settings` | `biome/base.json`, every value at `mkDefault` | Set when `programs.biome.enable` is true. |
| `programs.biome.validate.schema` | the schema in `programs.biome.package.src` | Set when `programs.biome.enable` is true. |
| `devkit.biome.linter.enable` | `false` | Adds `biome/linter.json`, every value at `mkDefault`. |

`biome/base.json` holds the formatter, quote style and import groups.
`biome/linter.json` holds the linter rule set.

## Explanation

### Why `Cargo.json` is excluded from every formatter

crate2nix writes `Cargo.json` in its own layout. If a formatter also
rewrites it, the formatter and `cargoJsonSync` take turns changing the
file, and a commit that stages it never passes both. The treefmt module
excludes it whether or not the repository enables `cargoJsonSync`, because
crate2nix's own runs write the same layout.

### Why every Biome setting is a default

A repository that disagrees with one shared value, a line width say,
defines just that value. Without `mkDefault` on every leaf, that
definition would collide with devkit's and need `lib.mkForce`, or would
replace the whole settings tree.

### Why crate2nix is pinned here

nixpkgs ships a crate2nix without `--format json`, so the hook needs one
from the crate2nix repository. devkit pins the commit governance and nest
already use, and a repository that pins its own overrides `package`.

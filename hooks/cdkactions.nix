# Runs `cdkactions synth` for a `cdkactions.yaml`, from the directory that
# holds it and against the working tree, then formats what it wrote with
# treefmt. The commit fails when the synthesized workflows differ from the
# ones staged.
pkgs: {
  config,
  lib,
  ...
}: let
  cfg = config.settings;
  packageManagers = {
    yarn = {
      package = pkgs.yarn-berry;
      synth = "yarn cdkactions synth";
    };
    npm = {
      package = pkgs.nodejs;
      synth = "npx --no-install cdkactions synth";
    };
    pnpm = {
      package = pkgs.pnpm;
      synth = "pnpm exec cdkactions synth";
    };
    bun = {
      package = pkgs.bun;
      synth = "bun x cdkactions synth";
    };
  };
  packageManager = packageManagers.${cfg.packageManager};
  configDir = dirOf cfg.configFile;

  # Installs the workspace from a fetchYarnBerryDeps cache, offline, the way
  # nixpkgs' yarnBerryConfigHook does, but into the working tree and without
  # writing the cache settings to .yarnrc.yml. yarn re-packs patch: and git
  # dependencies into its cache, so it gets a writable copy, made once per
  # cache and kept under XDG_CACHE_HOME.
  yarnInstall = cache: ''
    if ! ${pkgs.diffutils}/bin/cmp -s yarn.lock ${cache}/yarn.lock; then
      echo "cdkactions: yarn.lock differs from the yarnOfflineCache's; update its hash." >&2
      exit 1
    fi
    cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/devkit/yarn/${builtins.baseNameOf cache}"
    if [ ! -d "$cache_dir" ]; then
      mkdir -p "$(dirname "$cache_dir")"
      cp -r ${cache}/cache "$cache_dir.tmp"
      chmod -R u+w "$cache_dir.tmp"
      mv "$cache_dir.tmp" "$cache_dir"
    fi
    YARN_CACHE_FOLDER="$cache_dir" \
    YARN_ENABLE_GLOBAL_CACHE=false \
    YARN_ENABLE_NETWORK=false \
    YARN_ENABLE_TELEMETRY=false \
      yarn install --immutable --mode=skip-build
  '';
in {
  options.settings = {
    configFile = lib.mkOption {
      type = lib.types.str;
      example = "infrastructure/ci-cd/cdkactions.yaml";
      description = "The `cdkactions.yaml`, relative to the repository root. Its `output` names the directory synth writes.";
    };

    packageManager = lib.mkOption {
      type = lib.types.enum (builtins.attrNames packageManagers);
      default = "yarn";
      description = "The package manager that runs the cdkactions CLI.";
    };

    yarnOfflineCache = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        A `fetchYarnBerryDeps` output for the repository's `yarn.lock`. When
        set, the hook installs the workspace from it before synth; when null,
        it expects `node_modules` to be installed already.
      '';
    };

    nodejs = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs;
      description = "The Node.js the cdkactions app runs on.";
    };

    treefmt = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The treefmt to run over the output directory after synth. The devenv module sets it to the project's treefmt.";
    };
  };

  config = {
    name = lib.mkDefault "cdkactions";
    description = "Synthesize GitHub workflows with cdkactions";
    package = lib.mkDefault packageManager.package;
    # Git exports GIT_DIR and friends to hooks. In a linked worktree a package
    # manager inherits them and resolves the repository root to the current
    # directory, so they are unset before anything resolves a path.
    entry = toString (pkgs.writeShellScript "cdkactions" ''
      set -euo pipefail
      unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_PREFIX
      export PATH=${lib.makeBinPath [config.package cfg.nodejs pkgs.git]}:$PATH
      root=$(git rev-parse --show-toplevel)
      cd "$root"

      output=$(${pkgs.yq-go}/bin/yq -r '.output // ""' ${lib.escapeShellArg cfg.configFile})
      if [ -z "$output" ]; then
        echo "cdkactions: ${cfg.configFile} has no output directory." >&2
        exit 1
      fi

      ${lib.optionalString (cfg.yarnOfflineCache != null) (yarnInstall cfg.yarnOfflineCache)}

      cd ${lib.escapeShellArg configDir}
      # cdkactions lists the output directory before writing into it.
      mkdir -p "$output"
      ${packageManager.synth}
      output=$(realpath "$output")
      cd "$root"
      ${lib.optionalString (cfg.treefmt != null) ''${cfg.treefmt}/bin/treefmt "$output"''}

      # pre-commit reports a rewritten tracked file on its own, but not a
      # workflow synth adds, so a new one fails the commit here until staged.
      untracked=$(git ls-files --others --exclude-standard -- "$output")
      if [ -n "$untracked" ]; then
        echo "cdkactions: synthesized workflows not yet staged:" >&2
        echo "$untracked" >&2
        exit 1
      fi
    '');
    files = lib.mkDefault "^(${lib.escapeRegex configDir}/|\\.github/workflows/)|(^|/)package\\.json$|^yarn\\.lock$";
    pass_filenames = false;
  };
}

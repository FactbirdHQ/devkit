# Checks file and directory names against ls-lint rules.
#
# The configuration is generated from `settings`: shared `rules`, scoped
# overrides in `scopes`, and an `ignore` list. ls-lint replaces rather than
# merges the rules of a scoped block, so each scope is rendered as the
# shared rules with its own keys on top, and a scope states only what it
# changes. `configFile` uses an existing `.ls-lint.yml` instead.
#
# ls-lint runs over a copy of the names git lists, tracked or untracked but
# not ignored, as empty files. Its own walk follows symlinks, so in the
# repository it would walk into the Nix store through `.devenv/profile` and
# every other link a devenv shell leaves, whatever the ignore list says.
# The copy holds no links and nothing `.gitignore` covers, and ls-lint only
# reads names. ls-lint finds what a `**` pattern matches by globbing the
# tree, so no ignore entry may contain `**`.
pkgs: {
  config,
  lib,
  ...
}: let
  cfg = config.settings;
  rule = lib.types.nullOr lib.types.str;
  # A rule set to null is dropped, so a scope can stop checking an extension
  # the shared rules check.
  present = lib.filterAttrs (_: v: v != null);
  generated = {
    ls = present cfg.rules // lib.mapAttrs (_: scope: present (cfg.rules // scope)) cfg.scopes;
    inherit (cfg) ignore;
  };
  exactPath =
    lib.types.addCheck lib.types.str (path: !lib.hasInfix "**" path)
    // {description = "path relative to the repository root, without `**`";};
in {
  options.settings = {
    rules = lib.mkOption {
      type = lib.types.attrsOf rule;
      description = ''
        The rules for the whole tree, keyed by `.dir` or an extension such as
        `.ts`. ls-lint keys an extension off everything after a name's first
        dot, so a rule governs single-dot names only and `foo.test.ts` stays
        unchecked.
      '';
    };

    scopes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf rule);
      default = {};
      example = {
        "crates".".dir" = "snake_case | kebab-case";
      };
      description = "Rules for a path, merged over `rules`.";
    };

    ignore = lib.mkOption {
      type = lib.types.listOf exactPath;
      description = ''
        Paths ls-lint skips among the names git lists, relative to the
        repository root. What `.gitignore` covers never reaches ls-lint, so
        this is for tracked names that are not the repository's to choose. A
        repository's entries are added to devkit's.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ".ls-lint.yml";
      description = ''
        An ls-lint configuration in the repository, relative to its root,
        used instead of the generated one and as it is.
      '';
    };

    generatedConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        The configuration rendered from `rules`, `scopes` and `ignore`.
      '';
    };
  };

  config = {
    settings = {
      rules = lib.mapAttrs (_: lib.mkDefault) {
        # Tool directories such as `.github` are dot-named wherever they sit,
        # and test runners put a `__snapshots__` beside each test.
        ".dir" = "kebab-case | regex:\\.[a-z0-9-]+ | regex:__snapshots__";
        ".ts" = "kebab-case";
        ".tsx" = "kebab-case";
        ".js" = "kebab-case";
        ".css" = "kebab-case";
        # crate2nix writes a `Cargo.json` beside each `Cargo.toml`.
        ".json" = "kebab-case | regex:Cargo";
        ".gql" = "kebab-case";
        ".nix" = "kebab-case";
        ".sh" = "kebab-case";
        # A module's file or directory name is a Rust identifier, which cannot
        # hold a hyphen, while a binary's entry file is named like any other.
        ".rs" = "snake_case | kebab-case";
      };
      # Names a tool picks, each a path from the repository root: workflow
      # files cdkactions names, yarn's release and plugin files, and editor
      # and agent settings.
      ignore = [
        ".github"
        ".yarn"
        ".cargo"
        ".claude"
        ".vscode"
      ];
      generatedConfig = (pkgs.formats.json {}).generate "ls-lint.json" generated;
    };

    name = lib.mkDefault "ls-lint";
    description = "Check file and directory names with ls-lint";
    package = lib.mkDefault pkgs.ls-lint;
    entry = toString (pkgs.writeShellScript "ls-lint" ''
      set -euo pipefail
      export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.git]}:$PATH
      root=$(git rev-parse --show-toplevel)
      cd "$root"
      tree=$(mktemp -d)
      trap 'rm -rf "$tree"' EXIT
      git ls-files -z --cached --others --exclude-standard > "$tree.list"
      (
        cd "$tree"
        tr '\0' '\n' < "$tree.list" | sed -n 's|/[^/]*$||p' | sort -u | xargs -r -d '\n' mkdir -p
        xargs -r -0 touch < "$tree.list"
      )
      rm "$tree.list"
      ${config.package}/bin/ls_lint --workdir "$tree" --config ${
        if cfg.configFile != null
        then "\"$root\"/${lib.escapeShellArg cfg.configFile}"
        else cfg.generatedConfig
      }
    '');
    # Every listed name is checked against every rule, so a rename anywhere
    # is caught rather than only the staged paths.
    pass_filenames = false;
    always_run = lib.mkDefault true;
  };
}

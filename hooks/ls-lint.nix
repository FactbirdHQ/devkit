# Checks file and directory names against ls-lint rules.
#
# The configuration is generated from `settings`: shared `rules`, scoped
# overrides in `scopes`, and an `ignore` list. ls-lint replaces rather than
# merges the rules of a scoped block, so each scope is rendered as the
# shared rules with its own keys on top, and a scope states only what it
# changes. `configFile` uses an existing `.ls-lint.yml` instead.
#
# ls-lint reads no `.gitignore`, so the hook adds every path git ignores to
# the generated `ignore` list when it runs, each as an exact path. ls-lint
# finds what a `**` pattern matches by globbing the whole tree with symlinks
# followed, which never finishes in a tree with a symlink loop, such as the
# macOS SDK in a devenv profile. So no ignore entry may contain `**`.
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
        "libraries/rust".".dir" = "snake_case | kebab-case";
      };
      description = "Rules for a path, merged over `rules`.";
    };

    ignore = lib.mkOption {
      type = lib.types.listOf exactPath;
      description = ''
        Paths ls-lint skips, relative to the repository root, on top of
        everything git ignores. A tracked path that should not be checked
        belongs here. A repository's entries are added to devkit's.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = ".ls-lint.yml";
      description = ''
        An ls-lint configuration in the repository, relative to its root,
        used instead of the generated one and as it is. The hook adds no
        gitignored paths to it.
      '';
    };

    generatedConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        The configuration rendered from `rules`, `scopes` and `ignore`, before
        the hook adds the paths git ignores.
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
      # Each entry is a path from the repository root. git ignores most of
      # these anyway, but a repository may track a tool directory, and git
      # never lists its own.
      ignore = [
        ".git"
        ".github"
        ".yarn"
        ".cargo"
        ".direnv"
        ".devenv"
        ".cache"
        ".claude"
        ".vscode"
        "node_modules"
        "target"
        "result"
        "dist"
        "cdk.out"
      ];
      generatedConfig = (pkgs.formats.json {}).generate "ls-lint.json" generated;
    };

    name = lib.mkDefault "ls-lint";
    description = "Check file and directory names with ls-lint";
    package = lib.mkDefault pkgs.ls-lint;
    entry = toString (pkgs.writeShellScript "ls-lint" (''
        set -euo pipefail
        cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
      ''
      + (
        if cfg.configFile != null
        then ''
          exec ${config.package}/bin/ls_lint --config ${lib.escapeShellArg cfg.configFile}
        ''
        else ''
          config=$(${pkgs.coreutils}/bin/mktemp)
          trap 'rm -f "$config"' EXIT
          # --directory names an ignored directory once instead of listing
          # everything inside it.
          ${pkgs.git}/bin/git ls-files -z --others --ignored --exclude-standard --directory \
            | ${pkgs.jq}/bin/jq -Rs --slurpfile base ${cfg.generatedConfig} '
                (split("\u0000") | map(select(length > 0) | rtrimstr("/"))) as $ignored
                | $base[0] | .ignore += $ignored
              ' >"$config"
          ${config.package}/bin/ls_lint --config "$config"
        ''
      )));
    # ls-lint walks the whole tree, so a rename anywhere is checked against
    # every rule rather than only the staged paths.
    pass_filenames = false;
    always_run = lib.mkDefault true;
  };
}

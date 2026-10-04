# Checks file and directory names against ls-lint rules.
#
# With `settings` left null, ls-lint reads `.ls-lint.yml` from the
# repository root. Set it to keep the rules in Nix instead.
pkgs: {
  config,
  lib,
  ...
}: let
  yaml = pkgs.formats.yaml {};
in {
  options.settings = lib.mkOption {
    type = lib.types.nullOr yaml.type;
    default = null;
    description = "The ls-lint configuration, as `.ls-lint.yml` would hold it.";
    example = {
      ls = {
        ".dir" = "kebab-case";
        ".ts" = "kebab-case";
      };
      ignore = [".git" "node_modules"];
    };
  };

  config = {
    name = lib.mkDefault "ls-lint";
    description = "Check file and directory names with ls-lint";
    package = lib.mkDefault pkgs.ls-lint;
    entry =
      "${config.package}/bin/ls_lint"
      + lib.optionalString (config.settings != null)
      " --config ${yaml.generate "ls-lint.yml" config.settings}";
    # ls-lint walks the whole tree, so a rename anywhere is checked
    # against every rule rather than only the staged paths.
    pass_filenames = false;
    always_run = lib.mkDefault true;
  };
}

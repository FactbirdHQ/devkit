# The devenv module. Importing it declares every devkit hook disabled, and
# adds the devkit treefmt module to devenv's treefmt configuration.
devkit: {pkgs, ...}: {
  git-hooks.hooks = devkit.lib.hooks pkgs;
  treefmt.config.imports = [devkit.treefmtModules.default];
}

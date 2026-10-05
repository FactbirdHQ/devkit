# Writes the repository's `biome.json` from the Biome settings in Nix, so
# editors and a bare `biome` read the same configuration treefmt runs with.
# The commit fails when the file changed, like any hook that rewrites a
# file, and passes once the rewritten file is staged.
pkgs: {
  config,
  lib,
  ...
}: {
  options.settings.configFile = lib.mkOption {
    type = lib.types.path;
    description = "The rendered configuration, usually the treefmt evaluation's `devkit.biome.configFile`.";
  };

  config = {
    name = lib.mkDefault "biome-config";
    description = "Write biome.json from the Biome settings in Nix";
    entry = toString (pkgs.writeShellScript "biome-config" ''
      set -euo pipefail
      cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
      if ! cmp -s ${config.settings.configFile} biome.json; then
        install -m 644 ${config.settings.configFile} biome.json
      fi
    '');
    pass_filenames = false;
    # The settings change without any file in the repository changing, so
    # the hook cannot wait for a matching staged path.
    always_run = lib.mkDefault true;
  };
}

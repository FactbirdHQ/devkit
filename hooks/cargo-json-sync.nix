# Regenerates `Cargo.json`, the pre-resolved crate graph crate2nix builds
# read, whenever a Cargo manifest or lockfile changes. Nothing regenerates it
# at evaluation time, so without this hook it goes stale silently.
{
  pkgs,
  crate2nix,
}: {
  config,
  lib,
  ...
}: {
  options.settings.root = lib.mkOption {
    type = lib.types.str;
    default = ".";
    description = "The Cargo workspace root, relative to the repository root.";
  };

  config = {
    name = lib.mkDefault "cargo-json-sync";
    description = "Regenerate Cargo.json with crate2nix";
    # Each repository keeps its own crate2nix pin by overriding this.
    package = lib.mkDefault crate2nix;
    # Git exports GIT_DIR and friends to hooks, and nix-prefetch-git inherits
    # them and reinitialises the host repository instead of its own scratch
    # directory, so they are unset first.
    #
    # crate2nix bakes the hashes of git and registry sources into Cargo.json,
    # which makes crate-hashes.json redundant; `-h` points it at a temporary
    # path so it is not written into the repository.
    entry = toString (pkgs.writeShellScript "cargo-json-sync" ''
      set -euo pipefail
      unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_PREFIX
      cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)/${config.settings.root}"
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      ${config.package}/bin/crate2nix generate --format json -o Cargo.json -h "$tmp/crate-hashes.json"
    '');
    files = lib.mkDefault "Cargo\\.(toml|lock|json)$";
    pass_filenames = false;
  };
}

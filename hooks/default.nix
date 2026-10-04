# Every hook devkit provides, as git-hooks.nix hook modules. Each one is
# disabled until a repository sets `enable = true` on it.
{
  pkgs,
  crate2nix,
}: {
  cargoJsonSync = import ./cargo-json-sync.nix {inherit pkgs crate2nix;};
  lsLint = import ./ls-lint.nix pkgs;
}

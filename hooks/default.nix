# Every hook devkit provides, as git-hooks.nix hook modules. Each one is
# disabled until a repository sets `enable = true` on it.
{
  pkgs,
  crate2nixPackage,
}: {
  biomeConfig = import ./biome-config.nix pkgs;
  cdkactions = import ./cdkactions.nix pkgs;
  crate2nix = import ./crate2nix.nix {inherit pkgs crate2nixPackage;};
  lsLint = import ./ls-lint.nix pkgs;
}

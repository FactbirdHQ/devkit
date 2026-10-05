# A treefmt-nix module. Each tool devkit configures stays off until a
# repository sets `devkit.<tool>.enable`, which enables the treefmt-nix
# program and supplies devkit's settings for it.
#
# Every setting devkit supplies is a default, so a repository overrides any
# single value by defining it, without `lib.mkForce`.
{
  imports = [
    ./biome.nix
    ./rustfmt.nix
    ./taplo.nix
    ./github-workflows.nix
  ];

  # The crate2nix hook rewrites Cargo.json on every manifest change. A
  # formatter touching it as well means the two never settle on one
  # version.
  settings.global.excludes = ["Cargo.json" "**/Cargo.json"];
}

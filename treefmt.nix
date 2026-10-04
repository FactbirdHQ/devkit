# devkit's own formatting, through its own treefmt module.
{
  projectRootFile = "flake.nix";
  programs = {
    alejandra.enable = true;
    biome.enable = true;
  };
}

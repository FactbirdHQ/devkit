# devkit's own formatting, through its own treefmt module.
{
  projectRootFile = "flake.nix";
  programs.alejandra.enable = true;
  devkit = {
    biome.enable = true;
    githubWorkflows.enable = true;
    taplo.enable = true;
  };
}

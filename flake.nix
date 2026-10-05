{
  description = "Opt-in git hooks, Biome rules, ls-lint and treefmt configuration for Factbird repositories";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The default package for the crate2nix hook. nixpkgs ships a crate2nix
    # without `--format json`.
    crate2nix = {
      url = "github:nix-community/crate2nix/b873ca53dd64e12340416f0fd5e3b33792b9c17b";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cachix.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
    treefmt-nix,
    crate2nix,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    # For devenv: `imports = [inputs.devkit.devenvModules.default];`.
    devenvModules.default = import ./modules/devenv.nix self;

    # For treefmt-nix, wherever it is evaluated.
    treefmtModules.default = ./treefmt;

    lib = {
      # The hooks as git-hooks.nix hook modules, for `git-hooks.lib.run`.
      hooks = pkgs:
        import ./hooks {
          inherit pkgs;
          crate2nixPackage = crate2nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
        };

      # treefmt-nix evaluated with the devkit module, for a flake without
      # devenv. `.config.build.wrapper` is the treefmt to run and to hand
      # the `treefmt` hook; `.config.build.check` is a flake check.
      treefmt = pkgs: module:
        treefmt-nix.lib.evalModule pkgs {
          imports = [self.treefmtModules.default module];
        };
    };

    formatter = forAllSystems (pkgs: (self.lib.treefmt pkgs ./treefmt.nix).config.build.wrapper);

    checks = forAllSystems (pkgs: import ./checks {inherit pkgs self git-hooks;});
  };
}

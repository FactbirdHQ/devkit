{
  config,
  lib,
  ...
}: let
  cfg = config.devkit.rustfmt;
  value = v:
    if lib.isBool v
    then lib.boolToString v
    else toString v;
in {
  options.devkit.rustfmt = {
    enable = lib.mkEnableOption "rustfmt, with devkit's settings";

    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [bool int str]);
      description = ''
        rustfmt configuration, passed with `--config` so it takes precedence
        over a `rustfmt.toml`. devkit's values are defaults, so a value
        set here wins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    devkit.rustfmt.settings = lib.mapAttrs (_: lib.mkDefault) {
      # rustfmt otherwise derives the style from each crate's `edition`,
      # so a workspace spanning editions formats one file differently
      # depending on whether `cargo fmt` or treefmt reached it.
      style_edition = "2024";
      # Both are unstable rustfmt options. They take effect in a rustfmt
      # that allows unstable features, as the nixpkgs one does.
      imports_granularity = "Module";
      group_imports = "StdExternalCrate";
    };

    programs.rustfmt.enable = true;
    settings.formatter.rustfmt.options = [
      "--config"
      (lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}=${value v}") cfg.settings))
    ];
  };
}

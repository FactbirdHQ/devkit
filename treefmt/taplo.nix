{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.devkit.taplo;
in {
  options.devkit.taplo = {
    enable = lib.mkEnableOption "taplo, with devkit's settings";

    settings = lib.mkOption {
      inherit (pkgs.formats.toml {}) type;
      description = ''
        taplo configuration, as `taplo.toml` holds it. devkit's values are
        defaults, so a value set here wins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The same width as Biome's, so a one-line dependency in Cargo.toml
    # stays one line instead of exploding into a multi-line table.
    devkit.taplo.settings.formatting.column_width = lib.mkDefault 120;

    programs.taplo = {
      enable = true;
      inherit (cfg) settings;
    };
  };
}

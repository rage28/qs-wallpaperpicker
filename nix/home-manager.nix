{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.qs-wallpaperpicker;
  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.programs.qs-wallpaperpicker = {
    enable = lib.mkEnableOption "the Quickshell wallpaper picker";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "qs-wallpaperpicker.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "The qs-wallpaperpicker package to install.";
    };

    noctaliaIntegration.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Noctalia theme-template configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."noctalia/qs-wallpaperpicker.toml" = lib.mkIf cfg.noctaliaIntegration.enable {
      text = ''
        [theme]
        source = "wallpaper"
        wallpaper_scheme = "m3-content"

        [theme.templates]
        enable_builtin_templates = true
        builtin_ids = ["mango"]

        [theme.templates.user.qs_wallpaperpicker]
        input_path = "${cfg.package}/share/qs-wallpaperpicker/extras/noctalia/quickshell.json"
        output_path = "$XDG_CONFIG_HOME/qs-wallpaperpicker/colors/Colors.json"
      '';
    };
  };
}

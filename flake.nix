{
  description = "Swatch-deck wallpaper picker for Quickshell, Noctalia, and MangoWC";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fontconfig = pkgs.makeFontsConf {
            fontDirectories = [ pkgs.material-symbols ];
          };
        in
        rec {
          qs-wallpaperpicker = pkgs.stdenvNoCC.mkDerivation {
            pname = "qs-wallpaperpicker";
            version = "0-unstable";
            src = nixpkgs.lib.cleanSource self;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/share/qs-wallpaperpicker" "$out/bin"
              cp -R . "$out/share/qs-wallpaperpicker"

              makeWrapper "$out/share/qs-wallpaperpicker/bin/qs-wallpaperpicker" \
                "$out/bin/qs-wallpaperpicker" \
                --set QS_WALLPAPERPICKER_CONFIG "$out/share/qs-wallpaperpicker" \
                --set FONTCONFIG_FILE "${fontconfig}" \
                --prefix PATH : ${
                  nixpkgs.lib.makeBinPath [
                    pkgs.coreutils
                    pkgs.gnugrep
                    pkgs.noctalia
                    pkgs.python3
                    pkgs.quickshell
                  ]
                }

              runHook postInstall
            '';

            meta = {
              description = "Swatch-deck wallpaper picker for Quickshell";
              homepage = "https://github.com/rage28/qs-wallpaperpicker";
              license = nixpkgs.lib.licenses.gpl3Plus;
              mainProgram = "qs-wallpaperpicker";
              platforms = nixpkgs.lib.platforms.linux;
            };
          };

          default = qs-wallpaperpicker;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/qs-wallpaperpicker";
        };
      });

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          source = nixpkgs.lib.cleanSource self;
          fontconfig = pkgs.makeFontsConf { fontDirectories = [ ]; };
        in
        {
          qml-tests = pkgs.runCommand "qs-wallpaperpicker-qml-tests" { } ''
            export HOME="$TMPDIR/home"
            export FONTCONFIG_FILE="${fontconfig}"
            export LC_ALL=C.UTF-8
            export QML_IMPORT_PATH="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
            export QT_QPA_PLATFORM=offscreen
            mkdir -p "$HOME"
            ${pkgs.qt6.qtdeclarative}/bin/qmltestrunner -input ${source}/tests
            touch "$out"
          '';
        }
      );

      homeManagerModules.default = import ./nix/home-manager.nix { inherit self; };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}

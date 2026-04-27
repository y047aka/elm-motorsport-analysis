{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "lamdera"
          ];
        };

        elmTools = with pkgs.elmPackages; [
          elm
          elm-format
          elm-json
          elm-review
          elm-test
          elm-verify-examples
          lamdera
        ];

        playwrightEnv = {
          FONTCONFIG_FILE = pkgs.makeFontsConf {
            fontDirectories = with pkgs; [ ipafont freefont_ttf wqy_zenhei ];
          };
          PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers.override {
            withFirefox = false;
            withWebkit = false;
          };
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
        };

        mkNodeApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_24 pkgs.pnpm ] ++ elmTools;
            text = cmd;
          };

        playwrightModules = "${pkgs.playwright-test}/lib/node_modules";

        mkVrtApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_24 pkgs.pnpm pkgs.playwright-test ] ++ elmTools;
            text = ''
              export FONTCONFIG_FILE=${playwrightEnv.FONTCONFIG_FILE}
              export PLAYWRIGHT_BROWSERS_PATH=${playwrightEnv.PLAYWRIGHT_BROWSERS_PATH}
              export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=${playwrightEnv.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=${playwrightEnv.PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS}

              # Symlink @playwright/test into node_modules for ESM resolution
              mkdir -p app/node_modules/@playwright
              ln -sfn ${playwrightModules}/@playwright/test app/node_modules/@playwright/test

              ${cmd}
            '';
          };

        mkCargoApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.cargo pkgs.rustc pkgs.rustfmt ];
            text = ''
              cd cli
              ${cmd}
            '';
          };

        flix = pkgs.flix.overrideAttrs (old: rec {
          version = "0.71.0";
          src = pkgs.fetchurl {
            url = "https://github.com/flix/flix/releases/download/v${version}/flix.jar";
            hash = "sha256-Ha5oRDpQ7YuGsaF/ZNx8b+HjTSroxZEjzI3zR3g7NXI=";
          };
        });

        mkFlixApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              cd flix
              ${cmd}
            '';
          };

      in {
        devShells.default = pkgs.mkShell (playwrightEnv // {
          buildInputs = with pkgs; [ nodejs_24 pnpm rustc cargo rustfmt playwright-test ] ++ [ flix ] ++ elmTools;
        });

        apps = {
          dev                  = { type = "app"; program = "${mkNodeApp "dev"                  "pnpm start"}/bin/dev";                                              meta.description = "Start elm-pages dev server (localhost:1234)"; };
          build                = { type = "app"; program = "${mkNodeApp "build"                "pnpm run build"}/bin/build";                                         meta.description = "Production build"; };
          test                 = { type = "app"; program = "${mkNodeApp "test"                 "pnpm test"}/bin/test";                                               meta.description = "Run Elm package tests (elm-verify-examples + elm-test)"; };
          test-vrt             = { type = "app"; program = "${mkVrtApp  "test-vrt"             "cd app && playwright test"}/bin/test-vrt";                           meta.description = "Run Playwright VRT tests"; };
          update-snapshots-vrt = { type = "app"; program = "${mkVrtApp  "update-snapshots-vrt" "cd app && playwright test --update-snapshots"}/bin/update-snapshots-vrt"; meta.description = "Update Playwright VRT snapshots"; };
          review-app           = { type = "app"; program = "${mkNodeApp "review-app"           "cd app && elm-review src"}/bin/review-app";                          meta.description = "Run elm-review on app"; };
          review-package       = { type = "app"; program = "${mkNodeApp "review-package"       "cd package && elm-review src"}/bin/review-package";                  meta.description = "Run elm-review on package"; };
          format               = { type = "app"; program = "${mkNodeApp "format"               "elm-format --yes app/app app/src package/src"}/bin/format";           meta.description = "Format Elm code (elm-format)"; };
          cli-build            = { type = "app"; program = "${mkCargoApp "cli-build" "cargo build"}/bin/cli-build";                                                  meta.description = "Build Rust CLI"; };
          cli-test             = { type = "app"; program = "${mkCargoApp "cli-test"  "cargo test"}/bin/cli-test";                                                    meta.description = "Run Rust CLI tests"; };
          cli-run              = { type = "app"; program = "${mkCargoApp "cli-run"   "cargo run -p cli -- ../app/static/wec/2025"}/bin/cli-run";                     meta.description = "Run Rust CLI (CSV -> JSON)"; };
          flix-build           = { type = "app"; program = "${mkFlixApp "flix-build" "flix build"}/bin/flix-build";                                                   meta.description = "Build Flix project"; };
          flix-test            = { type = "app"; program = "${mkFlixApp "flix-test"  "flix test"}/bin/flix-test";                                                     meta.description = "Run Flix tests"; };
          flix-run             = { type = "app"; program = "${mkFlixApp "flix-run"   "flix run -- ../cli/test_data.csv"}/bin/flix-run";                               meta.description = "Run Flix project (CSV -> JSON)"; };
        };
      });
}

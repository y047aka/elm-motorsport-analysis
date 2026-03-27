{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        mkNodeApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_24 ];
            text = cmd;
          };

        mkCargoApp = name: cargoArgs:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.cargo pkgs.rustc pkgs.rustfmt ];
            text = ''
              cd cli
              cargo ${cargoArgs}
            '';
          };

      in {
        devShells.default = with pkgs;
          mkShell {
            buildInputs = [
              nodejs_24
              rustc
              cargo
              rustfmt
              elmPackages.elm-json
            ];
          };

        apps = {
          dev            = { type = "app"; program = "${mkNodeApp  "dev"            "npm start"}/bin/dev";            meta.description = "Start elm-pages dev server (localhost:1234)"; };
          build          = { type = "app"; program = "${mkNodeApp  "build"          "npm run build"}/bin/build";       meta.description = "Production build"; };
          test           = { type = "app"; program = "${mkNodeApp  "test"           "npm test"}/bin/test";             meta.description = "Run Elm package tests (elm-verify-examples + elm-test)"; };
          test-vrt       = { type = "app"; program = "${mkNodeApp  "test-vrt"       "npm run -w app test"}/bin/test-vrt"; meta.description = "Run Playwright VRT tests"; };
          review-app     = { type = "app"; program = "${mkNodeApp  "review-app"     "npm run -w review app"}/bin/review-app"; meta.description = "Run elm-review on app"; };
          review-package = { type = "app"; program = "${mkNodeApp  "review-package" "npm run -w review package"}/bin/review-package"; meta.description = "Run elm-review on package"; };
          format         = { type = "app"; program = "${mkNodeApp  "format"         "npx biome format --write ."}/bin/format"; meta.description = "Format code (biome format --write .)"; };
          lint           = { type = "app"; program = "${mkNodeApp  "lint"           "npx biome check --write ."}/bin/lint"; meta.description = "Lint and fix (biome check --write .)"; };
          cli-build      = { type = "app"; program = "${mkCargoApp "cli-build"      "build"}/bin/cli-build";          meta.description = "Build Rust CLI"; };
          cli-test       = { type = "app"; program = "${mkCargoApp "cli-test"       "test"}/bin/cli-test";            meta.description = "Run Rust CLI tests"; };
        };
      });
}

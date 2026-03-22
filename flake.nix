{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
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
            ];
          };

        apps = {
          dev            = { type = "app"; program = "${mkNodeApp  "dev"            "npm start"}/bin/dev"; };
          build          = { type = "app"; program = "${mkNodeApp  "build"          "npm run build"}/bin/build"; };
          test           = { type = "app"; program = "${mkNodeApp  "test"           "npm test"}/bin/test"; };
          test-vrt       = { type = "app"; program = "${mkNodeApp  "test-vrt"       "npm run -w app test"}/bin/test-vrt"; };
          review-app     = { type = "app"; program = "${mkNodeApp  "review-app"     "npm run -w review app"}/bin/review-app"; };
          review-package = { type = "app"; program = "${mkNodeApp  "review-package" "npm run -w review package"}/bin/review-package"; };
          format         = { type = "app"; program = "${mkNodeApp  "format"         "npx biome format --write ."}/bin/format"; };
          lint           = { type = "app"; program = "${mkNodeApp  "lint"           "npx biome check --write ."}/bin/lint"; };
          cli-build      = { type = "app"; program = "${mkCargoApp "cli-build"      "build"}/bin/cli-build"; };
          cli-test       = { type = "app"; program = "${mkCargoApp "cli-test"       "test"}/bin/cli-test"; };
        };
      });
}

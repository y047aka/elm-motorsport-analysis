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

        mkNodeApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_24 pkgs.pnpm ] ++ elmTools;
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
            buildInputs = [ nodejs_24 pnpm rustc cargo rustfmt ] ++ elmTools;
          };

        apps = {
          dev            = { type = "app"; program = "${mkNodeApp "dev"            "pnpm start"}/bin/dev";                      meta.description = "Start elm-pages dev server (localhost:1234)"; };
          build          = { type = "app"; program = "${mkNodeApp "build"          "pnpm run build"}/bin/build";                 meta.description = "Production build"; };
          test           = { type = "app"; program = "${mkNodeApp "test"           "pnpm test"}/bin/test";                       meta.description = "Run Elm package tests (elm-verify-examples + elm-test)"; };
          test-vrt       = { type = "app"; program = "${mkNodeApp "test-vrt"       "pnpm --filter app test"}/bin/test-vrt";        meta.description = "Run Playwright VRT tests"; };
          review-app     = { type = "app"; program = "${mkNodeApp "review-app"     "pnpm --filter review app"}/bin/review-app";    meta.description = "Run elm-review on app"; };
          review-package = { type = "app"; program = "${mkNodeApp "review-package" "pnpm --filter review package"}/bin/review-package"; meta.description = "Run elm-review on package"; };
          format         = { type = "app"; program = "${mkNodeApp "format"         "pnpm exec biome format --write ."}/bin/format";   meta.description = "Format code (biome format --write .)"; };
          lint           = { type = "app"; program = "${mkNodeApp "lint"           "pnpm exec biome check --write ."}/bin/lint";      meta.description = "Lint and fix (biome check --write .)"; };
          cli-build      = { type = "app"; program = "${mkCargoApp "cli-build"     "build"}/bin/cli-build";                    meta.description = "Build Rust CLI"; };
          cli-test       = { type = "app"; program = "${mkCargoApp "cli-test"      "test"}/bin/cli-test";                      meta.description = "Run Rust CLI tests"; };
        };
      });
}

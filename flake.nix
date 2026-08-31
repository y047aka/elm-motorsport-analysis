{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        elmTools = with pkgs.elmPackages; [
          elm
          elm-format
          elm-json
          elm-review
          elm-test
          elm-verify-examples
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

        # Runner carrying the Node and Elm toolchains. Every command names the
        # subproject it works on, because there is no manifest above them to
        # dispatch from: `app/` is the only npm project and holds the lockfile,
        # `package/` is Elm-only and reached through elm.json alone.
        mkNodeApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_26 pkgs.pnpm ] ++ elmTools;
            text = cmd;
          };

        playwrightModules = "${pkgs.playwright-test}/lib/node_modules";

        mkVrtApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_26 pkgs.pnpm pkgs.playwright-test ] ++ elmTools;
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

        # Runner for the Tauri v2 native app. Runs cargo-tauri with app/ as the cwd
        # (cargo-tauri finds ./src-tauri/tauri.conf.json and runs
        # beforeDevCommand=`pnpm run start` from app/).
        # Targets macOS, which uses the OS-provided WebView (no extra system deps).
        # Targeting Linux would additionally need pkg-config + webkitgtk_4_1/libsoup_3/gtk3.
        mkTauriApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_26 pkgs.pnpm pkgs.cargo pkgs.rustc pkgs.cargo-tauri ]
              ++ elmTools
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
            text = ''
              cd app
              ${cmd}
            '';
          };

        flix = pkgs.flix.overrideAttrs (old: rec {
          version = "0.75.1";
          src = pkgs.fetchurl {
            url = "https://github.com/flix/flix/releases/download/v${version}/flix.jar";
            hash = "sha256-4xd3AK6tiiKkLJEOc7+4oyb+/bq04+rq9tVcMopr2Tg=";
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

        # The CLI's one argument is the directory holding the season directories,
        # and it converts the rounds `Motorsport.Calendar` lists. Anything else
        # given to `nix run` is forwarded, which is how `--postgres <url>` is
        # reached.
        cliRunCmd = "flix run -- ../app/static/wec \"$@\"";

        # Audit helpers for the update-deps skill. The jar is located via the
        # git root so the caller's working directory is left untouched —
        # subcommands resolve flake.lock, app/elm.json and node_modules
        # relative to the cwd. Rebuilds the jar when sources changed; cargo
        # is needed by the rust-major-audit subcommand.
        depsAuditApp = pkgs.writeShellApplication {
          name = "deps-audit";
          runtimeInputs = [ flix pkgs.jdk21_headless pkgs.cargo pkgs.git ];
          text = ''
            root=$(git rev-parse --show-toplevel)
            dir=$root/.claude/skills/update-deps/scripts-flix
            jar=$dir/artifact/scripts-flix.jar
            if [ ! -f "$jar" ] || [ -n "$(find "$dir/src" -name '*.flix' -newer "$jar" 2>/dev/null)" ]; then
              (cd "$dir" && flix build-jar) >&2
            fi
            java -jar "$jar" "$@"
          '';
        };

      in {
        # `gh` is here rather than in an app: it is not a project command but a
        # tool with a surface of its own, and reaching it through
        # `nix develop --command gh ...` keeps it outside the blanket
        # `nix run .#*` permission, so each subcommand is allowed on its own
        # merits. It reads the credentials `gh auth login` wrote; nix supplies
        # the binary, not the login.
        devShells.default = pkgs.mkShell (playwrightEnv // {
          buildInputs = with pkgs; [ nodejs_26 pnpm rustc cargo rustfmt cargo-tauri playwright-test gh ]
            ++ [ flix ] ++ elmTools;
        });

        apps = {
          dev                  = { type = "app"; program = "${mkNodeApp "dev"                  "cd app && pnpm start"}/bin/dev";                                     meta.description = "Start Vite dev server (localhost:1234)"; };
          build                = { type = "app"; program = "${mkNodeApp "build"                "cd app && pnpm run build"}/bin/build";                               meta.description = "Production build"; };
          test                 = { type = "app"; program = "${mkNodeApp "test"                 "cd package && elm-verify-examples && elm-test"}/bin/test";           meta.description = "Run Elm package tests (elm-verify-examples + elm-test)"; };
          test-vrt             = { type = "app"; program = "${mkVrtApp  "test-vrt"             "cd app && playwright test"}/bin/test-vrt";                           meta.description = "Run Playwright VRT tests"; };
          update-snapshots-vrt = { type = "app"; program = "${mkVrtApp  "update-snapshots-vrt" "cd app && playwright test --update-snapshots"}/bin/update-snapshots-vrt"; meta.description = "Update Playwright VRT snapshots"; };
          benchmark            = { type = "app"; program = "${mkNodeApp "benchmark"            "cd package/benchmark && node generate-fixture.mjs && elm reactor"}/bin/benchmark"; meta.description = "Serve the package benchmarks (elm reactor)"; };
          typecheck            = { type = "app"; program = "${mkNodeApp "typecheck"            "cd app && pnpm run typecheck"}/bin/typecheck";                       meta.description = "Type-check the app's TypeScript (tsc --noEmit)"; };
          review-app           = { type = "app"; program = "${mkNodeApp "review-app"           "cd app && elm-review src"}/bin/review-app";                          meta.description = "Run elm-review on app"; };
          review-package       = { type = "app"; program = "${mkNodeApp "review-package"       "cd package && elm-review src"}/bin/review-package";                  meta.description = "Run elm-review on package"; };
          format               = { type = "app"; program = "${mkNodeApp "format"               "elm-format --yes app/src package/src"}/bin/format";                   meta.description = "Format Elm code (elm-format)"; };
          tauri-dev            = { type = "app"; program = "${mkTauriApp "tauri-dev"   "cargo tauri dev"}/bin/tauri-dev";                                              meta.description = "Start Tauri v2 native app (dev)"; };
          tauri-build          = { type = "app"; program = "${mkTauriApp "tauri-build" "cargo tauri build"}/bin/tauri-build";                                          meta.description = "Build Tauri v2 native app (release)"; };
          cli-build            = { type = "app"; program = "${mkFlixApp "cli-build" "flix build"}/bin/cli-build";                                                    meta.description = "Build the CLI"; };
          cli-test             = { type = "app"; program = "${mkFlixApp "cli-test"  "flix test"}/bin/cli-test";                                                      meta.description = "Run the CLI's tests"; };
          cli-run              = { type = "app"; program = "${mkFlixApp "cli-run"   cliRunCmd}/bin/cli-run";                                                         meta.description = "Run the CLI (CSV -> JSON)"; };
          deps-audit           = { type = "app"; program = "${depsAuditApp}/bin/deps-audit";                                                                          meta.description = "Audit helpers for the update-deps skill"; };
        };
      });
}

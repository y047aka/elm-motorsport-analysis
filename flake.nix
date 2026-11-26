{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    circuit-maps-3d.url = "github:y047aka/circuit-maps-3d";
  };

  outputs = { nixpkgs, flake-utils, circuit-maps-3d, ... }:
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

        vrt = import ./nix/vrt.nix { inherit pkgs elmTools; };

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

        # Runner for the Tauri v2 native app, from app/. Targets macOS, which
        # uses the OS-provided WebView; Linux would additionally need
        # pkg-config + webkitgtk_4_1/libsoup_3/gtk3. `before` runs from the
        # repository root, which is where the build writes the rounds it is
        # about to bundle.
        mkTauriApp = name: before: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_26 pkgs.pnpm pkgs.cargo pkgs.rustc pkgs.cargo-tauri flix ]
              ++ elmTools
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
            text = ''
              ${before}
              cd app
              ${cmd}
            '';
          };

        flix = pkgs.flix.overrideAttrs (old: rec {
          version = "0.79.0";
          src = pkgs.fetchurl {
            url = "https://github.com/flix/flix/releases/download/v${version}/flix.jar";
            hash = "sha256-j60qoJVnp+2rzEP0EB+mGZEx3ywikp4AHIdlnXZPbc8=";
          };
        });

        mkFlixApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              cd backend
              ${cmd}
            '';
          };

        # The surveyed geometry and each circuit's map record are owned by
        # `github:y047aka/circuit-maps-3d`; its flake's default package lays
        # `geometry/<word>.geojson` and `specs/<word>.json` out flat. The app
        # reads both from `app/static/` under their served names, and nothing
        # compares the two sides' bytes: a pinned input whose geometry moves
        # moves every tracker VRT baseline with it.
        #
        # Every command that reads the files copies the pinned bytes into the
        # working tree first; they are not committed.
        circuitData = circuit-maps-3d.packages.${system}.default;
        syncCircuitData = ''
          mkdir -p app/static/geometry app/static/circuit-maps
          cp -f ${circuitData}/geometry/*.geojson app/static/geometry/
          for f in ${circuitData}/specs/*.json; do
            cp -f "$f" "app/static/circuit-maps/$(basename "$f")"
          done
        '';

        # `app/codegen` writes `data/wec/manufacturers.json` out as the ignored module `app/generated/Generated/Data/Wec/Manufacturer/Table.elm`, so every command that compiles the app writes it first.
        # elm-codegen comes from `app/node_modules`, which is why `.#test` needs `pnpm install` too.
        # elm-codegen 0.6 exits 0 when the generator itself does not compile, so the old output is removed first: a broken generator then fails the app's compile by module name instead of leaving last run's table in place.
        generateElm = ''
          rm -rf app/generated
          (cd app && pnpm exec elm-codegen run --flags-from ../data/wec/manufacturers.json --output generated)
        '';

        # Where the CLI and the server compute when the caller names nowhere
        # else. The file is in the working copy rather than under /tmp, so the
        # rows a run left there are still there to be queried; the path is
        # relative to `backend`, which every command below changes to.
        dbUrl = "jdbc:sqlite:.db/motorsport.sqlite";

        # A caller who has already named a database is left alone, and
        # `--database` beats the variable in `Main`, so a run can still name
        # its own either way.
        dbEnv = ''export DATABASE_URL="''${DATABASE_URL:-${dbUrl}}"'';

        # The same as `mkFlixApp`, for the commands that need a database.
        mkFlixAppWithDb = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              ${dbEnv}
              cd backend
              ${cmd}
            '';
          };

        # The server's operating form is the jar: `flix run` takes the JVM down
        # with `main`, and the server's `main` does not return. Rebuilt when a
        # source is newer than it, as the deps-audit jar is.
        #
        # `flix build-jar` leaves the Maven dependencies out of the jar it
        # writes, so the JDBC driver is named on the class path beside it and
        # the jar is run by its main class rather than by `java -jar`.
        mkFlixServerApp = name: args:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix pkgs.jdk21_headless ];
            text = ''
              ${dbEnv}
              cd backend
              jar=artifact/backend.jar
              # The marker, not the jar: an interrupted `build-jar` leaves a jar
              # with no central directory in it, and one newer than every source
              # it was made from, which reads as built and runs as a missing
              # `Main` until the file is removed by hand.
              if [ ! -f "$jar.ok" ] || [ -n "$(find src flix.toml -newer "$jar.ok" 2>/dev/null)" ]; then
                rm -f "$jar" "$jar.ok"
                flix build-jar >&2
                touch "$jar.ok"
              fi
              java -cp "$jar:$(find lib -name '*.jar' | tr '\n' ':')" Main ${args} "$@"
            '';
          };

        # The one round the export is kept for. Every round is loaded and
        # `/api` answers for all of them; this is the one whose files are
        # written, so that what the renderers produce can be read without a
        # server. Passed before "$@", so a run can name another round as well.
        exportedRound = "--export-only 2025/le_mans_24h";

        # Relative to `backend`, which every command below changes to.
        csvDir = "--csv ../data/wec";
        outDir = "--out ../app/static/wec";

        # What `.#tauri-build` runs first, and the one place every round is
        # written: a bundle answers out of the files beside it, so a round left
        # unwritten is a round it cannot open. Converts rather than exports,
        # since a checkout has the CSV and an empty database.
        exportEveryRound = ''
          ${dbEnv}
          (cd backend && flix run -- ${csvDir} ${outDir})
        '';

        # The CLI converts the rounds `Motorsport.Calendar` lists, reading each
        # season directory under one directory and writing into the same one
        # under the other. Anything else given to `nix run` is forwarded, which
        # is how `--database <url>` is reached.
        cliRunCmd = "flix run -- ${exportedRound} ${csvDir} ${outDir} \"$@\"";

        # The two stages of that run, taken singly: `--load` stops at the rows,
        # and `--export` writes the files out of rows already there.
        cliLoadCmd   = "flix run -- --load ${csvDir} \"$@\"";
        cliExportCmd = "flix run -- --export ${exportedRound} ${outDir} \"$@\"";

        # What follows `nix run` reaches Playwright, so one shot can be run on its
        # own with `-g <shot>`. `--update-snapshots` with nothing narrowing it
        # rewrites every baseline to this machine's rasteriser, which CI rejects.
        # A file named after the flag is read as its mode, so name the shot.
        vrtTestCmd = "${syncCircuitData}\n${generateElm}\ncd app && playwright test \"$@\"";
        vrtUpdateCmd = "${syncCircuitData}\n${generateElm}\ncd app && playwright test --update-snapshots \"$@\"";

        # The fetcher encodes what it downloads, so it needs libwebp beside Node.
        # Kept apart from `mkNodeApp`: every other Node command would carry the
        # encoder for nothing.
        carImagesApp = pkgs.writeShellApplication {
          name = "car-images";
          runtimeInputs = [ pkgs.nodejs_26 pkgs.libwebp ];
          text = ''
            cd app
            node scripts/fetch-car-images.mjs "$@"
          '';
        };

        # Audit helpers for the update-deps skill. The jar is located via the
        # git root so the caller's working directory is left untouched --
        # subcommands resolve flake.lock, app/elm.json and node_modules
        # relative to the cwd. Rebuilt as `mkFlixServerApp` is; cargo is needed
        # by the rust-major-audit subcommand.
        depsAuditApp = pkgs.writeShellApplication {
          name = "deps-audit";
          runtimeInputs = [ flix pkgs.jdk21_headless pkgs.cargo pkgs.git ];
          text = ''
            root=$(git rev-parse --show-toplevel)
            dir=$root/.pi/skills/update-deps/scripts-flix
            jar=$dir/artifact/scripts-flix.jar
            if [ ! -f "$jar.ok" ] || [ -n "$(find "$dir/src" -name '*.flix' -newer "$jar.ok" 2>/dev/null)" ]; then
              rm -f "$jar" "$jar.ok"
              (cd "$dir" && flix build-jar) >&2
              touch "$jar.ok"
            fi
            java -jar "$jar" "$@"
          '';
        };

      in {
        # `gh` is here rather than in an app: reaching it through
        # `nix develop --command gh ...` keeps it outside the blanket
        # `nix run .#*` permission, so each subcommand is allowed on its own
        # merits. `update-snapshots-ci` is the exception (nix/vrt.nix).
        devShells.default = pkgs.mkShell (vrt.env // {
          buildInputs = with pkgs; [ nodejs_26 pnpm rustc cargo rustfmt cargo-tauri playwright-test gh ]
            ++ [ flix ] ++ elmTools;
        });

        apps = {
          dev                  = { type = "app"; program = "${mkNodeApp "dev"                  "${syncCircuitData}\n${generateElm}\ncd app && pnpm start"}/bin/dev";                                     meta.description = "Start Vite dev server (localhost:1234)"; };
          build                = { type = "app"; program = "${mkNodeApp "build"                "${syncCircuitData}\n${generateElm}\ncd app && pnpm run build"}/bin/build";                               meta.description = "Production build"; };
          test                 = { type = "app"; program = "${mkNodeApp "test"                 "${syncCircuitData}\n${generateElm}\ncd app && elm-test && cd .. && node app/scripts/test-fixtures.mjs && cd package && elm-verify-examples && elm-test"}/bin/test";           meta.description = "Run Elm tests: the app's, then the package's (on the served geometry bytes, via elm-verify-examples + elm-test)"; };
          test-vrt             = { type = "app"; program = "${vrt.mkApp "test-vrt" vrtTestCmd}/bin/test-vrt";                     meta.description = "Run Playwright VRT tests"; };
          update-snapshots-vrt = { type = "app"; program = "${vrt.mkApp "update-snapshots-vrt" vrtUpdateCmd}/bin/update-snapshots-vrt"; meta.description = "Update Playwright VRT snapshots"; };
          update-snapshots-ci  = { type = "app"; program = "${vrt.updateSnapshotsCiApp}/bin/update-snapshots-ci";                                                             meta.description = "Re-render the VRT baselines on CI's Linux and push them onto this branch"; };
          benchmark            = { type = "app"; program = "${mkNodeApp "benchmark"            "cd package/benchmark && node generate-position-fixture.mjs && node generate-fixture.mjs && elm reactor"}/bin/benchmark"; meta.description = "Serve the package benchmarks (elm reactor)"; };
          typecheck            = { type = "app"; program = "${mkNodeApp "typecheck"            "cd app && pnpm run typecheck"}/bin/typecheck";                                            meta.description = "Type-check the app's TypeScript (tsc --noEmit)"; };
          review-app           = { type = "app"; program = "${mkNodeApp "review-app"           "cd app && elm-review src"}/bin/review-app";                          meta.description = "Run elm-review on app"; };
          review-package       = { type = "app"; program = "${mkNodeApp "review-package"       "cd package && elm-review src"}/bin/review-package";                  meta.description = "Run elm-review on package"; };
          format               = { type = "app"; program = "${mkNodeApp "format"               "elm-format --yes app/src package/src"}/bin/format";                   meta.description = "Format Elm code (elm-format)"; };
          car-images           = { type = "app"; program = "${carImagesApp}/bin/car-images";                                                                            meta.description = "Download a season's car photographs and register them"; };
          tauri-dev            = { type = "app"; program = "${mkTauriApp "tauri-dev"   (syncCircuitData + generateElm) "cargo tauri dev"}/bin/tauri-dev";                                              meta.description = "Start Tauri v2 native app (dev)"; };
          tauri-build          = { type = "app"; program = "${mkTauriApp "tauri-build" (syncCircuitData + generateElm + exportEveryRound) "cargo tauri build"}/bin/tauri-build";                                          meta.description = "Build Tauri v2 native app (release; writes every round out first)"; };
          flix-build           = { type = "app"; program = "${mkFlixApp "flix-build" "flix build"}/bin/flix-build";                                                       meta.description = "Build the Flix project"; };
          flix-test            = { type = "app"; program = "${mkFlixApp "flix-test" "flix test"}/bin/flix-test";                                                     meta.description = "Run the Flix project's tests"; };
          sqlitefx-test        = { type = "app"; program = "${mkFlixApp "sqlitefx-test" "cd sqlitefx && flix test"}/bin/sqlitefx-test";                             meta.description = "Run backend/sqlitefx's tests, against SQLite databases in memory and in temporary files"; };
          cli-run              = { type = "app"; program = "${mkFlixAppWithDb "cli-run"  cliRunCmd}/bin/cli-run";                                                          meta.description = "Run the CLI (CSV -> SQLite, and the kept round out to JSON/JSONL)"; };
          cli-load             = { type = "app"; program = "${mkFlixAppWithDb "cli-load"   cliLoadCmd}/bin/cli-load";                                                      meta.description = "Load the CSV into SQLite, writing no files"; };
          cli-export           = { type = "app"; program = "${mkFlixAppWithDb "cli-export" cliExportCmd}/bin/cli-export";                                                  meta.description = "Write the kept round out as the export"; };
          serve-api            = { type = "app"; program = "${mkFlixServerApp "serve-api" "--serve"}/bin/serve-api";                                                      meta.description = "Serve the loaded rounds over HTTP (/api)"; };
          deps-audit           = { type = "app"; program = "${depsAuditApp}/bin/deps-audit";                                                                          meta.description = "Audit helpers for the update-deps skill"; };
        };
      });
}

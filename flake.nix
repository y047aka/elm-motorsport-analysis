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
              cd flix
              ${cmd}
            '';
          };

        # Probing OpenStreetMap before a config is authored is the third Flix
        # project, at `circuits/probe`. It is the flake's only Flix command that
        # neither computes in a database nor reads one: it is the one that asks a
        # question of OpenStreetMap, and it keeps its own reading of that rather than
        # symlinking one out of `flix/src`, because there is nothing in `flix/src`
        # that asks a question of anything but a database.
        mkProbeApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              cd circuits/probe
              ${cmd}
            '';
          };

        # The fourth Flix project, at `circuits/geometry`: it lays two kept geometries
        # together and surveys a circuit out of its kept Overpass answer, reading a file and
        # writing one and reaching neither a database nor a network. Which parts of the
        # pipeline stayed TypeScript's is `circuits/README.md`'s to say.
        #
        # `GEOMETRY_FROM` is the directory the reader was standing in: `flix` has to be
        # started inside the project to find its `flix.toml`, and the reader names
        # `app/static/geometry/le_mans.geojson` from outside it.
        mkGeometryApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              export GEOMETRY_FROM="$PWD"
              cd circuits/geometry
              ${cmd}
            '';
          };

        # The timing-lines report is a second Flix project, at `circuits/timing`.
        # Of the flake's Flix commands it is the only one handed neither `--database`
        # nor `DATABASE_URL`, and its `flix.toml` resolves no JDBC driver, so it has
        # no way to name a database, stale or otherwise.
        mkTimingApp = name: cmd:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ flix ];
            text = ''
              cd circuits/timing
              ${cmd}
            '';
          };

        # Where the CLI and the server compute when the caller names nowhere
        # else. The file is in the working copy rather than under /tmp, so the
        # rows a run left there are still there to be queried; the path is
        # relative to `flix`, which every command below changes to.
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
              cd flix
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
              cd flix
              jar=artifact/flix.jar
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

        # Relative to `flix`, which every command below changes to.
        csvDir = "--csv ../data/wec";
        outDir = "--out ../app/static/wec";

        # Relative to `circuits/timing`, which the report's two commands change to.
        timingCsvDir = "--csv ../../data/wec";

        # What `.#tauri-build` runs first, and the one place every round is
        # written: a bundle answers out of the files beside it, so a round left
        # unwritten is a round it cannot open. Converts rather than exports,
        # since a checkout has the CSV and an empty database.
        exportEveryRound = ''
          ${dbEnv}
          (cd flix && flix run -- ${csvDir} ${outDir})
        '';

        # Where its timings come from, and what they cannot answer, is
        # `circuits/README.md`'s.
        timingLinesCmd = "flix run -- ${timingCsvDir} \"$@\"";

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
        vrtTestCmd = "cd app && playwright test \"$@\"";
        vrtUpdateCmd = "cd app && playwright test --update-snapshots \"$@\"";

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

        # The tools under circuits/ that are Node's, each run with nothing else to
        # carry. Which circuits are surveyed is the registry's, not these
        # registrations'; only geometry-write writes what the app serves,
        # under app/static/geometry, and the rest write beside it or read it.
        # Probing a place, laying two geometries against each other and reading timing
        # lines are not among them: each is a Flix project of `circuits/` now, and each
        # is registered with its own runner below.
        geometryApp = name: script:
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [ pkgs.nodejs_26 ];
            text = ''
              node circuits/${script}.ts "$@"
            '';
          };

        # The circuit tools' unit tests, on Node's own test runner. They reach
        # each tool's pure reading -- the half that opens no file and asks no
        # network -- and the runner is in Node itself, so this directory keeps
        # installing nothing. The files are named out rather than the directory:
        # Node's test discovery does not offer up .ts files at every version
        # pinned here.
        geometryTest = pkgs.writeShellApplication {
          name = "geometry-test";
          runtimeInputs = [ pkgs.nodejs_26 ];
          text = ''
            node --test circuits/tests/*.test.ts
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
            dir=$root/.claude/skills/update-deps/scripts-flix
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
          dev                  = { type = "app"; program = "${mkNodeApp "dev"                  "cd app && pnpm start"}/bin/dev";                                     meta.description = "Start Vite dev server (localhost:1234)"; };
          build                = { type = "app"; program = "${mkNodeApp "build"                "cd app && pnpm run build"}/bin/build";                               meta.description = "Production build"; };
          test                 = { type = "app"; program = "${mkNodeApp "test"                 "cd app && elm-test && cd .. && node app/scripts/test-fixtures.mjs && cd package && elm-verify-examples && elm-test"}/bin/test";           meta.description = "Run Elm tests: the app's, then the package's (on the served geometry bytes, via elm-verify-examples + elm-test)"; };
          test-vrt             = { type = "app"; program = "${vrt.mkApp "test-vrt" vrtTestCmd}/bin/test-vrt";                     meta.description = "Run Playwright VRT tests"; };
          update-snapshots-vrt = { type = "app"; program = "${vrt.mkApp "update-snapshots-vrt" vrtUpdateCmd}/bin/update-snapshots-vrt"; meta.description = "Update Playwright VRT snapshots"; };
          update-snapshots-ci  = { type = "app"; program = "${vrt.updateSnapshotsCiApp}/bin/update-snapshots-ci";                                                             meta.description = "Re-render the VRT baselines on CI's Linux and push them onto this branch"; };
          benchmark            = { type = "app"; program = "${mkNodeApp "benchmark"            "cd package/benchmark && node generate-position-fixture.mjs && node generate-fixture.mjs && elm reactor"}/bin/benchmark"; meta.description = "Serve the package benchmarks (elm reactor)"; };
          typecheck            = { type = "app"; program = "${mkNodeApp "typecheck"            "cd app && pnpm run typecheck && pnpm exec tsc -p ../circuits"}/bin/typecheck";                       meta.description = "Type-check the TypeScript of both projects: the app's (tsc --noEmit), then the circuit tools' (their own tsconfig, the app's compiler and @types)"; };
          review-app           = { type = "app"; program = "${mkNodeApp "review-app"           "cd app && elm-review src"}/bin/review-app";                          meta.description = "Run elm-review on app"; };
          review-package       = { type = "app"; program = "${mkNodeApp "review-package"       "cd package && elm-review src"}/bin/review-package";                  meta.description = "Run elm-review on package"; };
          format               = { type = "app"; program = "${mkNodeApp "format"               "elm-format --yes app/src package/src"}/bin/format";                   meta.description = "Format Elm code (elm-format)"; };
          car-images           = { type = "app"; program = "${carImagesApp}/bin/car-images";                                                                            meta.description = "Download a season's car photographs and register them"; };
          geometry-write       = { type = "app"; program = "${geometryApp "geometry-write" "write-geometry"}/bin/geometry-write";                                        meta.description = "Write a circuit's geometry out of OpenStreetMap, or check the kept one (<circuit>; [overpass.json] to use an answer you kept; --from-geojson to re-check the kept geometry with no network)"; };
          geometry-atlas       = { type = "app"; program = "${geometryApp "geometry-atlas" "atlas-geometry"}/bin/geometry-atlas";                                        meta.description = "Measure a dataset's line against a circuit's kept geometry, and keep it beside it (<circuit> [--file gp.geojson])"; };
          geometry-diff        = { type = "app"; program = "${mkGeometryApp "geometry-diff" "flix run -- diff \"$@\""}/bin/geometry-diff";                              meta.description = "Lay two kept geometries against each other in metres, optionally as an SVG overlay (the circuits/geometry project, reading no database; paths from where the command is run, [--every <m>] [--svg <out.svg>])"; };
          geometry-survey      = { type = "app"; program = "${mkGeometryApp "geometry-survey" "flix run -- survey \"$@\""}/bin/geometry-survey";                          meta.description = "Survey a circuit's geometry out of its kept Overpass answer, and fail unless it is the bytes the app serves (the circuits/geometry project, reaching no database and no network; <circuit> [--answer <overpass.json>] [--write], paths from where the command is run)"; };
          geometry-diff-test   = { type = "app"; program = "${mkGeometryApp "geometry-diff-test" "flix test"}/bin/geometry-diff-test";                             meta.description = "Run the circuits/geometry project's tests — the readings behind geometry-diff and geometry-survey (no network, no database, no files written)"; };
          geometry-regenerate  = { type = "app"; program = "${geometryApp "geometry-regenerate" "regenerate-geometry"}/bin/geometry-regenerate";                      meta.description = "Re-run the geometry pipeline over each circuit's kept Overpass answer and fail unless it reproduces the kept geometry ([<circuit> ...]; --write re-lays the files from the kept answer; --freeze asks OpenStreetMap now and keeps both)"; };
          geometry-timing-lines = { type = "app"; program = "${mkTimingApp "geometry-timing-lines" timingLinesCmd}/bin/geometry-timing-lines";                              meta.description = "Whether a circuit's timing lines still stand where they stood a season earlier, read off two rounds' sector times (the circuits/timing project, computing in no database; <season>/<id> [--against <season>] [--tolerance <metres>])"; };
          geometry-timing-test = { type = "app"; program = "${mkTimingApp "geometry-timing-test" "flix test"}/bin/geometry-timing-test";                                   meta.description = "Run the timing report's tests (the circuits/timing project's; no database, no network, no files written)"; };
          geometry-probe       = { type = "app"; program = "${mkProbeApp "geometry-probe" "flix run -- \"$@\""}/bin/geometry-probe";                                 meta.description = "Ask OpenStreetMap which relations hold a circuit at a place, each lap measured, before a circuit's config is authored (the circuits/probe project, computing in no database; <lat>,<lon> [...] [--radius <km>], or a s,w,n,e box)"; };
          geometry-probe-test  = { type = "app"; program = "${mkProbeApp "geometry-probe-test" "flix test"}/bin/geometry-probe-test";                              meta.description = "Run the probe's tests (the circuits/probe project's; no network, no database, no files written)"; };
          geometry-test        = { type = "app"; program = "${geometryTest}/bin/geometry-test";                                                                          meta.description = "Run the circuit tools' unit tests (Node's own runner over circuits/tests/; no network, no files written)"; };
          tauri-dev            = { type = "app"; program = "${mkTauriApp "tauri-dev"   ""               "cargo tauri dev"}/bin/tauri-dev";                                              meta.description = "Start Tauri v2 native app (dev)"; };
          tauri-build          = { type = "app"; program = "${mkTauriApp "tauri-build" exportEveryRound "cargo tauri build"}/bin/tauri-build";                                          meta.description = "Build Tauri v2 native app (release; writes every round out first)"; };
          flix-build           = { type = "app"; program = "${mkFlixApp "flix-build" "flix build"}/bin/flix-build";                                                       meta.description = "Build the Flix project"; };
          flix-test            = { type = "app"; program = "${mkFlixApp "flix-test" "flix test"}/bin/flix-test";                                                     meta.description = "Run the Flix project's tests"; };
          cli-run              = { type = "app"; program = "${mkFlixAppWithDb "cli-run"  cliRunCmd}/bin/cli-run";                                                          meta.description = "Run the CLI (CSV -> SQLite, and the kept round out to JSON/JSONL)"; };
          cli-load             = { type = "app"; program = "${mkFlixAppWithDb "cli-load"   cliLoadCmd}/bin/cli-load";                                                      meta.description = "Load the CSV into SQLite, writing no files"; };
          cli-export           = { type = "app"; program = "${mkFlixAppWithDb "cli-export" cliExportCmd}/bin/cli-export";                                                  meta.description = "Write the kept round out as the export"; };
          serve-api            = { type = "app"; program = "${mkFlixServerApp "serve-api" "--serve"}/bin/serve-api";                                                      meta.description = "Serve the loaded rounds over HTTP (/api)"; };
          deps-audit           = { type = "app"; program = "${depsAuditApp}/bin/deps-audit";                                                                          meta.description = "Audit helpers for the update-deps skill"; };
        };
      });
}

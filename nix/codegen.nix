# What writes the sources nobody edits: the manufacturer table, the geometry
# fixtures the package's tests read, and the copy of the pinned circuit bytes
# the app serves. A line belongs here rather than in `flake.nix` when it is
# about a file the build generates.
{ circuitData }:

let
  # The package's tests read the same pinned bytes the app serves, and they
  # read them off the input rather than off `app/static/`: a stale copy in
  # the working tree is then not what a test passes on.
  # elm-codegen 0.6 writes a long string as a block string without looking at
  # its content, so a file holding `"""` comes out as a module that does not
  # compile.
  servedFiles = dir: extension:
    let
      names =
        builtins.filter
          (name: builtins.match ".*\\.${extension}" name != null)
          (builtins.attrNames (builtins.readDir dir));

      bytesOf = name:
        let
          content = builtins.readFile (dir + "/${name}");
        in
        if builtins.replaceStrings [ "\"\"\"" ] [ "quoted" ] content != content then
          builtins.throw "${dir}/${name} holds \"\"\", which no block string can hold"
        else
          content;
    in
    if names == [ ] then
      builtins.throw "${dir} holds no .${extension} file"
    else
      builtins.listToAttrs (map (name: { name = name; value = bytesOf name; }) names);

  testFixtureFlags =
    builtins.toFile "test-fixtures.json" (builtins.toJSON {
      geometry = servedFiles (circuitData + "/geometry") "geojson";
      maps = servedFiles (circuitData + "/specs") "json";
    });

in
rec {
  # The pinned bytes are not committed, so every command that reads them copies
  # them out of the input into `app/static/` first.
  syncCircuitData = ''
    mkdir -p app/static/geometry app/static/circuit-maps
    cp -f ${circuitData}/geometry/*.geojson app/static/geometry/
    for f in ${circuitData}/specs/*.json; do
      cp -f "$f" "app/static/circuit-maps/$(basename "$f")"
    done
  '';

  # `app/codegen`'s output — `app/generated/`, and the package's `TestHelpers/Survey/` and `TestHelpers/Map/` — is not committed, so every command that compiles the app or its tests writes it first; elm-codegen comes from `app/node_modules`.
  # elm-codegen 0.6 exits 0 when the generator itself does not compile, so the old output is removed first: a broken generator then fails the app's compile by module name instead of leaving last run's table in place.
  # Both generators read the pinned input, so no caller runs `syncCircuitData` for them, and the helper modules are removed with `app/generated/` so a circuit dropped upstream leaves none behind.
  generateElm = ''
    rm -rf app/generated package/tests/Motorsport/TestHelpers/Survey package/tests/Motorsport/TestHelpers/Map
    (cd app && pnpm exec elm-codegen run --flags-from ../data/wec/manufacturers.json --output generated)
    (cd app && pnpm exec elm-codegen run codegen/TestFixtures.elm --flags-from ${testFixtureFlags} --output ../package/tests)
  '';
}

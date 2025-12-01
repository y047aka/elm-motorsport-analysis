{ pkgs }:

pkgs.buildNpmPackage rec {
  pname = "elm-pages";
  version = "3.0.22";

  # Fetch the tarball from npm registry
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/elm-pages/-/elm-pages-${version}.tgz";
    hash = "sha256-0QA6khaVe7ndiTtmnJAwDKUp1kFbDsN4ArI4Tiv2OJs=";
  };

  # Hash of npm dependencies
  npmDepsHash = "sha256-WsDnhAZZOpYtUSmaiXaOhEVDDOpsiGDTNK7EeCKtCZY=";

  # Copy package-lock.json since it's not included in the tarball
  postPatch = ''
    cp ${./elm-pages-package-lock.json} package-lock.json
  '';

  # Skip Cypress installation to avoid certificate issues
  CYPRESS_INSTALL_BINARY = "0";

  # elm-pages ships prebuilt, no compilation needed
  dontNpmBuild = true;

  # Ensure elm is available during build/install
  nativeBuildInputs = [ pkgs.elmPackages.elm ];

  meta = with pkgs.lib; {
    description = "Hybrid Elm framework with full-stack and static routes";
    homepage = "https://elm-pages.com";
    license = licenses.bsd3;
    maintainers = [ ];
    mainProgram = "elm-pages";
    platforms = platforms.all;
  };
}

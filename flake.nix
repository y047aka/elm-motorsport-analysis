{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        elm-pages = pkgs.callPackage ./nix/elm-pages.nix { };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js runtime
            nodejs_24

            # Elm toolchain from nixpkgs
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-optimize-level-2

            # elm-pages from custom build
            elm-pages

            # Rust toolchain
            rustc
            cargo
          ];

          shellHook = ''
            echo "🎯 Elm Motorsport Analysis - Dev Environment"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "All tools managed by Nix:"
            echo "  • Elm: $(elm --version)"
            echo "  • elm-pages: $(elm-pages --version)"
            echo "  • Node.js: $(node --version)"
            echo "  • Rust: $(rustc --version | cut -d' ' -f2)"
            echo ""
            echo "📦 Next step: Run 'npm install' to set up workspace dependencies"
            echo ""
          '';
        };
      });
}

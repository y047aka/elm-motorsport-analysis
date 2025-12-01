{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js runtime
            nodejs_24

            # Elm toolchain from nixpkgs
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-optimize-level-2

            # Rust toolchain
            rustc
            cargo
          ];

          shellHook = ''
            echo "🎯 Elm Motorsport Analysis - Dev Environment"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo "Nix-managed tools:"
            echo "  • Elm: $(elm --version)"
            echo "  • Node.js: $(node --version)"
            echo "  • Rust: $(rustc --version | cut -d' ' -f2)"
            echo ""
            echo "📦 Next step: Run 'npm install' to set up workspace"
            echo "   (This will install elm-pages 3.0.22 and other deps)"
            echo ""
          '';
        };
      });
}

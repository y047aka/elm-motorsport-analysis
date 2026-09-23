# What the visual regression tests render with, and what refreshes their
# baselines. A command belongs here rather than in `flake.nix` when it is
# about a screenshot; `AGENTS.md` holds the reasoning behind the whole scheme.
{ pkgs, elmTools }:

let
  playwrightModules = "${pkgs.playwright-test}/lib/node_modules";

in
rec {
  # The fonts are named rather than left to the host: a baseline rendered
  # against whichever fonts a machine happens to have is one only that
  # machine can reproduce.
  env = {
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

  mkApp = name: cmd:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.nodejs_26 pkgs.pnpm pkgs.playwright-test ] ++ elmTools;
      text = ''
        export FONTCONFIG_FILE=${env.FONTCONFIG_FILE}
        export PLAYWRIGHT_BROWSERS_PATH=${env.PLAYWRIGHT_BROWSERS_PATH}
        export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=${env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD}
        export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=${env.PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS}

        # Symlink @playwright/test into node_modules for ESM resolution
        mkdir -p app/node_modules/@playwright
        ln -sfn ${playwrightModules}/@playwright/test app/node_modules/@playwright/test

        ${cmd}
      '';
    };

  # The only `gh` reachable through `nix run`, against the rule set out
  # beside the devShell: it takes no arguments, and one workflow is its whole
  # surface.
  updateSnapshotsCiApp = pkgs.writeShellApplication {
    name = "update-snapshots-ci";
    runtimeInputs = [ pkgs.gh pkgs.git ];
    text = builtins.readFile ./update-snapshots-ci.sh;
  };
}

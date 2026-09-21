# Everything the visual regression tests need: the environment that pins what
# Chromium renders with, the runner that reaches Playwright, and the command
# that refreshes the baselines on CI.
#
# Apart from the rest of the flake because the VRT answers to a different
# question than the other commands do -- not "what does this project build
# with" but "what does a screenshot of it look like, and whose screenshot
# counts". `AGENTS.md` holds the reasoning; what is here is the mechanism.
{ pkgs, elmTools }:

let
  playwrightModules = "${pkgs.playwright-test}/lib/node_modules";

in
rec {
  # What a screenshot is taken with. The fonts are named rather than left to
  # the host, because a baseline rendered against fonts a machine happens to
  # have is a baseline only that machine can reproduce.
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

  # The baselines are rendered on CI's Linux, so refreshing them means
  # dispatching the workflow that renders them. Doing that by hand asked for
  # the branch twice -- once to dispatch on, once as an input to push to --
  # and the two could disagree. Here the branch is read off the checkout, so
  # it cannot.
  #
  # This is the only `gh` reachable through `nix run`, against the rule set
  # out beside the devShell, and it is one because it is a project command
  # rather than the tool: it takes no arguments, and one workflow is its
  # whole surface.
  #
  # The script is a file rather than a string here: it is sixty lines of
  # shell with nothing for Nix to interpolate, and a file is what shellcheck
  # and an editor can read.
  updateSnapshotsCiApp = pkgs.writeShellApplication {
    name = "update-snapshots-ci";
    runtimeInputs = [ pkgs.gh pkgs.git ];
    text = builtins.readFile ./update-snapshots-ci.sh;
  };
}

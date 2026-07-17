use Sys.Console
use Sys.Env
use Sys.Exit

///
/// deps-audit: audit helpers for the update-deps skill.
///
/// Flix port of the Rust implementation in ../scripts. Subcommands are
/// added incrementally; unimplemented ones exit with an error so the
/// Rust version remains authoritative until parity is verified.
///
def main(): Unit \ {Env, Exit, Console} =
    let code = match Env.getArgs() {
        case cmd :: Nil => dispatch(cmd)
        case _          => usage()
    };
    Exit.exit(code)

def dispatch(cmd: String): Int32 \ Console =
    let known =
        "npm-security-audit" :: "npm-outdated-audit" :: "npm-pin-versions" ::
        "elm-versions-report" ::
        "elm-pages-audit" :: "elm-pages-compat-key" :: "elm-pages-elm-guard" :: "elm-pages-vite-version" ::
        "rust-major-audit" :: "rust-minor-audit" ::
        "nix-channel-audit" :: "nix-flakelock-audit" :: Nil;
    if (List.memberOf(cmd, known)) {
        Console.eprintln("${cmd}: not yet implemented in the Flix port — use the Rust version (scripts/)");
        1
    } else {
        usage()
    }

def usage(): Int32 \ Console =
    Console.eprintln("usage: deps-audit <subcommand>");
    Console.eprintln("");
    Console.eprintln("subcommands:");
    Console.eprintln("  npm-security-audit");
    Console.eprintln("  npm-outdated-audit");
    Console.eprintln("  npm-pin-versions");
    Console.eprintln("  elm-versions-report");
    Console.eprintln("  elm-pages-audit");
    Console.eprintln("  elm-pages-compat-key");
    Console.eprintln("  elm-pages-elm-guard");
    Console.eprintln("  elm-pages-vite-version");
    Console.eprintln("  rust-major-audit");
    Console.eprintln("  rust-minor-audit");
    Console.eprintln("  nix-channel-audit");
    Console.eprintln("  nix-flakelock-audit");
    1

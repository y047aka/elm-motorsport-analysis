mod elm;
mod elm_pages;
mod nix;
mod npm;
mod rust_audit;

use std::process;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str());

    let result = match cmd {
        Some("npm-security-audit") => npm::security_audit(),
        Some("npm-outdated-audit") => npm::outdated_audit(),
        Some("npm-pin-versions") => npm::pin_versions(),
        Some("elm-versions-report") => elm::versions_report(),
        Some("elm-pages-audit") => elm_pages::audit(),
        Some("elm-pages-compat-key") => elm_pages::compat_key(),
        Some("elm-pages-elm-guard") => elm_pages::elm_guard(),
        Some("elm-pages-vite-version") => elm_pages::vite_version(),
        Some("rust-major-audit") => rust_audit::major_audit(),
        Some("rust-minor-audit") => rust_audit::minor_audit(),
        Some("nix-channel-audit") => nix::channel_audit(),
        Some("nix-flakelock-audit") => nix::flakelock_audit(),
        _ => {
            eprintln!(
                "usage: deps-audit <subcommand>\n\nsubcommands:\n  \
                 npm-security-audit\n  npm-outdated-audit\n  npm-pin-versions\n  \
                 elm-versions-report\n  \
                 elm-pages-audit\n  elm-pages-compat-key\n  elm-pages-elm-guard\n  elm-pages-vite-version\n  \
                 rust-major-audit\n  rust-minor-audit\n  \
                 nix-channel-audit\n  nix-flakelock-audit"
            );
            process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("{e}");
        process::exit(1);
    }
}

use std::env;
use std::process;

use cli::Config;

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_target(false)
        .init();

    let config = Config::build(env::args()).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });

    let summary = cli::run(config);
    if summary.errors > 0 {
        process::exit(1);
    }
}

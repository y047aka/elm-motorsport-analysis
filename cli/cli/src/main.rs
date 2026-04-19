use std::env;
use std::process;

use cli::Config;

fn main() {
    let config = Config::build(env::args()).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });

    match cli::run(config) {
        Ok(summary) if summary.errors > 0 => {
            process::exit(1);
        }
        Err(e) => {
            eprintln!("Application error: {e}");
            process::exit(1);
        }
        _ => {}
    }
}

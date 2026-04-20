use std::env;
use std::process;

use cli::{Config, FileResult};

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_target(false)
        .init();

    let config = Config::build(env::args()).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });

    let mut processed = 0;
    let mut errors = 0;
    for result in cli::run(config) {
        match result {
            FileResult::Processed {
                input_path,
                report,
            } => {
                log::info!(
                    "Read {} cars from CSV '{}'",
                    report.car_count,
                    input_path.display()
                );
                log::info!("Wrote metadata JSON to {}", report.metadata_path.display());
                log::info!("Wrote laps JSON to {}", report.laps_path.display());
                processed += 1;
            }
            FileResult::Failed { input_path, error } => {
                log::error!("Error processing '{}': {}", input_path.display(), error);
                errors += 1;
            }
        }
    }

    log::info!(
        "Processing completed: {} processed, {} errors",
        processed, errors
    );

    if errors > 0 {
        process::exit(1);
    }
}

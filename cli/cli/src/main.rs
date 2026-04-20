use std::env;
use std::process;

use cli::parse_args;

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_target(false)
        .init();

    let tasks = parse_args(env::args()).unwrap_or_else(|err| {
        eprintln!("Problem parsing arguments: {err}");
        process::exit(1);
    });

    let (processed, errors) = cli::run(tasks).fold((0u32, 0u32), |(processed, errors), outcome| {
        match &outcome.result {
            Ok(report) => {
                log::info!(
                    "Read {} cars from CSV '{}'",
                    report.car_count,
                    outcome.input_path.display()
                );
                log::info!("Wrote metadata JSON to {}", report.metadata_path.display());
                log::info!("Wrote laps JSON to {}", report.laps_path.display());
                (processed + 1, errors)
            }
            Err(error) => {
                log::error!(
                    "Error processing '{}': {}",
                    outcome.input_path.display(),
                    error
                );
                (processed, errors + 1)
            }
        }
    });

    log::info!(
        "Processing completed: {} processed, {} errors",
        processed, errors
    );

    if errors > 0 {
        process::exit(1);
    }
}

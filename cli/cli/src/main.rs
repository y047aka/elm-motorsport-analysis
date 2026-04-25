use std::env;
use std::process::ExitCode;

fn main() -> ExitCode {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_target(false)
        .init();

    match cli::run(env::args()) {
        Ok(summary) if summary.errors == 0 => ExitCode::SUCCESS,
        Ok(_) => ExitCode::FAILURE,
        Err(err) => {
            eprintln!("Problem parsing arguments: {err}");
            ExitCode::FAILURE
        }
    }
}

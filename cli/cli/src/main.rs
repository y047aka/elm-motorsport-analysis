use std::env;
use std::process::ExitCode;

fn main() -> ExitCode {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .format_target(false)
        .init();

    match cli::run(env::args()) {
        Ok(summary) => summary.exit_code(),
        Err(err) => {
            eprintln!("{}", cli::WithChain(&err));
            ExitCode::FAILURE
        }
    }
}

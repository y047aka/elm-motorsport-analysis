use std::path::PathBuf;

use thiserror::Error;

/// Errors raised during the setup phase: argv parsing and input-path
/// resolution. Surfaced as `Err` from [`run`](crate::run).
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum SetupError {
    #[error("Missing required input path argument")]
    MissingInputPath,

    #[error("Unexpected argument: {0}")]
    UnexpectedArgument(String),

    #[error("Input path does not exist: {}", .0.display())]
    InputPathNotFound(PathBuf),

    #[error("Input path is neither a file nor directory: {}", .0.display())]
    InvalidInputPath(PathBuf),

    #[error("--output requires a value")]
    MissingOutputValue,

    #[error("--output cannot be used with directory input")]
    OutputWithDirectory,

    #[error("--output specified more than once")]
    DuplicateOutput,

    #[error("No CSV files found in directory: {}", .0.display())]
    NoCsvFilesFound(PathBuf),

    #[error("Failed to walk directory '{}': {source}", path.display())]
    WalkDir {
        path: PathBuf,
        #[source]
        source: walkdir::Error,
    },
}

/// Errors raised while processing a single file. Logged and counted in
/// [`RunSummary`](crate::RunSummary) rather than bubbled up from
/// [`run`](crate::run).
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum FileError {
    #[error("Failed to read input file '{}': {source}", path.display())]
    ReadFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to write file '{}': {source}", path.display())]
    WriteFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to serialize {context} to JSON: {source}")]
    Serialize {
        context: &'static str,
        #[source]
        source: serde_json::Error,
    },
}

/// Display adapter that renders an error and its full `source()` chain.
///
/// `thiserror`'s generated `Display` only prints the outermost error, so the
/// underlying `io::Error` / `walkdir::Error` reason is invisible by default.
/// Wrap an error in `WithChain` whenever it crosses a user-visible boundary
/// (stderr, log) to surface the root cause.
pub struct WithChain<'a, E: ?Sized>(pub &'a E);

impl<E: std::error::Error + ?Sized> std::fmt::Display for WithChain<'_, E> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)?;
        let mut source = self.0.source();
        while let Some(e) = source {
            write!(f, "\n  caused by: {e}")?;
            source = e.source();
        }
        Ok(())
    }
}

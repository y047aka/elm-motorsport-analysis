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

    #[error("Failed to walk directory '{}'", path.display())]
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
    #[error("Failed to read input file '{}'", path.display())]
    ReadFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to write file '{}'", path.display())]
    WriteFile {
        path: PathBuf,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to serialize {context} to JSON")]
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
///
/// The variants in this module deliberately omit `{source}` from their outer
/// `#[error]` format strings — the chain is rendered exclusively by this
/// adapter, so embedding the source in the outer message would duplicate it.
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn with_chain_renders_io_source_once() {
        let err = FileError::ReadFile {
            path: PathBuf::from("/missing"),
            source: std::io::Error::new(std::io::ErrorKind::NotFound, "no such file"),
        };
        let rendered = format!("{}", WithChain(&err));

        assert!(rendered.starts_with("Failed to read input file '/missing'"));
        assert!(rendered.contains("\n  caused by: no such file"));
        // Outer Display must not embed the source — otherwise the chain
        // walker would print it a second time.
        assert_eq!(rendered.matches("no such file").count(), 1);
    }

    #[test]
    fn with_chain_on_setup_error_without_source_prints_only_outer() {
        let err = SetupError::MissingInputPath;
        let rendered = format!("{}", WithChain(&err));
        assert_eq!(rendered, "Missing required input path argument");
    }

    #[test]
    fn with_chain_renders_serialize_source() {
        // Build a serde_json::Error by deserializing invalid JSON.
        let json_err = serde_json::from_str::<i32>("not json").unwrap_err();
        let err = FileError::Serialize {
            context: "metadata",
            source: json_err,
        };
        let rendered = format!("{}", WithChain(&err));

        assert!(rendered.starts_with("Failed to serialize metadata to JSON"));
        assert!(rendered.contains("\n  caused by: "));
    }
}

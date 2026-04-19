use thiserror::Error;

#[derive(Debug, Error)]
pub enum CliError {
    // Config errors
    #[error("Missing required input path argument")]
    MissingInputPath,

    #[error("Unexpected argument: {0}")]
    UnexpectedArgument(String),

    #[error("Input path does not exist: {0}")]
    InputPathNotFound(String),

    #[error("Input path is neither a file nor directory: {0}")]
    InvalidInputPath(String),

    #[error("--output cannot be used with directory input")]
    OutputWithDirectory,

    #[error("No CSV files found in directory: {0}")]
    NoCsvFilesFound(String),

    // I/O errors (with path context)
    #[error("Failed to read directory '{path}': {source}")]
    ReadDir {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to read directory entry: {0}")]
    ReadDirEntry(#[source] std::io::Error),

    #[error("Failed to read input file '{path}': {source}")]
    ReadFile {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("Failed to write file '{path}': {source}")]
    WriteFile {
        path: String,
        #[source]
        source: std::io::Error,
    },

    // Serialization
    #[error("Failed to serialize {context} to JSON: {source}")]
    Serialize {
        context: &'static str,
        #[source]
        source: serde_json::Error,
    },
}

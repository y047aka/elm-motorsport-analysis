// Entry point for the Tauri v2 app.
//
// The window loads the frontend build (app/dist), and the API it reads is
// started here: `sidecar/` holds the server's jar and a JVM to run it on, and
// the frontend reaches it at http://127.0.0.1:8080 rather than same-origin,
// because the page is tauri://localhost.
//
// Nothing here fails the launch. A machine with no database, or one where the
// JVM will not start, leaves the frontend to read the export bundled beside it.

use std::env;
use std::path::PathBuf;
use std::process::{Child, Command};
use std::sync::Mutex;

use tauri::path::BaseDirectory;
use tauri::{Manager, RunEvent};

/// The URL `nix run .#pg-start` prints, which is the database a working copy
/// has. `DATABASE_URL` names another.
const DEFAULT_DATABASE_URL: &str = "jdbc:postgresql://127.0.0.1:55433/motorsport?user=postgres";

/// The port `index.ts` looks for the server on.
const PORT: &str = "8080";

struct Server(Mutex<Option<Child>>);

fn spawn(app: &tauri::AppHandle) -> Result<Child, String> {
    let sidecar: PathBuf = app
        .path()
        .resolve("sidecar", BaseDirectory::Resource)
        .map_err(|e| format!("no sidecar in this build ({e})"))?;
    let java = sidecar
        .join("jre/bin")
        .join(if cfg!(windows) { "java.exe" } else { "java" });
    // `lib/*` is the JVM's own wildcard: the JDBC driver is on the class path
    // beside the jar rather than inside it.
    let class_path = env::join_paths([sidecar.join("api.jar"), sidecar.join("lib/*")])
        .map_err(|e| format!("could not build the class path ({e})"))?;
    Command::new(java)
        .args(["-cp"])
        .arg(class_path)
        .args(["Main", "--serve", "--port", PORT])
        .env(
            "DATABASE_URL",
            env::var("DATABASE_URL").unwrap_or_else(|_| DEFAULT_DATABASE_URL.to_string()),
        )
        .spawn()
        .map_err(|e| format!("could not start the server ({e})"))
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(Server(Mutex::new(None)))
        .setup(|app| {
            match spawn(app.handle()) {
                Ok(child) => *app.state::<Server>().0.lock().unwrap() = Some(child),
                Err(cause) => eprintln!("API: {cause}"),
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            // The JVM is a child of this process and would outlive it, holding
            // the port against the next launch.
            if let RunEvent::Exit = event {
                if let Some(mut child) = app.state::<Server>().0.lock().unwrap().take() {
                    let _ = child.kill();
                    let _ = child.wait();
                }
            }
        });
}

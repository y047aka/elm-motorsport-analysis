// Entry point for the Tauri v2 app.
//
// The window loads the frontend build (app/dist) over http from a server of
// its own rather than from `tauri://localhost`: Elm's `Browser.application`
// reads the page's location through `Url.fromString`, which takes no scheme
// but http and https and crashes on anything else.
//
// What the page reads is started here: `sidecar/` holds a PostgreSQL, the rows
// to fill it with, the server's jar and a JVM to run it on. The API is another
// port, so it is another origin than the page.
//
// Nothing here fails the launch. A database that will not start, or a JVM that
// will not, leaves the frontend to read the export bundled beside it.

use std::env;
use std::path::{Path, PathBuf};
use std::process::{Child, Command};
use std::sync::Mutex;

use tauri::path::BaseDirectory;
use tauri::{Manager, RunEvent, WebviewUrl, WebviewWindowBuilder};

/// The port `index.ts` looks for the server on.
const API_PORT: &str = "8080";

/// Where the frontend is served from, which is what the window opens.
const PAGE_PORT: u16 = 1430;

/// Not 55433, which is the working copy's: a checkout and the installed app
/// are two databases, and only one of them is rebuilt by a run of the CLI.
const DATABASE_PORT: &str = "55434";

#[derive(Default)]
struct Services {
    api: Option<Child>,
    database: Option<PathBuf>,
}

fn sidecar(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .resolve("sidecar", BaseDirectory::Resource)
        .map_err(|e| format!("no sidecar in this build ({e})"))
}

/// The database this launch reads. `DATABASE_URL` is one someone else is
/// keeping -- a checkout's, say -- and is taken as it is; otherwise the bundled
/// one is started, and initialised the first time.
fn database(app: &tauri::AppHandle, sidecar: &Path, services: &mut Services) -> Result<String, String> {
    if let Ok(named) = env::var("DATABASE_URL") {
        return Ok(named);
    }
    let data = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("no application directory ({e})"))?
        .join("pg");
    if !data.join("PG_VERSION").exists() {
        run_program(
            sidecar.join("pg/bin/initdb"),
            &[
                "-D".as_ref(),
                data.as_os_str(),
                "-U".as_ref(),
                "postgres".as_ref(),
                "-A".as_ref(),
                "trust".as_ref(),
                "--no-locale".as_ref(),
                "--encoding=UTF8".as_ref(),
            ],
        )?;
    }
    // A launch that found one already up leaves it running, and leaves
    // stopping it to whoever started it.
    let pg_ctl = sidecar.join("pg/bin/pg_ctl");
    let running = run_program(pg_ctl.clone(), &["-D".as_ref(), data.as_os_str(), "status".as_ref()]).is_ok();
    if !running {
        // `-o` is split on spaces by `pg_ctl`, and the data directory's path
        // holds one, so the socket directory cannot be named in it. Nothing
        // here connects over a socket: the driver speaks TCP.
        run_program(
            pg_ctl,
            &[
                "-D".as_ref(),
                data.as_os_str(),
                "-l".as_ref(),
                data.join("server.log").as_os_str(),
                "-o".as_ref(),
                format!("-p {DATABASE_PORT} -c listen_addresses=127.0.0.1 -c unix_socket_directories=")
                    .as_ref(),
                "-w".as_ref(),
                "start".as_ref(),
            ],
        )?;
        services.database = Some(data);
    }
    Ok(format!(
        "jdbc:postgresql://127.0.0.1:{DATABASE_PORT}/postgres?user=postgres"
    ))
}

/// The rows are the ones the build was made from, and are loaded into a
/// database that has none: an installed app seeds itself once.
fn start_api(sidecar: &Path, database: &str) -> Result<Child, String> {
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
        .args(["Main", "--serve", "--port", API_PORT, "--postgres"])
        .arg(database)
        .arg("--seed")
        .arg(sidecar.join("laps.tsv.gz"))
        .spawn()
        .map_err(|e| format!("could not start the server ({e})"))
}

fn run_program(program: PathBuf, args: &[&std::ffi::OsStr]) -> Result<(), String> {
    let named = program.display().to_string();
    let status = Command::new(&program)
        .args(args)
        .status()
        .map_err(|e| format!("could not run {named} ({e})"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{named} exited with {status}"))
    }
}

fn start(app: &tauri::AppHandle, services: &mut Services) -> Result<(), String> {
    let sidecar = sidecar(app)?;
    let database = database(app, &sidecar, services)?;
    services.api = Some(start_api(&sidecar, &database)?);
    Ok(())
}

fn stop(app: &tauri::AppHandle, services: &mut Services) {
    // Both outlive this process if they are left: the JVM holds the port
    // against the next launch, and the database holds its own data directory.
    if let Some(mut api) = services.api.take() {
        let _ = api.kill();
        let _ = api.wait();
    }
    if let Some(data) = services.database.take() {
        if let Ok(sidecar) = sidecar(app) {
            let _ = run_program(
                sidecar.join("pg/bin/pg_ctl"),
                &[
                    "-D".as_ref(),
                    data.as_os_str(),
                    "-m".as_ref(),
                    "fast".as_ref(),
                    "stop".as_ref(),
                ],
            );
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_localhost::Builder::new(PAGE_PORT).build())
        .manage(Mutex::new(Services::default()))
        .setup(|app| {
            let handle = app.handle().clone();
            {
                let state = app.state::<Mutex<Services>>();
                let mut services = state.lock().unwrap();
                if let Err(cause) = start(&handle, &mut services) {
                    eprintln!("API: {cause}");
                }
            }
            WebviewWindowBuilder::new(
                app,
                "main",
                WebviewUrl::External(format!("http://localhost:{PAGE_PORT}").parse()?),
            )
            .title("Motorsport Analysis")
            .inner_size(1440.0, 900.0)
            .min_inner_size(1024.0, 640.0)
            .build()?;
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app, event| {
            if let RunEvent::Exit = event {
                let state = app.state::<Mutex<Services>>();
                let mut services = state.lock().unwrap();
                stop(app, &mut services);
            }
        });
}

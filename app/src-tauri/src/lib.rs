// Entry point for the Tauri v2 app.
//
// The window is opened over http rather than over the `tauri://localhost` a
// bundle serves its assets from. Elm's `Browser.application` reads the page's
// location through `Url.fromString`, which takes no scheme but http and https;
// on anything else the program crashes on the first line it runs, and
// `--optimize` leaves that crash without a message, so the window is simply
// blank. macOS and Linux have no configuration for this: `useHttpsScheme` and
// `dangerousUseHttpScheme` are Windows and Android only.
//
// `tauri-plugin-localhost` serves those same embedded assets on a port
// instead. A dev build embeds none of them -- the assets are the Vite server's
// -- so the window opens `devUrl` there and the plugin is left out.

use tauri::{WebviewUrl, WebviewWindowBuilder};

/// Where a bundle serves its own assets. Not 1234, which is Vite's, nor 8080,
/// which is the API's: a checkout can be running either while the bundle runs.
const PAGE_PORT: u16 = 1430;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let mut builder = tauri::Builder::default();
    if !tauri::is_dev() {
        builder = builder.plugin(tauri_plugin_localhost::Builder::new(PAGE_PORT).build());
    }
    builder
        .setup(|app| {
            let page = if tauri::is_dev() {
                WebviewUrl::default()
            } else {
                WebviewUrl::External(format!("http://localhost:{PAGE_PORT}").parse()?)
            };
            WebviewWindowBuilder::new(app, "main", page)
                .title("Motorsport Analysis")
                .inner_size(1440.0, 900.0)
                .min_inner_size(1024.0, 640.0)
                .build()?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

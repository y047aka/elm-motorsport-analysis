// Entry point for the Tauri v2 app.
//
// No extra native features (plugins / commands) are wired up yet. The existing
// frontend runs unchanged because:
//   - the elm-pages build output (app/dist) is served as frontendDist
//   - race data (/static/wec/**/*.json) and images live at the dist root, so
//     Http.get's absolute paths "/static/..." resolve same-origin as
//     tauri://localhost/static/... (no extra permissions required)
//
// To move logic into the Rust backend later, register tauri::command here.
// Data processing itself belongs to the CLI (/flix), which writes the JSON
// this app reads; there is no Rust port of it to link against.

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

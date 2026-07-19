// Tauri v2 アプリのエントリポイント。
//
// PoC 段階では追加のネイティブ機能（プラグイン / コマンド）は導入していない。
// 既存フロントエンドは以下の理由により無改修で動作する見込み:
//   - elm-pages のビルド出力（app/dist）を frontendDist として配信する
//   - レースデータ（/static/wec/**/*.json）や画像は dist ルートに含まれるため、
//     Http.get の絶対パス "/static/..." は tauri://localhost/static/... として
//     同一オリジンで解決される（追加の権限付与は不要）
//
// 将来 Rust バックエンドへ機能を寄せる場合は、ここに tauri::command を登録し、
// motorsport クレート（../../cli/motorsport）を取り込んでデータ処理を行う。

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

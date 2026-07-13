// MDness — native Windows Markdown viewer/editor (Tauri v2 + WebView2).
// Shares its rendering pipeline (markdown-it + mermaid) and web assets
// byte-for-byte with the macOS and Linux apps; see ../../web and build.rs.
//
// The Rust side is deliberately thin: file dialogs come from tauri-plugin-dialog
// (called from the frontend), and these two commands are the only native I/O.
// Everything else — toolbar, editor, live preview, export — lives in ../ui.
//
// MIT © 2026 David Feher
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;

#[tauri::command]
fn read_file(path: String) -> Result<String, String> {
    fs::read_to_string(&path).map_err(|e| e.to_string())
}

#[tauri::command]
fn write_file(path: String, contents: String) -> Result<(), String> {
    fs::write(&path, contents).map_err(|e| e.to_string())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![read_file, write_file])
        .run(tauri::generate_context!())
        .expect("error while running MDness");
}

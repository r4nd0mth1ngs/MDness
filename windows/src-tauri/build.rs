use std::{env, fs, path::Path};

fn main() {
    copy_web_assets();
    tauri_build::build();
}

// Reuse the shared render pipeline byte-for-byte. `web/` is the single source of
// truth across macOS, Linux and Windows; copy its 4 runtime assets into the
// bundled frontend dir (windows/ui/vendor) at build time so nothing is
// duplicated in git.
// ponytail: build.rs copy keeps one source of truth. A committed copy would put
// the 3.5 MB mermaid bundle in git twice; a shell/node copy step would not be
// portable to a Windows build host the way std::fs is.
fn copy_web_assets() {
    let manifest = env::var("CARGO_MANIFEST_DIR").unwrap();
    let src = Path::new(&manifest).join("..").join("..").join("web");
    let dst = Path::new(&manifest).join("..").join("ui").join("vendor");
    fs::create_dir_all(&dst).expect("create ui/vendor");
    for f in ["app.js", "markdown-it.min.js", "mermaid.min.js", "mdness.css"] {
        fs::copy(src.join(f), dst.join(f))
            .unwrap_or_else(|e| panic!("copy {f} from ../../web: {e}"));
    }
    println!("cargo:rerun-if-changed={}", src.display());
}

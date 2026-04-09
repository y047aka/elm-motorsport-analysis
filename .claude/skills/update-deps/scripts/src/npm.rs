use std::collections::BTreeMap;
use std::fs;
use std::io::Read;

use serde::Deserialize;
use serde_json::Value;

// --- npm-security-audit ---

pub fn security_audit() -> Result<(), String> {
    let input = read_stdin().trim().to_string();
    if input.is_empty() {
        println!("--- vulnerabilities ---");
        println!("none");
        println!();
        println!("--- summary ---");
        println!("total: 0");
        return Ok(());
    }

    let data: Value = serde_json::from_str(&input).map_err(|e| format!("unexpected npm audit format: {e}"))?;
    let vulns = match data["vulnerabilities"].as_object() {
        Some(v) => v,
        None => {
            println!("--- vulnerabilities ---");
            println!("none");
            println!();
            println!("--- summary ---");
            println!("total: 0");
            return Ok(());
        }
    };

    let total = vulns.len();
    let mut lines: Vec<String> = Vec::new();
    let mut fixable = 0u32;
    let mut fixable_breaking = 0u32;

    for (name, info) in vulns {
        let severity = info["severity"].as_str().unwrap_or("unknown");

        // Build description from via entries
        let via = info["via"].as_array();
        let titles: Vec<&str> = via
            .iter()
            .flat_map(|arr| arr.iter())
            .filter_map(|v| {
                if v.is_object() {
                    v["title"].as_str()
                } else {
                    None
                }
            })
            .collect();
        let via_names: Vec<&str> = via
            .iter()
            .flat_map(|arr| arr.iter())
            .filter_map(|v| v.as_str())
            .collect();

        let desc = if !titles.is_empty() {
            titles[0].to_string()
        } else if !via_names.is_empty() {
            format!("via {}", via_names.join(", "))
        } else {
            String::new()
        };

        // Fix availability
        let fix_available = &info["fixAvailable"];
        let (fix_str, fix_kind) = if fix_available.is_boolean() {
            if fix_available.as_bool().unwrap_or(false) {
                ("fix available".to_string(), "fixable")
            } else {
                ("no fix available".to_string(), "none")
            }
        } else if fix_available.is_object() {
            let fa_name = fix_available["name"].as_str().unwrap_or("");
            let fa_version = fix_available["version"].as_str().unwrap_or("");
            let is_major = fix_available["isSemVerMajor"].as_bool().unwrap_or(false);
            if is_major {
                (
                    format!("fix: {fa_name}@{fa_version} (BREAKING)"),
                    "breaking",
                )
            } else {
                (format!("fix: {fa_name}@{fa_version}"), "fixable")
            }
        } else {
            ("no fix available".to_string(), "none")
        };

        match fix_kind {
            "fixable" => fixable += 1,
            "breaking" => fixable_breaking += 1,
            _ => {}
        }

        lines.push(format!("{name} ({severity}): {desc} — {fix_str}"));
    }

    println!("--- vulnerabilities ---");
    println!("{}", if lines.is_empty() { "none".to_string() } else { lines.join("\n") });
    println!();
    println!("--- summary ---");
    println!("total: {total}");
    println!("fixable: {fixable}");
    println!("fixable-breaking: {fixable_breaking}");

    Ok(())
}

// --- npm-outdated-audit ---

pub fn outdated_audit() -> Result<(), String> {
    let input = read_stdin().trim().to_string();
    if input.is_empty() {
        println!("--- minor updates ---");
        println!("none");
        println!();
        println!("--- major updates ---");
        println!("none");
        return Ok(());
    }

    let data: BTreeMap<String, OutdatedInfo> =
        serde_json::from_str(&input).map_err(|e| format!("unexpected npm outdated format: {e}"))?;

    let mut minor: Vec<String> = Vec::new();
    let mut major: Vec<String> = Vec::new();

    for (name, info) in &data {
        let dep = info.dependent.as_deref().unwrap_or("");
        if info.current != info.wanted {
            minor.push(format!("{name}: {} -> {} ({dep})", info.current, info.wanted));
        }
        if info.latest != info.wanted {
            major.push(format!("{name}: {} -> {} ({dep})", info.current, info.latest));
        }
    }

    let playwright_changed = data.get("@playwright/test").is_some_and(|pw| {
        pw.current != pw.wanted || {
            let cur_major: u64 = pw.current.split('.').next().and_then(|s| s.parse().ok()).unwrap_or(0);
            let lat_major: u64 = pw.latest.split('.').next().and_then(|s| s.parse().ok()).unwrap_or(0);
            lat_major > cur_major
        }
    });

    println!("--- minor updates ---");
    println!("{}", if minor.is_empty() { "none".to_string() } else { minor.join("\n") });
    println!();
    println!("--- major updates ---");
    println!("{}", if major.is_empty() { "none".to_string() } else { major.join("\n") });
    println!();
    println!("--- flags ---");
    println!("playwright-changed: {playwright_changed}");

    if let Some(vite) = data.get("vite") {
        let cwd = std::env::current_dir().map_err(|e| e.to_string())?;
        let nested = cwd.join("node_modules/elm-pages/node_modules/vite/package.json");
        let hoisted = cwd.join("node_modules/vite/package.json");
        let bundled_pkg = if nested.exists() { &nested } else { &hoisted };

        let bundled_major = if bundled_pkg.exists() {
            let raw = fs::read_to_string(bundled_pkg).map_err(|e| e.to_string())?;
            let pkg: Value = serde_json::from_str(&raw).map_err(|e| e.to_string())?;
            pkg["version"]
                .as_str()
                .and_then(|v| v.split('.').next())
                .and_then(|s| s.parse::<u64>().ok())
                .map(|n| n.to_string())
                .unwrap_or_else(|| "unknown".to_string())
        } else {
            "unknown".to_string()
        };

        println!();
        println!("--- vite ---");
        println!("current: {}", vite.current);
        println!("latest: {}", vite.latest);
        println!("bundled-major: {bundled_major}");
    }

    Ok(())
}

#[derive(Deserialize)]
struct OutdatedInfo {
    current: String,
    wanted: String,
    latest: String,
    dependent: Option<String>,
}

// --- npm-pin-versions ---

pub fn pin_versions() -> Result<(), String> {
    let lock_raw = fs::read_to_string("package-lock.json")
        .map_err(|e| format!("package-lock.json: {e}"))?;
    let lock: Value =
        serde_json::from_str(&lock_raw).map_err(|e| format!("package-lock.json: {e}"))?;

    let workspaces: &[(&str, &str)] = &[
        ("package.json", ""),
        ("app/package.json", "app"),
        ("package/package.json", "package"),
        ("review/package.json", "review"),
    ];

    for &(file, ws_prefix) in workspaces {
        let raw = fs::read_to_string(file).map_err(|e| format!("{file}: {e}"))?;
        let mut pkg: Value = serde_json::from_str(&raw).map_err(|e| format!("{file}: {e}"))?;

        for key in &["dependencies", "devDependencies"] {
            if let Some(deps) = pkg[key].as_object_mut() {
                for (name, ver) in deps.iter_mut() {
                    let resolved = resolve_version(&lock, name, ws_prefix);
                    if let Some(resolved_ver) = resolved {
                        *ver = Value::String(resolved_ver);
                    } else {
                        // Strip ^/~ prefix as fallback
                        if let Some(s) = ver.as_str() {
                            let stripped = s.trim_start_matches(|c| c == '^' || c == '~');
                            *ver = Value::String(stripped.to_string());
                        }
                    }
                }
            }
        }

        let output = serde_json::to_string_pretty(&pkg).map_err(|e| e.to_string())? + "\n";
        fs::write(file, output).map_err(|e| format!("{file}: {e}"))?;
    }

    Ok(())
}

fn resolve_version(lock: &Value, name: &str, ws_prefix: &str) -> Option<String> {
    if !ws_prefix.is_empty() {
        let key = format!("{ws_prefix}/node_modules/{name}");
        if let Some(v) = lock["packages"][&key]["version"].as_str() {
            return Some(v.to_string());
        }
    }
    let key = format!("node_modules/{name}");
    lock["packages"][&key]["version"]
        .as_str()
        .map(|s| s.to_string())
}

// --- helpers ---

fn read_stdin() -> String {
    let mut buf = String::new();
    std::io::stdin().read_to_string(&mut buf).unwrap_or(0);
    buf
}

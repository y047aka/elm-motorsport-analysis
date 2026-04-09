use std::fs;
use std::io::Read;
use std::path::Path;

use regex::Regex;
use serde_json::Value;

pub fn audit() -> Result<(), String> {
    // --- stdin: latest version from npm view ---
    let latest_raw = read_stdin().trim().to_string();
    let latest = if latest_raw.is_empty() { None } else { Some(latest_raw) };

    // --- 1. Current elm-pages version from app/package.json ---
    let app_pkg: Value = read_json("app/package.json")?;
    let current = app_pkg["dependencies"]["elm-pages"]
        .as_str()
        .or_else(|| app_pkg["devDependencies"]["elm-pages"].as_str())
        .unwrap_or("unknown");

    println!("--- elm-pages version ---");
    println!("current: {current}");
    match &latest {
        Some(v) => {
            println!("latest:  {v}");
            println!(
                "status:  {}",
                if current == v { "up to date" } else { "update available" }
            );
        }
        None => println!("latest:  unknown (npm view failed)"),
    }

    // --- 2. dillonkearns/* packages from app/elm.json ---
    let elm_json: Value = read_json("app/elm.json")?;
    let deps = &elm_json["dependencies"];
    let direct = collect_dillonkearns(&deps["direct"]);
    let indirect = collect_dillonkearns(&deps["indirect"]);

    println!();
    println!("--- dillonkearns packages (app/elm.json) ---");
    for (name, version) in &direct {
        println!("{name}: {version} (direct)");
    }
    for (name, version) in &indirect {
        println!("{name}: {version} (indirect)");
    }

    println!();
    println!("--- restore commands (for /update-deps elm) ---");
    for (name, version) in &direct {
        println!("elm-json install --yes '{name}@{version}' -- app/elm.json");
    }

    // --- 3. compatibilityKey matching ---
    println!();
    println!("--- compatibilityKey ---");

    let cwd = std::env::current_dir().map_err(|e| e.to_string())?;
    let npm_key_file =
        cwd.join("node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm");

    if !npm_key_file.exists() {
        println!("npmKey: unknown (file not found — run npm install first)");
        return Ok(());
    }

    let npm_key = match parse_compat_key(&npm_key_file)? {
        Some(k) => k,
        None => {
            println!("npmKey: unknown (could not parse)");
            return Ok(());
        }
    };
    println!("npmKey: {npm_key}");

    let home = match std::env::var("HOME") {
        Ok(h) => h,
        Err(_) => {
            println!("matchingElmVersion: unknown (HOME not set)");
            return Ok(());
        }
    };

    let cache_dir = format!("{home}/.elm/0.19.1/packages/dillonkearns/elm-pages");
    if !Path::new(&cache_dir).exists() {
        println!("matchingElmVersion: no-match");
        println!(
            "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json"
        );
        return Ok(());
    }

    match find_matching_version(&cache_dir, npm_key)? {
        Some(v) => println!("matchingElmVersion: {v}"),
        None => {
            println!("matchingElmVersion: no-match");
            println!(
                "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json"
            );
        }
    }

    Ok(())
}

pub fn compat_key() -> Result<(), String> {
    let cwd = std::env::current_dir().map_err(|e| e.to_string())?;
    let npm_key_file =
        cwd.join("node_modules/elm-pages/src/Pages/Internal/Platform/CompatibilityKey.elm");

    if !npm_key_file.exists() {
        return Err(format!(
            "{} not found\nRun npm install first.",
            npm_key_file.display()
        ));
    }

    let npm_key = parse_compat_key(&npm_key_file)?
        .ok_or("could not parse compatibilityKey from npm source")?;
    println!("npmKey: {npm_key}");

    let home = std::env::var("HOME").map_err(|_| "HOME not set".to_string())?;
    let cache_dir = format!("{home}/.elm/0.19.1/packages/dillonkearns/elm-pages");

    if !Path::new(&cache_dir).exists() {
        println!("matchingElmVersion: no-match");
        println!(
            "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json"
        );
        return Ok(());
    }

    match find_matching_version(&cache_dir, npm_key)? {
        Some(v) => println!("matchingElmVersion: {v}"),
        None => {
            println!("matchingElmVersion: no-match");
            println!(
                "Install latest to populate cache: elm-json install --yes 'dillonkearns/elm-pages@latest' -- app/elm.json"
            );
        }
    }

    Ok(())
}

pub fn elm_guard() -> Result<(), String> {
    let elm_json: Value = read_json("app/elm.json")?;
    let deps = &elm_json["dependencies"];
    let direct = collect_dillonkearns(&deps["direct"]);
    let indirect = collect_dillonkearns(&deps["indirect"]);

    println!("--- dillonkearns packages ---");
    for (name, version) in &direct {
        println!("{name}: {version} (direct)");
    }
    for (name, version) in &indirect {
        println!("{name}: {version} (indirect)");
    }

    println!();
    println!("--- restore commands (direct only; indirect restored transitively) ---");
    for (name, version) in &direct {
        println!("elm-json install --yes '{name}@{version}' -- app/elm.json");
    }

    Ok(())
}

pub fn vite_version() -> Result<(), String> {
    let cwd = std::env::current_dir().map_err(|e| e.to_string())?;
    let nested = cwd.join("node_modules/elm-pages/node_modules/vite/package.json");
    let hoisted = cwd.join("node_modules/vite/package.json");
    let pkg_path = if nested.exists() { &nested } else { &hoisted };

    let pkg_str = pkg_path.to_str().ok_or("vite package.json path is not valid UTF-8")?;
    let pkg: Value = read_json(pkg_str)?;
    let version = pkg["version"].as_str().ok_or("vite package.json missing version")?;
    println!("{version}");

    Ok(())
}

// --- helpers ---

fn read_stdin() -> String {
    let mut buf = String::new();
    std::io::stdin().read_to_string(&mut buf).unwrap_or(0);
    buf
}

fn read_json(path: &str) -> Result<Value, String> {
    let raw = fs::read_to_string(path).map_err(|e| format!("{path}: {e}"))?;
    serde_json::from_str(&raw).map_err(|e| format!("{path}: {e}"))
}

fn collect_dillonkearns(obj: &Value) -> Vec<(String, String)> {
    let mut result = Vec::new();
    if let Some(map) = obj.as_object() {
        let mut entries: Vec<_> = map.iter().collect();
        entries.sort_by(|(a, _), (b, _)| a.cmp(b));
        for (name, version) in entries {
            if name.starts_with("dillonkearns/") {
                if let Some(v) = version.as_str() {
                    result.push((name.clone(), v.to_string()));
                }
            }
        }
    }
    result
}

fn parse_compat_key(path: &Path) -> Result<Option<i64>, String> {
    let source = fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let re = Regex::new(r"currentCompatibilityKey\s*=\s*(\d+)").unwrap();
    Ok(re.captures(&source).map(|c| c[1].parse::<i64>().unwrap()))
}

fn find_matching_version(cache_dir: &str, npm_key: i64) -> Result<Option<String>, String> {
    let entries = fs::read_dir(cache_dir).map_err(|e| format!("{cache_dir}: {e}"))?;
    let mut matches: Vec<String> = Vec::new();

    for entry in entries {
        let entry = entry.map_err(|e| e.to_string())?;
        let name = entry.file_name().to_string_lossy().to_string();
        let key_file =
            entry.path().join("src/Pages/Internal/Platform/CompatibilityKey.elm");
        if !key_file.exists() {
            continue;
        }
        if let Some(key) = parse_compat_key(&key_file)? {
            if key == npm_key {
                matches.push(name);
            }
        }
    }

    matches.sort_by(|a, b| compare_semver(a, b));
    Ok(matches.pop())
}

fn compare_semver(a: &str, b: &str) -> std::cmp::Ordering {
    let pa: Vec<u64> = a.split('.').filter_map(|s| s.parse().ok()).collect();
    let pb: Vec<u64> = b.split('.').filter_map(|s| s.parse().ok()).collect();
    let len = pa.len().max(pb.len());
    for i in 0..len {
        let va = pa.get(i).copied().unwrap_or(0);
        let vb = pb.get(i).copied().unwrap_or(0);
        match va.cmp(&vb) {
            std::cmp::Ordering::Equal => continue,
            other => return other,
        }
    }
    std::cmp::Ordering::Equal
}

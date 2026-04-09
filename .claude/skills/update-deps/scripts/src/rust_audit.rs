use std::fs;
use std::io::Read;
use std::process::Command;

use regex::Regex;

// --- rust-major-audit ---

pub fn major_audit() -> Result<(), String> {
    // All Cargo.toml files in the workspace (including deps-audit itself)
    let files = [
        "cli/Cargo.toml",
        "cli/cli/Cargo.toml",
        "cli/motorsport/Cargo.toml",
        ".claude/skills/update-deps/scripts/Cargo.toml",
    ];

    let dep_re =
        Regex::new(r#"^([\w-]+)\s*=\s*(?:"([^"]+)"|.*version\s*=\s*"([^"]+)")"#).unwrap();
    let section_re = Regex::new(r"^\[(workspace\.)?(dev-)?dependencies\]").unwrap();
    let any_section_re = Regex::new(r"^\[").unwrap();

    // Parse all deps from Cargo.toml files, dedup by name
    let mut seen = std::collections::HashMap::new();
    for f in &files {
        let content = match fs::read_to_string(f) {
            Ok(c) => c,
            Err(_) => continue, // skip missing files gracefully
        };
        let mut in_deps = false;
        for line in content.lines() {
            if section_re.is_match(line) {
                in_deps = true;
                continue;
            }
            if any_section_re.is_match(line) {
                in_deps = false;
                continue;
            }
            if !in_deps {
                continue;
            }
            if let Some(caps) = dep_re.captures(line) {
                let name = caps[1].to_string();
                let constraint = caps.get(2).or_else(|| caps.get(3)).unwrap().as_str().to_string();
                seen.entry(name).or_insert(constraint);
            }
        }
    }

    let mut deps: Vec<(String, String)> = seen.into_iter().collect();
    deps.sort_by(|a, b| a.0.cmp(&b.0));

    let mut major_updates: Vec<String> = Vec::new();
    let mut up_to_date: Vec<String> = Vec::new();

    for (name, constraint) in &deps {
        let current = base_version(constraint);
        let latest = fetch_latest_version(name);

        match latest {
            Some(ref lat) if is_major_bump(&current, lat) => {
                major_updates.push(format!("{name}: {current} -> {lat}"));
            }
            Some(ref lat) => {
                up_to_date.push(format!("{name}: {current} (latest {lat})"));
            }
            None => {
                up_to_date.push(format!("{name}: {current} (latest unknown)"));
            }
        }
    }

    println!("--- major updates ---");
    println!(
        "{}",
        if major_updates.is_empty() { "none".to_string() } else { major_updates.join("\n") }
    );
    println!();
    println!("--- up to date ---");
    println!(
        "{}",
        if up_to_date.is_empty() { "none".to_string() } else { up_to_date.join("\n") }
    );

    Ok(())
}

fn fetch_latest_version(name: &str) -> Option<String> {
    let output = Command::new("cargo")
        .args(["search", name, "--limit", "1"])
        .output()
        .ok()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let name_escaped = regex::escape(name).replace(r"\-", "[-_]");
    let line_re = Regex::new(&format!(r#"^{name_escaped}\s.*"([^"]+)""#)).ok()?;

    for line in stdout.lines() {
        if let Some(caps) = line_re.captures(line) {
            return Some(caps[1].to_string());
        }
    }
    None
}

fn base_version(constraint: &str) -> String {
    constraint
        .trim_start_matches(|c: char| matches!(c, '~' | '^' | '>' | '=' | '<'))
        .to_string()
}

fn major_component(version: &str) -> (usize, u64) {
    let parts: Vec<u64> = version.split('.').filter_map(|s| s.parse().ok()).collect();
    match parts.iter().position(|&p| p != 0) {
        Some(idx) => (idx, parts[idx]),
        None => (0, 0),
    }
}

fn is_major_bump(current: &str, latest: &str) -> bool {
    let (ci, cv) = major_component(current);
    let (li, lv) = major_component(latest);
    if ci != li {
        return true;
    }
    lv > cv
}

// --- rust-minor-audit ---

pub fn minor_audit() -> Result<(), String> {
    let input = read_stdin().trim().to_string();
    if input.is_empty() {
        print_empty_minor();
        return Ok(());
    }

    let update_re =
        Regex::new(r"^\s+(?:Updating|Locking)\s+(\S+)\s+v(\S+)\s+->\s+v(\S+)").unwrap();

    let mut updates: Vec<(String, String, String)> = Vec::new();
    for line in input.lines() {
        if let Some(caps) = update_re.captures(line) {
            updates.push((caps[1].to_string(), caps[2].to_string(), caps[3].to_string()));
        }
    }

    if updates.is_empty() {
        print_empty_minor();
        return Ok(());
    }

    let mut minor: Vec<String> = Vec::new();
    let mut patch: Vec<String> = Vec::new();

    for (name, from, to) in &updates {
        let line = format!("{name}: {from} -> {to}");
        if is_minor_bump(from, to) {
            minor.push(line);
        } else {
            patch.push(line);
        }
    }

    println!("--- minor updates ---");
    println!(
        "{}",
        if minor.is_empty() { "none".to_string() } else { minor.join("\n") }
    );
    println!();
    println!("--- patch updates ---");
    println!(
        "{}",
        if patch.is_empty() { "none".to_string() } else { patch.join("\n") }
    );
    println!();
    println!("--- summary ---");
    println!("minor: {}, patch: {}", minor.len(), patch.len());

    Ok(())
}

fn is_minor_bump(from: &str, to: &str) -> bool {
    let fp: Vec<u64> = from.split('.').filter_map(|s| s.parse().ok()).collect();
    let tp: Vec<u64> = to.split('.').filter_map(|s| s.parse().ok()).collect();
    let major_idx = match fp.iter().position(|&p| p != 0) {
        Some(i) => i,
        None => return tp.iter().any(|&p| p != 0),
    };
    let next = major_idx + 1;
    next < fp.len() && next < tp.len() && tp[next] > fp[next]
}

fn print_empty_minor() {
    println!("--- minor updates ---");
    println!("none");
    println!();
    println!("--- patch updates ---");
    println!("none");
    println!();
    println!("--- summary ---");
    println!("minor: 0, patch: 0");
}

fn read_stdin() -> String {
    let mut buf = String::new();
    std::io::stdin().read_to_string(&mut buf).unwrap_or(0);
    buf
}

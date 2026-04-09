use std::fs;

use serde::Deserialize;

pub fn channel_audit() -> Result<(), String> {
    let flake = fs::read_to_string("flake.nix").map_err(|e| format!("flake.nix: {e}"))?;

    let re = regex::Regex::new(r"nixpkgs/nixpkgs-(\d+)\.(\d+)-darwin").unwrap();
    let caps = match re.captures(&flake) {
        Some(c) => c,
        None => {
            println!("channel: unknown");
            return Ok(());
        }
    };

    let yy: u32 = caps[1].parse().unwrap();
    let mm: u32 = caps[2].parse().unwrap();
    println!("current channel: nixpkgs-{yy}.{mm:02}-darwin");

    // Derive current year/month from Unix timestamp via days_to_ymd
    let now_secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    let (current_year_full, current_month, _) = days_to_ymd(now_secs / 86400);
    let current_year_short = (current_year_full % 100) as u32;

    // Build list of stable channels (May=05, November=11) from 24.05 up to today
    let mut latest_label: Option<(u32, u32)> = None;
    for y in 24..=current_year_short {
        for &m in &[5u32, 11] {
            if y < current_year_short || (y == current_year_short && m <= current_month) {
                latest_label = Some((y, m));
            }
        }
    }

    match latest_label {
        Some((ly, lm)) => {
            let current_num = yy * 100 + mm;
            let latest_num = ly * 100 + lm;
            if latest_num > current_num {
                println!(
                    "latest channel:  nixpkgs-{ly}.{lm:02}-darwin  <- UPGRADE AVAILABLE"
                );
            } else {
                println!(
                    "latest channel:  nixpkgs-{ly}.{lm:02}-darwin  (up to date)"
                );
            }
        }
        None => {
            println!("latest channel: unknown");
        }
    }

    Ok(())
}

pub fn flakelock_audit() -> Result<(), String> {
    let raw = fs::read_to_string("flake.lock").map_err(|e| format!("flake.lock: {e}"))?;
    let lock: FlakeLock =
        serde_json::from_str(&raw).map_err(|e| format!("unexpected flake.lock format: {e}"))?;

    for (name, node) in &lock.nodes {
        if let Some(locked) = &node.locked {
            let date = match locked.last_modified {
                Some(ts) => {
                    let (y, m, d) = days_to_ymd(ts / 86400);
                    format!("{y:04}-{m:02}-{d:02}")
                }
                None => "?".to_string(),
            };
            let rev = locked
                .rev
                .as_deref()
                .map(|r| &r[..12.min(r.len())])
                .unwrap_or("?");
            println!("{name}: pinned {date} (rev {rev})");
        }
    }

    Ok(())
}

#[derive(Deserialize)]
struct FlakeLock {
    #[serde(default)]
    nodes: std::collections::BTreeMap<String, FlakeNode>,
}

#[derive(Deserialize)]
struct FlakeNode {
    locked: Option<FlakeLocked>,
}

#[derive(Deserialize)]
struct FlakeLocked {
    #[serde(rename = "lastModified")]
    last_modified: Option<i64>,
    rev: Option<String>,
}

// Algorithm from http://howardhinnant.github.io/date_algorithms.html
fn days_to_ymd(days: i64) -> (i64, u32, u32) {
    let z = days + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u32;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    (y, m, d)
}

use std::fs;

use serde_json::Value;

pub fn versions_report() -> Result<(), String> {
    let files = ["app/elm.json", "package/elm.json", "review/elm.json"];

    for f in &files {
        let raw = fs::read_to_string(f).map_err(|e| format!("{f}: {e}"))?;
        let elm_json: Value =
            serde_json::from_str(&raw).map_err(|e| format!("{f}: {e}"))?;

        let type_str = elm_json["type"].as_str().unwrap_or("unknown");
        println!("--- {f} ({type_str}) ---");

        match type_str {
            "application" => {
                let deps = &elm_json["dependencies"];
                let test_deps = &elm_json["test-dependencies"];

                println!("direct:");
                print_entries(&deps["direct"]);
                println!("indirect:");
                print_entries(&deps["indirect"]);

                let has_test = !is_empty_obj(&test_deps["direct"])
                    || !is_empty_obj(&test_deps["indirect"]);
                if has_test {
                    println!("test-direct:");
                    print_entries(&test_deps["direct"]);
                    println!("test-indirect:");
                    print_entries(&test_deps["indirect"]);
                }
            }
            "package" => {
                println!("dependencies:");
                print_entries(&elm_json["dependencies"]);

                let test_deps = &elm_json["test-dependencies"];
                if !is_empty_obj(test_deps) {
                    println!("test-dependencies:");
                    print_entries(test_deps);
                }
            }
            _ => {}
        }

        println!();
    }

    Ok(())
}

fn print_entries(obj: &Value) {
    if let Some(map) = obj.as_object() {
        let mut entries: Vec<_> = map.iter().collect();
        entries.sort_by(|(a, _), (b, _)| a.cmp(b));
        for (name, version) in entries {
            if let Some(v) = version.as_str() {
                println!("  {name}: {v}");
            }
        }
    }
}

fn is_empty_obj(v: &Value) -> bool {
    v.as_object().map_or(true, |m| m.is_empty())
}

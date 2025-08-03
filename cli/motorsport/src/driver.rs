use serde::{Deserialize, Serialize};

/// ドライバー情報
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct Driver {
    pub name: String,
}

impl Driver {
    /// 新しいドライバーを作成
    pub fn new(name: String, _is_current: bool) -> Self {
        Driver { name }
    }
}

#[cfg(test)]
mod tests {
    use super::Driver;

    #[test]
    fn test_driver_json_serialization() {
        let driver = Driver::new("Kamui KOBAYASHI".to_string(), true);
        let json = serde_json::to_string(&driver).unwrap();

        assert!(json.contains("\"name\":\"Kamui KOBAYASHI\""));

        println!("Driver JSON: {}", json);
    }
}

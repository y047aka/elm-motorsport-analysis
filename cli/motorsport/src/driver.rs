use serde::Serialize;

/// ドライバー情報
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Driver {
    pub name: String,
}

impl Driver {
    /// 新しいドライバーを作成
    pub fn new(name: String) -> Self {
        Driver { name }
    }
}

#[cfg(test)]
mod tests {
    use super::Driver;

    #[test]
    fn test_driver_json_serialization() {
        let driver = Driver::new("Kamui KOBAYASHI".to_string());
        let json = serde_json::to_string(&driver).unwrap();

        assert!(json.contains("\"name\":\"Kamui KOBAYASHI\""));

        println!("Driver JSON: {}", json);
    }
}

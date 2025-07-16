use serde::{Deserialize, Serialize};

/// ドライバー情報
#[derive(Debug, Clone, PartialEq, Deserialize, Serialize)]
pub struct Driver {
    pub name: String,
    pub is_current_driver: bool,
}

impl Driver {
    /// 新しいドライバーを作成
    pub fn new(name: String, is_current: bool) -> Self {
        Driver {
            name,
            is_current_driver: is_current,
        }
    }
}

/// ドライバーリストから現在のドライバーを検索
pub fn find_current_driver(drivers: &[Driver]) -> Option<&Driver> {
    drivers.iter().find(|d| d.is_current_driver)
}

#[cfg(test)]
mod tests {
    use super::{Driver, find_current_driver};

    #[test]
    fn find_current_driver_() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Kamui KOBAYASHI".to_string(), true),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_some());
        assert_eq!(current.unwrap().name, "Kamui KOBAYASHI");
    }

    #[test]
    fn find_current_driver_none() {
        let drivers = vec![
            Driver::new("Will STEVENS".to_string(), false),
            Driver::new("Mike CONWAY".to_string(), false),
        ];

        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }

    #[test]
    fn find_current_driver_empty() {
        let drivers: Vec<Driver> = vec![];
        let current = find_current_driver(&drivers);
        assert!(current.is_none());
    }
}

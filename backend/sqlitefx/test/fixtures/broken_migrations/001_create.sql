-- migrate のテスト用。本体の test/Sqlite/TestMigrate.flix が当てる
CREATE TABLE sqlitefx_mig_test (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO sqlitefx_mig_test (name) VALUES ('first');

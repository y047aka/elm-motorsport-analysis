-- sqlitefx:no-transaction
CREATE INDEX IF NOT EXISTS sqlitefx_mig_test_name_idx ON sqlitefx_mig_test (name);
VACUUM;

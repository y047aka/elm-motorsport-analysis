# Project instructions

- 利用者への応答は日本語で行う。
- コミットメッセージに `Co-Authored-By:` トレーラーを付けない。
- bash コマンドの許可/確認/拒否は `.pi/extensions/permission-gate.ts` が enforcing する。
  それ以外の bash は確認なく実行してよい。秘密ファイル（`.env*`, `*.key`, `*.pem`）は
  `read` / `edit` / `write` ツールがゲートで遮断されるが、**bash は遮断されない**:
  `cat .env` のような読み書きをコマンドでしてはならない。

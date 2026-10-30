# Project instructions (ported from .claude/settings.json)

- 利用者への応答は日本語で行う（`language: "japanese"` の移植）。
- コミットメッセージに `Co-Authored-By:` トレーラーを付けない（`includeCoAuthoredBy: false` の移植）。
- bash コマンドの許可/確認/拒否は `.pi/extensions/permission-gate.ts` が enforcing する。
  それ以外の bash は確認なく実行してよい。秘密ファイル（`.env*`, `*.key`, `*.pem`）の
  読み書きは拡張が遮断する。

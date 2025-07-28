# Requirements Document

## Project Overview
Lap型のデータ構造を見直し、Car型で採用されているmetaDataプロパティパターンに整合させ、統一性を保つ。将来的なCLI出力形式の統一を見据えつつ、現在の既存JSONデータとの互換性をElmデコーダーで維持する。

## Project Description (User Input)
Lap型のデータ構造を見直す。Car型ではメタデータをmetaDataプロパティに集約しており、この方法に倣うことは選択肢の1つになる。将来的にはCLIが出力するデータ形式も統一が見込めるが、今回は既存のJSONデータをそのまま使い、Elmのデコーダーで差異を吸収する。

## Requirements
<!-- Detailed user stories will be generated in /spec-requirements phase -->

---
**STATUS**: Ready for requirements generation
**NEXT STEP**: Run `/kiro:spec-requirements lap-metadata-restructure` to generate detailed requirements
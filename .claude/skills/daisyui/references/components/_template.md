<!--
TEMPLATE GUIDE:
このテンプレートはdaisyUI skillのための高精度なリファレンスを作成するためのものです。
Claude Codeが既知の一般的な情報は完全に省略し、daisyUI固有の情報のみに特化します。

【重要原則】
- カラーバリアント(primary/secondary等)は記載しない → Claude Codeが既知
- サイズバリアント(xs/sm/md/lg/xl)は標準パターンなら記載しない → 特殊なサイズのみ記載
- レスポンシブ対応(`sm:btn-sm`等)は記載しない → Tailwindの標準機能
- 単純なHTML属性(disabled等)は記載しない → 一般的な知識

【記載すべき情報】
1. daisyUI固有のクラス名(modal-box, modal-backdrop等)
2. 必須のHTML構造(dialog要素、form method="dialog"等)
3. コンポーネント固有の制約(modal-action内のformタグ等)
4. ブラウザAPIとの連携(element.showModal()等)
5. daisyUI固有の修飾子(btn-wide, btn-square等)

使用方法:
1. {ComponentName}, {prefix}等のプレースホルダーを置き換える
2. 公式ドキュメントURL({official_url})を記載
3. Class Referenceは公式情報で不明確な点がある場合のみ追加説明を記載
4. Essential Examplesに必要なセクションのみを残す
5. 不要なセクションは全て削除
-->

# {ComponentName}

{1行の簡潔な説明文 - daisyUI固有の特徴を記載}

## Class Reference

公式ドキュメント: {official_url}

<!--
【基本方針】
公式ドキュメントのClass name tableを参照すること。
以下の場合のみ、補足説明を記載:

✅ 記載すべき補足:
- 公式のDescriptionが不明確なクラスの詳細説明
- 必須の組み合わせ(例: "modal-box は modal 内でのみ使用")
- HTML構造の制約(例: "modal-backdrop は form method='dialog' と併用")
- ブラウザAPIとの連携(例: "modal-open は dialog.showModal() で自動付与")

❌ 記載不要:
- 公式ドキュメントに明記されているクラス名の単純な列挙
- Type分類(公式のtableに記載済み)
- 一般的なカラー/サイズバリアント

補足が不要な場合は、このセクションを「公式ドキュメント: {url}」のみにすること
-->

<!-- 以下は公式情報が不明確な場合のみ記載 -->
| Class name | 補足 |
|------------|------|
| `{specific-class}` | {公式ドキュメントで不明確な点の詳細説明} |


## Essential Examples

### Basic usage

```html
<!-- コピペ可能な最小実装 - 必須クラスとHTML構造のみ -->
```

### With structure

```html
<!-- 複雑なHTML構造が必要な場合のみ記載
     例: modalのdialog要素、dropdownの階層構造、form method="dialog"等

     単純な構造(<button class="btn">等)なら削除 -->
```

### Interactive

```html
<!-- ブラウザAPIとの連携が必要な場合のみ記載
     例: dialog.showModal()、checkbox:checked擬似クラス等

     APIとの連携がなければ削除 -->
```

<!--
セクション削除基準:
- "Basic usage": 必須(削除不可)
- "With structure": 単純な構造なら削除
- "Interactive": ブラウザAPIとの連携がなければ削除

廃止されたセクション:
- "Colors and styles" → カラー/スタイルはClaude Codeが既知
- "States" → HTML標準のため不要
- "Responsive" → Tailwindの標準機能のため不要
- "Icon buttons" → 一般的なHTMLパターンのため不要
-->

## Notes

<!--
記載基準:
✅ 必須: daisyUI固有の制約事項(modal-action内のformタグ、dialog要素の使用等)
✅ 推奨: daisyUI固有のアクセシビリティパターン
✅ 非推奨: v4.xの破壊的変更、古いクラス名
❌ 不要: ブラウザの一般的な挙動、HTML標準の知識

注意点がない場合はNotesセクション全体を削除すること
-->

- **必須**: {daisyUI固有の制約事項}
- **推奨**: {daisyUI固有のアクセシビリティパターン}
- **非推奨**: {v4.xで変更された情報}

pub mod Sqlitefx.Row {

    use Sqlitefx.SqlValue

    ///
    /// 列名 → 添字。同じ結果セットの行はこれを共有する（行ごとに Map を持たない）。
    ///
    pub type alias ColumnIndex = Map[String, Int32]

    ///
    /// 結果セットの 1 行。接続からは切り離された不変の値。
    ///
    /// - `columns`: 列名 → 添字。結果セットの全行で共有する
    /// - `names`: 列名を結果セットの順に。`cells` と同じ長さ
    /// - `cells`: 列の値。添字は `columns` と対応する
    ///
    /// WhyNot: `columns` だけで列名を持たないのは、結合で両側の同じ名前の列を並べた結果（`a.id, b.id`）では
    /// Map が片方の名前を落とし、列名の数がセルの数より少なくなるから。`get` は後ろの方を返す。
    ///
    pub type alias Row = { columns = ColumnIndex, names = Vector[String], cells = Vector[SqlValue.SqlValue] }

    ///
    /// 発行した文。計測ハンドラが記録し、テストで比較する。
    ///
    /// - `sql`: プレースホルダを含む SQL 文
    /// - `params`: プレースホルダに渡した値。順序は `$1`, `$2`, ... と対応する
    ///
    pub type alias Statement = { sql = String, params = List[SqlValue.SqlValue] }

    ///
    /// 列名のリストから列名 → 添字の Map を組む。
    ///
    pub def makeColumnIndex(names: List[String]): ColumnIndex =
        names
            |> List.zipWithIndex
            |> List.map(match (index, name) -> (name, index))
            |> List.toMap

    ///
    /// 列名のリストと各行のセルから結果セットを組む。テストハンドラと JDBC ハンドラの両方が使う。
    ///
    pub def makeRows(names: List[String], cells: List[List[SqlValue.SqlValue]]): List[Row] =
        let columns = makeColumnIndex(names);
        let ordered = List.toVector(names);
        cells |> List.map(rowCells -> { columns = columns, names = ordered, cells = List.toVector(rowCells) })

    ///
    /// 列名で値を取り出す。列が無ければ None。
    ///
    pub def get(name: String, row: Row): Option[SqlValue.SqlValue] =
        Map.get(name, row#columns) |> Option.flatMap(index -> Vector.nth(index, row#cells))

    ///
    /// 1 列の値を差し替えた行を返す。列が無ければ末尾に足す。
    /// テストで「この列だけ壊れた行」を作るのに使う。
    ///
    pub def set(name: String, value: SqlValue.SqlValue, row: Row): Row =
        match Map.get(name, row#columns) {
            case Some(index) if index >= Vector.length(row#cells) => bug!("Row.set: column '${name}' has index ${index} but the row has ${Vector.length(row#cells)} cells")
            case Some(index) => { columns = row#columns, names = row#names, cells = Vector.update(index, value, row#cells) }
            case None =>
                let index = Vector.length(row#cells);
                { columns = Map.insert(name, index, row#columns), names = Vector.append(row#names, Vector#{name}), cells = Vector.append(row#cells, Vector#{value}) }
        }

    ///
    /// 列名を結果セットの順で返す。同じ名前が 2 回あれば 2 回並ぶ。
    ///
    pub def columnNames(row: Row): List[String] =
        Vector.toList(row#names)

    ///
    /// 列のない行。
    ///
    pub def empty(): Row = { columns = Map#{}, names = Vector#{}, cells = Vector#{} }

}

// Gen: `gen` の引数の読み方。

/// `--scope` の値: `列` は検査だけ、`列:effect` は注入。effect は名前空間付きでもよく、`:` の後ろが空なら検査だけ。
@Test
def testScopeSpec(): Unit \ Assert =
    Assert.assertEq(
        expected = List#{("project_id", None), ("project_id", Some("Tenant")), ("org_id", Some("Cms.Org")), ("project_id", None)},
        List.map(spec -> { let scope = scopeSpec(spec); (scope#column, scope#effect) }, List#{"project_id", "project_id:Tenant", "org_id:Cms.Org", "project_id:"}))

/// `gen --statements <path>` は文の一覧を書く先。どの位置に置いてもよい。
@Test
def testGenArgsStatements(): Unit \ Assert =
    let parsed = genArgs(List#{"--statements", "out/statements.json", "--scope", "project_id:Tenant", "m", "q", "o"})
        |> Option.map(match (check, dirs) -> (check, dirs#statements, dirs#migrations, dirs#queries, dirs#out));
    Assert.assertEq(expected = Some((false, Some("out/statements.json"), "m", "q", "o")), parsed)

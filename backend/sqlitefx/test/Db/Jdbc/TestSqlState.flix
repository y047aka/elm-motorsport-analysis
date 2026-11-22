use Sqlitefx.SqlState

use Sqlitefx.DbError.DbErrorKind
use Sqlitefx.DbError.TransientKind

// SqlState: SQLite の result code とメッセージ → DbErrorKind の翻訳表。

/// 拡張 code があれば code で、違反した物（表.列、名前付き CHECK は制約名）付きの違反に。
///
///   2067 UNIQUE      → UniqueViolation("users.email")
///   1555 PRIMARYKEY  → UniqueViolation("users.id")
///   1299 NOTNULL     → NotNullViolation("users.name")
///   275  CHECK       → CheckViolation("score_positive")
///   787  FOREIGNKEY  → ForeignKeyViolation(メッセージ全体。SQLite は何も名指さない)
@Test
def testClassifyExtendedConstraint(): Unit \ Assert =
    Assert.assertEq(
        expected = List#{
            DbErrorKind.UniqueViolation("users.email"),
            DbErrorKind.UniqueViolation("users.id"),
            DbErrorKind.NotNullViolation("users.name"),
            DbErrorKind.CheckViolation("score_positive"),
            DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed")
        },
        List#{
            SqlState.classify({ code = 2067, message = "UNIQUE constraint failed: users.email" }),
            SqlState.classify({ code = 1555, message = "UNIQUE constraint failed: users.id" }),
            SqlState.classify({ code = 1299, message = "NOT NULL constraint failed: users.name" }),
            SqlState.classify({ code = 275, message = "CHECK constraint failed: score_positive" }),
            SqlState.classify({ code = 787, message = "FOREIGN KEY constraint failed" })
        })

/// 基本 code（19）だけなら文言で分ける。sqlite-jdbc が自分の文で包んだ物も、閉じる `)` の前まで。
@Test
def testClassifyPrimaryConstraint(): Unit \ Assert =
    Assert.assertEq(
        expected = List#{
            DbErrorKind.UniqueViolation("t.k"),
            DbErrorKind.UniqueViolation("users.email"),
            DbErrorKind.NotNullViolation("users.name"),
            DbErrorKind.CheckViolation("score_positive"),
            DbErrorKind.ForeignKeyViolation("FOREIGN KEY constraint failed"),
            DbErrorKind.Other("constraint failed")
        },
        List#{
            SqlState.classify({ code = 19, message = "[SQLITE_CONSTRAINT_UNIQUE] A UNIQUE constraint failed (UNIQUE constraint failed: t.k)" }),
            SqlState.classify({ code = 19, message = "UNIQUE constraint failed: users.email" }),
            SqlState.classify({ code = 19, message = "NOT NULL constraint failed: users.name" }),
            SqlState.classify({ code = 19, message = "CHECK constraint failed: score_positive" }),
            SqlState.classify({ code = 19, message = "FOREIGN KEY constraint failed" }),
            SqlState.classify({ code = 19, message = "constraint failed" })
        })

/// ロックを待って取れなかった物と、ファイルを開けない物は Transient。拡張 code は下位 1 バイトで読む。
///
///   5   BUSY          → timeout 0
///   6   LOCKED        → timeout 0
///   517 BUSY_SNAPSHOT → timeout 0
///   14  CANTOPEN      → connectionLost
@Test
def testClassifyTransient(): Unit \ Assert =
    Assert.assertEq(
        expected = List#{
            DbErrorKind.Transient(TransientKind.Timeout(0)),
            DbErrorKind.Transient(TransientKind.Timeout(0)),
            DbErrorKind.Transient(TransientKind.Timeout(0)),
            DbErrorKind.Transient(TransientKind.ConnectionLost("unable to open database file"))
        },
        List#{
            SqlState.classify({ code = 5, message = "database is locked" }),
            SqlState.classify({ code = 6, message = "database table is locked" }),
            SqlState.classify({ code = 517, message = "database is locked" }),
            SqlState.classify({ code = 14, message = "unable to open database file" })
        })

/// 無い表・列・関数は SchemaMismatch。構文の誤りは同じ SQLITE_ERROR でも Other。
@Test
def testClassifySchemaMismatch(): Unit \ Assert =
    let wrapped = "[SQLITE_ERROR] SQL error or missing database (no such column: led.hled)";
    Assert.assertEq(
        expected = List#{
            DbErrorKind.SchemaMismatch("no such table: users"),
            DbErrorKind.SchemaMismatch(wrapped),
            DbErrorKind.SchemaMismatch("no such function: jsonb_build_object"),
            DbErrorKind.SchemaMismatch("table users has no column named nickname"),
            DbErrorKind.Other("near \"FORM\": syntax error")
        },
        List#{
            SqlState.classify({ code = 1, message = "no such table: users" }),
            SqlState.classify({ code = 1, message = wrapped }),
            SqlState.classify({ code = 1, message = "no such function: jsonb_build_object" }),
            SqlState.classify({ code = 1, message = "table users has no column named nickname" }),
            SqlState.classify({ code = 1, message = "near \"FORM\": syntax error" })
        })

/// それ以外は Other で、メッセージをそのまま持つ。
@Test
def testClassifyOther(): Unit \ Assert =
    Assert.assertEq(
        expected = DbErrorKind.Other("database or disk is full"),
        SqlState.classify({ code = 13, message = "database or disk is full" }))

/// `failed:` の後ろを、閉じる `)` の前まで。複数列の UNIQUE は列が `, ` で並ぶ。
/// `failed:` が無ければ SQLite 自身の文（sqlite-jdbc が包んでいれば括弧の中）。
@Test
def testConstraintName(): Unit \ Assert =
    Assert.assertEq(
        expected = List#{"users.email", "t.a, t.b", "t.k", "FOREIGN KEY constraint failed", "FOREIGN KEY constraint failed"},
        List#{
            SqlState.constraintName("UNIQUE constraint failed: users.email"),
            SqlState.constraintName("UNIQUE constraint failed: t.a, t.b"),
            SqlState.constraintName("[SQLITE_CONSTRAINT_UNIQUE] A UNIQUE constraint failed (UNIQUE constraint failed: t.k)"),
            SqlState.constraintName("FOREIGN KEY constraint failed"),
            SqlState.constraintName("[SQLITE_CONSTRAINT_FOREIGNKEY] A foreign key constraint failed (FOREIGN KEY constraint failed)")
        })

pub mod Sqlitefx.Savepoint {

    ///
    /// 発行する文。名前は `isValidName` を通った物だけが入る。
    ///
    pub enum Command with Eq, Order, ToString {
        /// `SAVEPOINT name`
        case Savepoint(String)
        /// `RELEASE SAVEPOINT name`
        case Release(String)
        /// `ROLLBACK TO SAVEPOINT name`
        case RollbackTo(String)
    }

    ///
    /// 名前が `^[a-z_][a-z0-9_]*$` で 63 文字までか。SQL の文面に入る唯一の値なので、これ以外は通さない。
    ///
    /// WhyNot: SQLite は長い名前も切り詰めずに受けるのに 63 文字で止めるのは、sqlfx が通す名前と同じ物だけを通し、片方で書いた `withSavepoint` がもう片方で `Err` にならないようにするため。
    ///
    pub def isValidName(name: String): Bool =
        match String.toList(name) {
            case head :: rest => isLeading(head) and List.forAll(isFollowing, rest) and String.length(name) <= maxNameLength()
            case Nil          => false
        }

    ///
    /// 命令を SQL にする。
    ///
    pub def toSql(command: Command): String = match command {
        case Command.Savepoint(name)  => "SAVEPOINT ${name}"
        case Command.Release(name)    => "RELEASE SAVEPOINT ${name}"
        case Command.RollbackTo(name) => "ROLLBACK TO SAVEPOINT ${name}"
    }

    ///
    /// 名前の決まりを人が読む 1 行にする。断りの文言に使う。
    ///
    pub def nameRule(): String = "expected ^[a-z_][a-z0-9_]*$, at most ${maxNameLength()} chars"

    /// sqlfx の上限（PG の識別子の上限、NAMEDATALEN - 1）。
    def maxNameLength(): Int32 = 63

    /// 先頭に置ける文字。ASCII の小文字と `_` だけ（`Char.isLetter` は ASCII 以外も通す）。
    def isLeading(ch: Char): Bool = (ch >= 'a' and ch <= 'z') or ch == '_'

    /// 2 文字目以降に置ける文字。
    def isFollowing(ch: Char): Bool = isLeading(ch) or (ch >= '0' and ch <= '9')

}

/// The savepoints a reading marks, as the statements they are.
///
/// A name is the one value that reaches the statement's text rather than a
/// placeholder, so it is the one value with a rule of its own.
pub mod Db.Savepoint {

    /// The three statements a savepoint is.
    pub enum Command with Eq, ToString {
        case Mark(String)
        case Release(String)
        case RollbackTo(String)
    }

    /// The name `^[a-z_][a-z0-9_]*$`, which is what a savepoint may be called
    /// without the statement meaning something else.
    pub def isValidName(name: String): Bool =
        match String.toList(name) {
            case head :: rest => isLeading(head) and List.forAll(isFollowing, rest)
            case Nil          => false
        }

    /// The statement, in the spelling SQLite takes.
    pub def toSql(command: Command): String = match command {
        case Command.Mark(name)      => "SAVEPOINT ${name}"
        case Command.Release(name)   => "RELEASE SAVEPOINT ${name}"
        case Command.RollbackTo(name) => "ROLLBACK TO SAVEPOINT ${name}"
    }

    /// The rule, in the one line a refusal can say.
    pub def nameRule(): String = "expected ^[a-z_][a-z0-9_]*$"

    /// ASCII lower case and `_`, which is what a name may start with.
    def isLeading(ch: Char): Bool = (ch >= 'a' and ch <= 'z') or ch == '_'

    def isFollowing(ch: Char): Bool = isLeading(ch) or (ch >= '0' and ch <= '9')

}

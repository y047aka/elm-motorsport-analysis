mod Log {

    import java.lang.System

    pub def info(msg: String): Unit \ IO =
        println(msg)

    pub def error(msg: String): Unit \ IO =
        System.err.println(msg)

}

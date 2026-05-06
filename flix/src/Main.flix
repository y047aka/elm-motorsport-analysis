use Sys.Env
use Sys.Console
use Sys.Exit
use Cli.Args
use Cli.FileTask
use Cli.Stages

def main(): Unit \ {Env, IO, Exit, Console} =
    let code = match Args.parse(Env.getArgs()) {
        case Err(e) =>
            Console.eprintln("Error: ${e}");
            Console.eprintln(Args.usageInfo());
            1
        case Ok(parsed) =>
            match FileTask.resolve(parsed) {
                case Err(e) =>
                    Console.eprintln("Error: ${e}");
                    1
                case Ok(tasks) =>
                    Stages.runAll(tasks)
            }
    };
    Exit.exit(code)

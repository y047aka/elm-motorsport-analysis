use Sys.Env
use Cli.Args
use Cli.Exit
use Cli.FileTask
use Cli.Log
use Cli.Stages

def main(): Unit \ {Env, IO} =
    let code = match Args.parse(Env.getArgs()) {
        case Err(e) =>
            Log.error("Error: ${e}");
            Log.error("Usage: flix-run <input.csv|dir> [--output <output.json>]");
            1
        case Ok(parsed) =>
            match FileTask.resolve(parsed) {
                case Err(e) =>
                    Log.error("Error: ${e}");
                    1
                case Ok(tasks) =>
                    Stages.runAll(tasks)
            }
    };
    Exit.exit(code)

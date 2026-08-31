module Getopt = Util_getopt

type args_error =
  | Missing_root
  | Unexpected_arguments of string list
  | Parse_errors of string list

let args_error_to_string = function
  | Missing_root -> "Missing_root"
  | Unexpected_arguments extras -> Printf.sprintf "Unexpected_arguments(%s)" (String.concat ", " extras)
  | Parse_errors errors -> Printf.sprintf "Parse_errors(%s)" (String.concat ", " errors)

(** Where the season directories are, and nothing else. What to convert comes
    from [Motorsport_calendar], so there is no per-file input and nothing to
    redirect a single file's output to. *)
type parsed_args = { root : string }

let option_descrs : unit Getopt.option_descr list = []

let get_opt_result args =
  match Getopt.get_opt Getopt.Permute option_descrs args with
  | Error errors -> Error (Parse_errors errors)
  | Ok (options, non_options) -> Ok (options, non_options)

let extract_root non_options =
  match non_options with
  | [ root ] -> Ok root
  | [] -> Error Missing_root
  | extras -> Error (Unexpected_arguments extras)

let parse args =
  Result.bind (get_opt_result args) (fun (_, non_options) ->
      Result.map (fun root -> { root }) (extract_root non_options))

let usage () = Getopt.usage_info "Usage: cli-run <dir holding the season directories>" option_descrs

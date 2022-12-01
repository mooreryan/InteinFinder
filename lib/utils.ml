open! Core
module Sh = Shexp_process

(* Return list of entries in [path] as [path/entry] *)
let ls_dir path =
  List.fold
    ~init:[]
    ~f:(fun acc entry -> Filename.concat path entry :: acc)
    (Sys_unix.ls_dir path)

(* May raise some unix errors? *)
let rec rm_rf name =
  match Core_unix.lstat name with
  | {st_kind= S_DIR; _} ->
      List.iter (ls_dir name) ~f:rm_rf ;
      Core_unix.rmdir name
  | _ ->
      Core_unix.unlink name
  | exception Core_unix.Unix_error (ENOENT, _, _) ->
      ()

let with_temp_dir ?(perm = 0o700) ?in_dir ?(prefix = "tmp") ?(suffix = "tmp") f
    =
  let dir = Filename_unix.temp_dir ~perm ?in_dir prefix suffix in
  Exn.protectx
    ~f
    ~finally:(fun name -> if Sys_unix.file_exists_exn name then rm_rf name)
    dir

let with_temp_file ?(perm = 0o600) ?in_dir ?(prefix = "tmp") ?(suffix = "tmp") f
    =
  let file = Filename_unix.temp_file ~perm ?in_dir prefix suffix in
  Exn.protectx
    ~f
    ~finally:(fun name ->
      if Sys_unix.file_exists_exn name then Sys_unix.remove name )
    file

let remove_file_if_empty file_name =
  let ({st_size; _} : Core_unix.stats) = Core_unix.stat file_name in
  if Int64.(st_size = of_int 0) then Sys_unix.remove file_name

let remove_if_exists file_name =
  if Sys_unix.file_exists_exn file_name then Sys_unix.remove file_name

let touch ?(perm = 0o644) ?(fail_if_exists = true) name =
  Out_channel.close @@ Out_channel.create ~perm ~fail_if_exists name ;
  name

let redirect_out_err out proc = Sh.outputs_to ~append:() out proc

let eval_sh log proc = Sh.eval @@ redirect_out_err log proc

let now_coarse () =
  let zone = Lazy.force Time_unix.Zone.local in
  let now = Time.now () in
  Time_unix.format now "%Y-%m-%d %H:%M:%S" ~zone

let now () =
  let zone = Lazy.force Time_unix.Zone.local in
  Time.to_filename_string ~zone @@ Time.now ()

let log_name ~log_base ~desc =
  let now = now () in
  [%string "%{log_base}.%{now}.%{desc}.txt"]

let string_of_int_option = function None -> "None" | Some i -> Int.to_string i

let assert_all_files_exist : string list -> unit =
 fun files ->
  List.map files ~f:(fun file ->
      if Sys_unix.file_exists_exn file then Or_error.return file
      else Or_error.errorf "Expected '%s' to exist, but it does not" file )
  |> Or_error.all |> Or_error.ok_exn |> ignore

let iter_if_ok (v : 'a Async.Deferred.Or_error.t) ~f =
  match%bind.Async.Deferred v with
  | Ok x ->
      f x
  | Error _ ->
      Async.Deferred.return ()

(** Run an async function that may raise with [Async.try_with]. If it passes or
    fails return [unit Async.Deferred.t]. *)
let iter_and_swallow_error f =
  match%map.Async.Deferred Async.try_with f with Ok () | Error _ -> ()

let float_to_string_hum x = Float.to_string_hum ~strip_zero:true ~decimals:6 x

(** Raises failure. Like [failwithf] but gives standardized message for things
    that should be impossible. *)
let impossible' fmt =
  ksprintf
    (fun s () ->
      let msg = [%string "internal error (impossible state): %{s}"] in
      failwith msg )
    fmt
  [@@coverage off]

(** Raises failure. Like [failwith] but gives standardized message for things
    that should be impossible. *)
let impossible msg =
  let msg = [%string "internal error (impossible state): %{msg}"] in
  failwith msg
  [@@coverage off]

open! Core

module Log_reporter = struct
  (* Lightly modified from [Logs_fmt] in the [Logs] package. *)

  (*---------------------------------------------------------------------------
    Copyright (c) 2015 The logs programmers. All rights reserved. Distributed
    under the ISC license, see terms at the end of the file.
    ---------------------------------------------------------------------------*)

  let app_style = `Cyan

  let err_style = `Red

  let warn_style = `Yellow

  let info_style = `Blue

  let debug_style = `Green

  [@@@coverage off]

  (* Coverage is off here as it is taken exactly from Logs. *)
  let pp_header ~pp_h ppf (l, h) =
    match l with
    | Logs.App -> (
      match h with
      | None ->
          ()
      | Some h ->
          Fmt.pf ppf "[%a] " Fmt.(styled app_style string) h )
    | Logs.Error ->
        pp_h ppf err_style (match h with None -> "ERROR" | Some h -> h)
    | Logs.Warning ->
        pp_h ppf warn_style (match h with None -> "WARNING" | Some h -> h)
    | Logs.Info ->
        pp_h ppf info_style (match h with None -> "INFO" | Some h -> h)
    | Logs.Debug ->
        pp_h ppf debug_style (match h with None -> "DEBUG" | Some h -> h)

  [@@@coverage on]

  let pp_exec_header =
    let pp_h ppf style h =
      Fmt.pf ppf "%a [%s] " Fmt.(styled style string) h (Utils.now_coarse ())
    in
    pp_header ~pp_h

  let reporter ?(pp_header = pp_exec_header) ?app ?dst () =
    Logs.format_reporter ~pp_header ?app ?dst ()

  let pp_header =
    let pp_h ppf style h = Fmt.pf ppf "[%a]" Fmt.(styled style string) h in
    pp_header ~pp_h
end

let set_log_level log_level =
  let log_level =
    match Logs.level_of_string log_level with
    | Ok x ->
        x
    | Error (`Msg s) ->
        failwith s
  in
  Logs.set_level log_level

let set_up_logging log_level =
  Logs.set_reporter @@ Log_reporter.reporter () ;
  Fmt_tty.setup_std_outputs () ;
  set_log_level log_level

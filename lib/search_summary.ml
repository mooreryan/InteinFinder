open! Core

[@@@coverage off]

type t =
  { query: string
  ; total_hits: int
  ; pident: float
  ; pident_target: string
  ; bits: float
  ; bits_target: string
  ; alnlen: int
  ; alnlen_target: string
  ; alnperc: float option
  ; alnperc_target: string option }
[@@deriving sexp, fields]

[@@@coverage on]

let to_string_header () =
  [ "query"
  ; "total_hits"
  ; "best_pident"
  ; "pident_target"
  ; "best_bits"
  ; "bits_target"
  ; "best_alnlen"
  ; "alnlen_target"
  ; "best_alnperc"
  ; "alnperc_target" ]
  |> String.concat ~sep:"\t"

let to_string t =
  let conv to_s acc _ _ v = to_s v :: acc in
  let conv_float_opt acc _ _ = function
    | None ->
        "None" :: acc
    | Some x ->
        Float.to_string x :: acc
  in
  let conv_string_opt acc _ _ = function
    | None ->
        "None" :: acc
    | Some x ->
        x :: acc
  in
  Fields.Direct.fold
    t
    ~init:[]
    ~query:(conv Fn.id)
    ~total_hits:(conv Int.to_string)
    ~pident:(conv Float.to_string)
    ~pident_target:(conv Fn.id)
    ~bits:(conv Float.to_string)
    ~bits_target:(conv Fn.id)
    ~alnlen:(conv Int.to_string)
    ~alnlen_target:(conv Fn.id)
    ~alnperc:conv_float_opt
    ~alnperc_target:conv_string_opt
  |> List.rev |> String.concat ~sep:"\t"

let update_pident current ~pident ~target =
  if Float.(pident > current.pident) then
    {current with pident; pident_target= target}
  else current

let update_bits current ~bits ~target =
  if Float.(bits > current.bits) then {current with bits; bits_target= target}
  else current

let update_alnlen current ~alnlen ~target =
  if Int.(alnlen > current.alnlen) then
    {current with alnlen; alnlen_target= target}
  else current

let update_alnperc current ~alnperc ~target =
  match (alnperc, current.alnperc) with
  | None, None | None, Some _ ->
      current
  | Some _, None ->
      {current with alnperc; alnperc_target= Some target}
  | Some alnperc', Some current_alnperc ->
      if Float.(alnperc' > current_alnperc) then
        {current with alnperc; alnperc_target= Some target}
      else current

let incr_total_hits current = {current with total_hits= current.total_hits + 1}

let update_best current ~pident ~bits ~alnlen ~alnperc ~target =
  current |> incr_total_hits
  |> update_pident ~pident ~target
  |> update_bits ~bits ~target
  |> update_alnlen ~alnlen ~target
  |> update_alnperc ~alnperc ~target

let alnperc ~alnlen ~tlen =
  let%map.Option tlen = tlen in
  Float.(of_int alnlen /. of_int tlen)

let summarize btab =
  Bio_io.Btab.In_channel.with_file_fold_records
    btab
    ~init:String.Map.empty
    ~f:(fun map record ->
      let query = Bio_io.Btab.Record.query record in
      let target = Bio_io.Btab.Record.target record in
      let pident = Bio_io.Btab.Record.pident record in
      let bits = Bio_io.Btab.Record.bits record in
      let alnlen = Bio_io.Btab.Record.alnlen record in
      let tlen = Bio_io.Btab.Record.tlen record in
      let alnperc = alnperc ~alnlen ~tlen in
      let alnperc_target =
        match alnperc with None -> None | Some _ -> Some target
      in
      Map.update map query ~f:(function
          | None ->
              { query
              ; total_hits= 1
              ; pident
              ; pident_target= target
              ; bits
              ; bits_target= target
              ; alnlen
              ; alnlen_target= target
              ; alnperc
              ; alnperc_target }
          | Some current_best ->
              update_best current_best ~pident ~bits ~alnlen ~alnperc ~target ) )

let print_summary oc map =
  Out_channel.output_string oc (to_string_header () ^ "\n") ;
  Map.iter map ~f:(fun t -> Out_channel.output_string oc (to_string t ^ "\n"))

let summarize_and_print ~dir ~out ~btab =
  let file_name = dir ^/ out in
  let map = summarize btab in
  Out_channel.with_file file_name ~f:(fun oc -> print_summary oc map)

(** Wrapper for all the searches. Call it in the main [run] function. *)
let summarize_searches ~dir ~mmseqs_search_out ~rpsblast_search_out =
  Logs.info (fun m -> m "Summarizing intein DB search") ;
  summarize_and_print
    ~dir
    ~out:"1_mmseqs_search_summary.tsv"
    ~btab:(Mmseqs_search.Out.out mmseqs_search_out) ;
  Logs.info (fun m -> m "Summarizing conserved domain DB search") ;
  summarize_and_print
    ~dir
    ~out:"1_rpsblast_search_summary.tsv"
    ~btab:(Rpsblast.Search.Out.out rpsblast_search_out)

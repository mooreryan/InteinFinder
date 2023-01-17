(** Dealing with fasta records in the alignment in/out files. *)

open! Core
module Record = Bio_io_ext.Fasta.Record
module C = Coord

let gap_char = '-'

[@@@coverage off]

type aln_out =
  {query: Record.query_aln; intein: Record.intein_aln; file_name: string}
[@@deriving sexp_of]

[@@@coverage on]

let is_gap = function '-' -> true | _ -> false

let is_non_gap = Fn.non is_gap

module El = struct
  [@@@coverage off]

  type t = Residue of char | Gap [@@deriving sexp_of]

  [@@@coverage on]

  (* Note that we treat El.t option None case as a gap. *)

  let to_string = function Residue c -> Char.to_string c | Gap -> "-"

  (** Explicitly tell the user about None. Otherwise like [to_string]. *)
  let to_string' = function None -> "None" | Some el -> to_string el

  (** Treat None as a gap. Useful in the internal checks functions. *)
  let to_string_none_is_gap = function None -> "-" | Some el -> to_string el

  (** Concat, but treat none as a gap. Used in the internal checks functions. *)
  let concat_none_is_gap el1 el2 =
    to_string_none_is_gap el1 ^ to_string_none_is_gap el2
end

module Intein_query_info = struct
  [@@@coverage off]

  (** Stuff on the query sequence that corresponds to where the intein aligned. *)
  type t =
    { intein_start_minus_one: El.t option
    ; intein_start: El.t option
    ; intein_penultimate: El.t option
    ; intein_end: El.t option
    ; intein_end_plus_one: El.t option
    ; intein_start_index: C.zero_aln option
    ; intein_end_index: C.zero_aln option
    ; intein_start_to_the_right_of_hit_region_start: bool
    ; intein_end_to_the_left_of_hit_region_end: bool }
  [@@deriving sexp_of, fields]

  [@@@coverage on]

  let to_string t =
    let conv to_s acc _ _ v = to_s v :: acc in
    let conv_el_opt = conv El.to_string' in
    (* let conv_zero_aln_opt = let f x = match x with None -> "None" | Some x ->
       C.to_one_indexed_string x in conv f in *)
    let ignore acc _ _ _ = acc in
    let l =
      Fields.Direct.fold
        t
        ~init:[]
        ~intein_start_minus_one:conv_el_opt
        ~intein_start:conv_el_opt
        ~intein_penultimate:conv_el_opt
        ~intein_end:conv_el_opt
        ~intein_end_plus_one:conv_el_opt
        ~intein_start_index:ignore
        ~intein_end_index:ignore
        ~intein_start_to_the_right_of_hit_region_start:ignore
        ~intein_end_to_the_left_of_hit_region_end:ignore
    in
    l |> List.rev |> String.concat ~sep:"\t"

  let to_string_with_info t ~query_name ~intein_name
      ~(region_index : Zero_indexed_int.t) =
    String.concat
      ~sep:"\t"
      [ query_name
      ; Zero_indexed_int.to_one_indexed_string region_index
      ; intein_name
      ; to_string t ]

  let to_string_with_info_header () =
    [ "query"
    ; "region"
    ; "intein_target"
    ; "intein_start_minus_one"
    ; "intein_start"
    ; "intein_penultimate"
    ; "intein_end"
    ; "intein_end_plus_one" ]
end

type left_to_right_checks =
  { intein_start_to_the_right_of_hit_region_start: bool
  ; intein_start: El.t option
  ; intein_start_index: C.zero_aln option
  ; intein_start_minus_one: El.t option }

type right_to_left_checks =
  { intein_end_to_the_left_of_hit_region_end: bool
  ; intein_end: El.t option
  ; intein_end_index: C.zero_aln option
  ; intein_end_plus_one: El.t option
  ; intein_penultimate: El.t option }

(** You can't have a first without a last, that's why the both come in the
    option. If this is None, then you have an aligned sequence with all gaps,
    which is very bad an (probably) should take down the program. *)
let first_and_last_non_gap_positions :
    Record.query_aln -> (C.zero_aln * C.zero_aln) option =
 fun (Record.Query_aln record) ->
  let first_non_gap, last_non_gap =
    String.foldi
      (Record.seq record)
      ~init:(None, 0)
      ~f:(fun aln_i (first_non_gap, last_non_gap) c ->
        if is_non_gap c then
          match first_non_gap with
          | None ->
              (Some aln_i, aln_i)
          | Some _ ->
              (first_non_gap, aln_i)
        else (first_non_gap, last_non_gap) )
  in
  match first_non_gap with
  | None ->
      (* This happens if the sequence was all gaps. *)
      None
  | Some first_non_gap ->
      Some (C.zero_aln_exn first_non_gap, C.zero_aln_exn last_non_gap)

let find_next_non_gap_index :
    string -> current_index:C.zero_aln -> C.zero_aln option =
 fun s ~current_index ->
  (* Fail if index is too big. *)
  if C.to_int current_index >= String.length s then
    raise (Invalid_argument "current index >= string length") ;
  (* We want to start the search AFTER the current index. *)
  let pos = C.(incr current_index |> to_int) in
  if pos >= String.length s then None
  else
    let%map.Option i = String.lfindi ~pos s ~f:(fun _ c -> is_non_gap c) in
    (* lfindi will only ever return a valid index, so exn is safe here. *)
    C.zero_aln_exn i

let find_previous_non_gap_index :
    string -> current_index:C.zero_aln -> C.zero_aln option =
 fun s ~current_index ->
  (* Fail if index is too big. *)
  if C.to_int current_index >= String.length s then
    raise (Invalid_argument "current index >= string length") ;
  let open Option.Let_syntax in
  (* We want to start the search BEFORE the current index. *)
  let%bind pos = C.decr current_index in
  let%map i =
    String.rfindi ~pos:(C.to_int pos) s ~f:(fun _ c -> is_non_gap c)
  in
  (* lfindi will only ever return a valid index, so exn is safe here. *)
  C.zero_aln_exn i

module Leftover = struct
  type t =
    { aln_i: C.zero_aln
    ; prev_non_gap_index: C.zero_aln option
    ; next_non_gap_index: C.zero_aln option }

  let v ~aln_i ~prev_non_gap_index ~next_non_gap_index =
    {aln_i; next_non_gap_index; prev_non_gap_index}

  (** Makes a new [t] with the data from the aligned query sequence. (Call when
      generating the map from aln to raw.) *)
  let create ~query ~aln_i =
    let next_non_gap_index =
      find_next_non_gap_index query ~current_index:aln_i
    in
    let prev_non_gap_index =
      find_previous_non_gap_index query ~current_index:aln_i
    in
    v ~aln_i ~prev_non_gap_index ~next_non_gap_index
end

(* Note: This uses add exn in places where it is a bug if the key is already
   present. *)
let aln_to_raw : Record.query_aln -> C.Query_aln_to_raw.t =
 fun (Record.Query_aln query_record as query_aln) ->
  let module Map = C.Query_aln_to_raw in
  let open C.Query_aln_to_raw.Value in
  let first_non_gap_pos, last_non_gap_pos =
    Option.value_exn
      ~error:
        (Error.createf
           "first_and_last_non_gap_positions returned None.  This can only \
            happen if the aligned query sequence was all gaps.  If you see \
            this message, there is definitely something wrong with your input \
            data.  The bad query was '%s'."
           (Record.id query_record) )
    @@ first_and_last_non_gap_positions query_aln
  in
  let query = Record.seq query_record in
  (* Tracks the befores, afters, ats and the leftovers. *)
  let first_pass_reducer aln_i (raw_i, map, leftovers) query_char =
    let aln_i = C.zero_aln_exn aln_i in
    if C.(aln_i < first_non_gap_pos) then (
      (* If this assertion fails, there is either a bug in the
         first_and_last_non_gap_positions function, or you passed the wrong
         sequence to that function and to this one. Same with the assertion
         below this one. *)
      assert (is_gap query_char) ;
      let next_map = Map.add_exn map ~key:aln_i ~data:Before in
      (raw_i, next_map, leftovers) )
    else if C.(aln_i > last_non_gap_pos) then (
      assert (is_gap query_char) ;
      let next_map = Map.add_exn map ~key:aln_i ~data:After in
      (raw_i, next_map, leftovers) )
    else if is_gap query_char then
      (* let next_non_gap_index = find_next_non_gap_index query
         ~current_index:aln_i in let prev_non_gap_index =
         find_previous_non_gap_index query ~current_index:aln_i in let leftover
         = Leftover.v ~aln_i ~raw_i ~prev_non_gap_index ~next_non_gap_index
         in *)
      let leftover = Leftover.create ~query ~aln_i in
      let next_leftovers = leftover :: leftovers in
      (raw_i, map, next_leftovers)
    else
      (* Non-gap *)
      let next_raw_i = raw_i + 1 in
      let data = At (C.zero_raw_exn raw_i) in
      let next_map = Map.add_exn map ~key:aln_i ~data in
      (next_raw_i, next_map, leftovers)
  in
  (* Second pass we fill in the other betweens (gap columns). *)
  (* Take the map and a leftover gap column and add it to the map. *)
  let add_leftover_gap_column map
      {Leftover.aln_i; prev_non_gap_index; next_non_gap_index} =
    (* Note: We don't use the opt method here because, if this key is not found,
       it is a bug. *)
    let find i =
      match Map.find_exn map i with
      | At x ->
          x
      | _ ->
          Utils.impossible
            "non-gap column index should always be 'At' some raw index in the \
             query" [@coverage off]
    in
    let next_non_gap_index_raw = Option.map next_non_gap_index ~f:find in
    let prev_non_gap_index_raw = Option.map prev_non_gap_index ~f:find in
    let data = Between (prev_non_gap_index_raw, next_non_gap_index_raw) in
    Map.add_exn map ~key:aln_i ~data
  in
  let first_pass query =
    let _raw_i, map, leftovers =
      let raw_i = 0 in
      let map = Map.empty in
      let leftovers = [] in
      String.foldi query ~init:(raw_i, map, leftovers) ~f:first_pass_reducer
    in
    (map, leftovers)
  in
  let second_pass (map, leftovers) =
    List.fold leftovers ~init:map ~f:add_leftover_gap_column
  in
  query |> first_pass |> second_pass

let add_prefix : string -> Record.t -> Record.t =
 fun prefix record ->
  let open Record in
  let id = id record in
  let new_id = prefix ^ id in
  with_id new_id record

let clip_sequence (Record.Query_raw record) clipping_region =
  (* Convert 1-indexed to 0-indexed. *)
  let start = C.to_zero_indexed_int @@ Region.start clipping_region in
  let stop = C.to_zero_indexed_int @@ Region.end_ clipping_region in
  (* Basic assumptions with the region and seq length.. *)
  assert (start >= 0 && start < Record.seq_length record) ;
  assert (stop >= 0 && stop < Record.seq_length record) ;
  let seq = Record.seq record in
  let clipped_seq =
    String.sub seq ~pos:start ~len:(Region.length clipping_region)
  in
  let clipped_seq_id = "clipped___" ^ Record.id record in
  Record.create ~id:clipped_seq_id ~desc:None ~seq:clipped_seq
  |> Record.clipped_query_raw

(* Write the 3 sequences that will be aligned. (query, intein target, and
   clipped query). *)
let write_aln_in_file ~query:(Record.Query_raw query)
    ~clipped_query:(Record.Clipped_query_raw clipped_query)
    ~intein:(Record.Intein_raw intein) ~file_name =
  let query_seq = add_prefix Record.query_prefix query in
  let clipped_query_seq =
    add_prefix Record.clipped_query_prefix clipped_query
  in
  let intein_seq = add_prefix Record.intein_prefix intein in
  Out_channel.write_lines
    file_name
    [ Record.to_string intein_seq
    ; Record.to_string clipped_query_seq
    ; Record.to_string query_seq ]

(* Note: you can't trust that the order of the aligned sequences is correct.

   Note: this asserts the lengths of the aligment as well. *)
let read_aln_out_file file_name =
  let assert_aln_lengths (Record.Query_aln query)
      (Record.Clipped_query_aln clipped_query) (Record.Intein_aln intein) =
    let query_len = Record.seq_length query in
    let clipped_query_len = Record.seq_length clipped_query in
    let intein_len = Record.seq_length intein in
    assert (query_len = clipped_query_len && query_len = intein_len)
  in
  let parse_seqs r1 r2 r3 =
    (* Note: this is generated code. *)
    match
      ( Record.query_clipped_or_intein_of_record r1
      , Record.query_clipped_or_intein_of_record r2
      , Record.query_clipped_or_intein_of_record r3 )
    with
    | Ok (Query query), Ok (Clipped_query clipped_query), Ok (Intein intein)
    | Ok (Query query), Ok (Intein intein), Ok (Clipped_query clipped_query)
    | Ok (Clipped_query clipped_query), Ok (Query query), Ok (Intein intein)
    | Ok (Clipped_query clipped_query), Ok (Intein intein), Ok (Query query)
    | Ok (Intein intein), Ok (Query query), Ok (Clipped_query clipped_query)
    | Ok (Intein intein), Ok (Clipped_query clipped_query), Ok (Query query) ->
        assert_aln_lengths query clipped_query intein ;
        {query; intein; file_name}
    | _ ->
        (* Should be okay as there SHOULD never be a case in practice where this
           happens. If it does it's a pretty programmer error. *)
        let file_contents = In_channel.read_all file_name in
        failwithf
          "Expected one query, one clipped query, and one intein, but got \
           something else in alignment out file:\n\
           %s"
          file_contents
          ()
  in
  match Bio_io.Fasta.In_channel.with_file_records file_name with
  | [r1; r2; r3] ->
      parse_seqs r1 r2 r3
  | l ->
      let num_seqs = List.length l in
      failwithf
        "expected three sequences in the alignment output file but got %d"
        num_seqs
        ()

let left_to_right_range aln_len =
  List.range 0 aln_len ~start:`inclusive ~stop:`exclusive
  |> List.map ~f:C.zero_aln_exn

let right_to_left_range aln_len =
  List.range aln_len 0 ~start:`exclusive ~stop:`inclusive ~stride:(-1)
  |> List.map ~f:C.zero_aln_exn

let string_get_aln : string -> C.zero_aln -> char =
 fun s i -> String.get s (C.to_int i)

let update_raw_query_idx ~query_char ~raw_query_idx ~start_idx ~index_updater =
  if is_non_gap query_char then
    match !raw_query_idx with
    | Some raw_query_idx' ->
        raw_query_idx := Some (index_updater raw_query_idx')
    | None ->
        raw_query_idx := Some (C.zero_raw_exn start_idx)

(* TODO: intein_start_to_the_right_of_hit_region_start name is misleading as it
   actually does check that it is on the region boundary ...and counts that as
   good. (Same with the before the hit region one. *)
let check_if_intein_start_on_the_query_is_after_hit_region_start
    ~hit_region_start ~raw_query_idx
    ~intein_start_to_the_right_of_hit_region_start =
  match !raw_query_idx with
  | Some raw_query_idx ->
      if C.(hit_region_start <= raw_query_idx) then
        intein_start_to_the_right_of_hit_region_start := true
  | None ->
      ()

let check_if_intein_end_on_the_query_is_before_hit_region_end ~hit_region_end
    ~raw_query_idx ~intein_end_to_the_left_of_hit_region_end =
  match !raw_query_idx with
  | Some raw_query_idx ->
      if C.(raw_query_idx <= hit_region_end) then
        intein_end_to_the_left_of_hit_region_end := true
  | None ->
      ()

(** Set intein start index to the current alignment index. *)
let set_intein_start_index ~intein_start_index ~aln_idx =
  intein_start_index := Some aln_idx

let set_intein_end_index ~intein_end_index ~aln_idx =
  intein_end_index := Some aln_idx

let set_intein_start_char ~intein_start ~query_char =
  if is_gap query_char then intein_start := Some El.Gap
  else intein_start := Some (El.Residue query_char)

let set_intein_end_char ~intein_end ~query_char =
  if is_gap query_char then intein_end := Some El.Gap
  else intein_end := Some (El.Residue query_char)

let set_intein_start_minus_one ~query_char ~raw_query_chars
    ~intein_start_minus_one =
  if is_gap query_char then
    (* If there is a gap in the query char then the intein start minus one
       cannot be determined. *)
    intein_start_minus_one := None
  else
    match !raw_query_chars with
    | minus_one :: _ ->
        (* If there exists a residue on the query before the current residue,
           that is the minus_one. *)
        intein_start_minus_one := Some (El.Residue minus_one)
    | [] ->
        (* If there are no previous residues on the query, then you know that
           the intein is at the very start of the query. So there is no
           minus-one. In full-length proteins, this cannot happen. But in
           metagenomic derived sequenecs you could get a fragment that happens
           to start at an intein. It should be a rare event though. *)
        (* Should already be none, but be explicit about it. *)
        intein_start_minus_one := None

let set_intein_end_plus_one ~query_char ~raw_query_chars ~intein_end_plus_one =
  if is_gap query_char then
    (* If there is a gap in the query char then the intein end plus one cannot
       be determined. *)
    intein_end_plus_one := None
  else
    match !raw_query_chars with
    | plus_one :: _ ->
        intein_end_plus_one := Some (El.Residue plus_one)
    | [] ->
        intein_end_plus_one := None

let track_non_gap_query_chars ~query_char ~raw_query_chars =
  if is_non_gap query_char then
    raw_query_chars := query_char :: !raw_query_chars

let left_to_right_checks_v ~intein_start ~intein_start_index
    ~intein_start_minus_one ~intein_start_to_the_right_of_hit_region_start =
  { intein_start_to_the_right_of_hit_region_start=
      !intein_start_to_the_right_of_hit_region_start
  ; intein_start= !intein_start
  ; intein_start_index= !intein_start_index
  ; intein_start_minus_one= !intein_start_minus_one }

let right_to_left_checks_v ~intein_end_to_the_left_of_hit_region_end
    ~intein_end_index ~intein_end ~intein_end_plus_one ~intein_penultimate =
  { intein_end_to_the_left_of_hit_region_end=
      !intein_end_to_the_left_of_hit_region_end
  ; intein_end_index= !intein_end_index
  ; intein_end= !intein_end
  ; intein_end_plus_one= !intein_end_plus_one
  ; intein_penultimate= !intein_penultimate }

let scan_left_to_right :
       aln_len:int
    -> query_seq:string
    -> intein_seq:string
    -> hit_region_start:C.one_raw
    -> left_to_right_checks =
 fun ~aln_len ~query_seq ~intein_seq ~hit_region_start ->
  (* This is what we are tracking in this function. *)
  let intein_start_to_the_right_of_hit_region_start = ref false in
  let intein_start = ref None in
  let intein_start_index = ref None in
  let intein_start_minus_one = ref None in
  let raw_query_idx = ref None in
  (* The hd of this list will be the previous raw residue. Use it to get the
     penultimate and the minus one. *)
  let raw_query_chars = ref [] in
  let iter_fun aln_idx =
    let query_char = string_get_aln query_seq aln_idx in
    let intein_char = string_get_aln intein_seq aln_idx in
    update_raw_query_idx
      ~query_char
      ~raw_query_idx
      ~start_idx:0
      ~index_updater:C.incr ;
    (* Note: we don't have to check if we're in the intein, because the first
       non_gap_char we see will cause a raise Exit at the end of this [if]. *)
    if is_non_gap intein_char then (
      check_if_intein_start_on_the_query_is_after_hit_region_start
        ~hit_region_start
        ~raw_query_idx
        ~intein_start_to_the_right_of_hit_region_start ;
      set_intein_start_index ~intein_start_index ~aln_idx ;
      set_intein_start_char ~intein_start ~query_char ;
      set_intein_start_minus_one
        ~query_char
        ~raw_query_chars
        ~intein_start_minus_one ;
      raise Exit ) ;
    track_non_gap_query_chars ~query_char ~raw_query_chars
  in
  let range = left_to_right_range aln_len in
  let () = try List.iter range ~f:iter_fun with Exit -> () in
  left_to_right_checks_v
    ~intein_start
    ~intein_start_index
    ~intein_start_minus_one
    ~intein_start_to_the_right_of_hit_region_start

let scan_right_to_left :
       aln_len:int
    -> query_seq:string
    -> intein_seq:string
    -> raw_query_length:int
    -> hit_region_end:C.one_raw
    -> right_to_left_checks =
 fun ~aln_len ~query_seq ~intein_seq ~raw_query_length ~hit_region_end ->
  let intein_end_to_the_left_of_hit_region_end = ref false in
  let intein_end = ref None in
  let intein_end_index = ref None in
  let intein_end_plus_one = ref None in
  let raw_query_idx = ref None in
  let intein_penultimate = ref None in
  (* The hd of this list will be the previous raw residue. Use it to get the
     penultimate and the minus one. *)
  let raw_query_chars = ref [] in
  (* Set this to true when we are read to look for penultimate residue. *)
  let find_the_penultimate = ref false in
  let f aln_idx =
    let query_char = string_get_aln query_seq aln_idx in
    let intein_char = string_get_aln intein_seq aln_idx in
    update_raw_query_idx
      ~query_char
      ~raw_query_idx
      ~start_idx:(raw_query_length - 1)
      ~index_updater:C.decr_exn ;
    if !find_the_penultimate && Option.is_none !intein_penultimate then
      if is_non_gap intein_char then (
        if is_gap query_char then intein_penultimate := Some El.Gap
        else intein_penultimate := Some (El.Residue query_char) ;
        raise Exit ) ;
    if is_non_gap intein_char then (
      check_if_intein_end_on_the_query_is_before_hit_region_end
        ~hit_region_end
        ~raw_query_idx
        ~intein_end_to_the_left_of_hit_region_end ;
      set_intein_end_index ~intein_end_index ~aln_idx ;
      find_the_penultimate := true ;
      set_intein_end_char ~intein_end ~query_char ;
      set_intein_end_plus_one ~query_char ~raw_query_chars ~intein_end_plus_one
      ) ;
    track_non_gap_query_chars ~query_char ~raw_query_chars
  in
  let range = right_to_left_range aln_len in
  let () = try List.iter range ~f with Exit -> () in
  right_to_left_checks_v
    ~intein_end_to_the_left_of_hit_region_end
    ~intein_end_index
    ~intein_end
    ~intein_end_plus_one
    ~intein_penultimate

(* You need to look at the alignment, and figure out all the interesting
   residues on the query seq as defined by the intein alignment. *)
let parse_aln_out :
       hit_region_start:C.one_raw
    -> hit_region_end:C.one_raw
    -> raw_query_length:int
    -> aln_out
    -> Intein_query_info.t =
 fun ~hit_region_start
     ~hit_region_end
     ~raw_query_length
     {query= Record.Query_aln query; intein= Record.Intein_aln intein; _} ->
  (* NOTE: for paper/docs...if the intein start/end is in a gap on the query,
     then then minus/plus one will have to be None, as we can't even place the
     start and end on the query. There are some tests in there about that. *)

  (* You know aln lengths are good because of assertions elsewhere. *)
  let aln_len = Record.seq_length query in
  let query_seq = Record.seq query in
  let intein_seq = Record.seq intein in
  (* Scan left to right. *)
  let { intein_start_to_the_right_of_hit_region_start
      ; intein_start
      ; intein_start_index
      ; intein_start_minus_one } =
    scan_left_to_right ~aln_len ~query_seq ~intein_seq ~hit_region_start
  in
  (* Scan right to left. *)
  let { intein_end_to_the_left_of_hit_region_end
      ; intein_end
      ; intein_end_index
      ; intein_end_plus_one
      ; intein_penultimate } =
    scan_right_to_left
      ~aln_len
      ~query_seq
      ~intein_seq
      ~raw_query_length
      ~hit_region_end
  in
  { intein_start_minus_one
  ; intein_start
  ; intein_penultimate
  ; intein_end
  ; intein_end_plus_one
  ; intein_start_index
  ; intein_end_index
  ; intein_start_to_the_right_of_hit_region_start
  ; intein_end_to_the_left_of_hit_region_end }

module Checks = struct
  (* Note: for docs/paper, we lose some info here as we treat None as a "gap".
     Gaps and none will both appear as -. *)

  module Position_check = struct
    [@@@coverage off]

    (* Positions in the region are None if the intein lined up with a gap in the
       query. *)
    type t =
      | Pass of C.Query_aln_to_raw.Value.t
      | Fail of C.Query_aln_to_raw.Value.t
      | Fail_none
    [@@deriving sexp_of, variants]

    [@@@coverage on]

    let pass t = is_pass t

    let to_tier_or_fail : t -> Tier.Tier_or_fail.t = function
      | Pass _ ->
          Tier Tier.t1
      | Fail _ | Fail_none ->
          Fail

    let to_string = function
      | Pass v ->
          let x = C.Query_aln_to_raw.Value.to_string v in
          [%string "Pass (%{x})"]
      | Fail v ->
          let x = C.Query_aln_to_raw.Value.to_string v in
          [%string "Fail (%{x})"]
      | Fail_none ->
          "Fail (None)"

    let check_intein_start_index :
           intein_start_index:C.zero_aln option
        -> intein_start_to_the_right_of_hit_region_start:bool
        -> aln_to_raw:C.Query_aln_to_raw.t
        -> t =
     fun ~intein_start_index
         ~intein_start_to_the_right_of_hit_region_start
         ~aln_to_raw ->
      match
        (intein_start_index, intein_start_to_the_right_of_hit_region_start)
      with
      | None, false | None, true ->
          Fail_none
      | Some aln_idx, false ->
          let raw_idx = C.Query_aln_to_raw.find_exn aln_to_raw aln_idx in
          Fail raw_idx
      | Some aln_idx, true ->
          (* NOTE: you can pass the region test but not be trimmable if the
             Value is between and not At. *)
          let raw_idx = C.Query_aln_to_raw.find_exn aln_to_raw aln_idx in
          Pass raw_idx

    let check_intein_end_index :
           intein_end_index:C.zero_aln option
        -> intein_end_to_the_left_of_hit_region_end:bool
        -> aln_to_raw:C.Query_aln_to_raw.t
        -> t =
     fun ~intein_end_index ~intein_end_to_the_left_of_hit_region_end ~aln_to_raw ->
      match (intein_end_index, intein_end_to_the_left_of_hit_region_end) with
      | None, false | None, true ->
          Fail_none
      | Some aln_idx, false ->
          let raw_idx = C.Query_aln_to_raw.find_exn aln_to_raw aln_idx in
          Fail raw_idx
      | Some aln_idx, true ->
          let raw_idx = C.Query_aln_to_raw.find_exn aln_to_raw aln_idx in
          Pass raw_idx
  end

  module Full_region_check = struct
    [@@@coverage off]

    type t = Pass | Start_pass | End_pass | Fail
    [@@deriving sexp_of, variants]

    [@@@coverage on]

    let pass t = is_pass t

    let to_string = Variants.to_name

    let check :
        start_position:Position_check.t -> end_position:Position_check.t -> t =
     fun ~start_position ~end_position ->
      match (start_position, end_position) with
      | Pass _, Pass _ ->
          Pass
      | Pass _, Fail _ | Pass _, Fail_none ->
          Start_pass
      | Fail _, Pass _ | Fail_none, Pass _ ->
          End_pass
      | Fail _, Fail _
      | Fail _, Fail_none
      | Fail_none, Fail _
      | Fail_none, Fail_none ->
          Fail

    let to_tier_or_fail : t -> Tier.Tier_or_fail.t = function
      | Pass ->
          Tier Tier.t1
      | Start_pass | End_pass | Fail ->
          Fail
  end

  (* TODO: add to hacking...should have t, should have check, should have pass,
     to_string, etc etc. *)
  module Start_residue_check = struct
    [@@@coverage off]

    type t = Pass of (Tier.t * char) | Fail of char
    [@@deriving sexp_of, variants]

    [@@@coverage on]

    let pass t = is_pass t

    let of_tier_or_fail : char -> Tier.Tier_or_fail.t -> t =
     fun c tof -> match tof with Tier t -> Pass (t, c) | Fail -> Fail c

    let to_tier_or_fail : t -> Tier.Tier_or_fail.t = function
      | Pass (tier, _) ->
          Tier tier
      | Fail _ ->
          Fail

    let check' c tier_map =
      of_tier_or_fail c @@ Tier.Map.find tier_map @@ String.of_char c

    let check : El.t option -> tier_map:Tier.Map.t -> t =
     fun el ~tier_map ->
      match el with
      | None | Some Gap ->
          Fail '-'
      | Some (Residue c) ->
          check' c tier_map

    let to_string = function
      | Pass (tier, residue) ->
          [%string "Pass (%{tier#Tier} %{residue#Char})"]
      | Fail v ->
          [%string "Fail (%{v#Char})"]
  end

  module End_residues_check = struct
    [@@@coverage off]

    type t = Pass of (Tier.t * string) | Fail of string
    [@@deriving sexp_of, variants]

    [@@@coverage on]

    let pass t = is_pass t

    let of_tier_or_fail : string -> Tier.Tier_or_fail.t -> t =
     fun s tof -> match tof with Tier t -> Pass (t, s) | Fail -> Fail s

    let to_tier_or_fail : t -> Tier.Tier_or_fail.t = function
      | Pass (tier, _) ->
          Tier tier
      | Fail _ ->
          Fail

    let check' s tier_map = of_tier_or_fail s @@ Tier.Map.find tier_map s

    let check :
        penultimate:El.t option -> end_:El.t option -> tier_map:Tier.Map.t -> t
        =
     fun ~penultimate ~end_ ~tier_map ->
      let el = El.concat_none_is_gap penultimate end_ in
      check' el tier_map

    let to_string = function
      | Pass (tier, residues) ->
          [%string "Pass (%{tier#Tier} %{residues})"]
      | Fail v ->
          [%string "Fail (%{v})"]
  end

  module End_plus_one_residue_check = struct
    [@@@coverage off]

    (** [Na] will happen if the end of the intein is at the end of the query
        alignment (or beyond the end). It will be NA in these cases because
        there is no C-terminal extein sequence that we can find, so there is no
        way to tell its first residue. *)
    type t = Pass of (Tier.t * char) | Fail of char | Na
    [@@deriving sexp_of, variants]

    [@@@coverage on]

    let pass = function Pass _ | Na -> true | Fail _ -> false

    let of_tier_or_fail : char -> Tier.Tier_or_fail.t -> t =
     fun c tof -> match tof with Tier t -> Pass (t, c) | Fail -> Fail c

    (* WARNING: a little counterintuitive, but the [Na] case goes to Tier 1
       pass. Generally this should only be used along with the lowest tier...so
       treating no data as the highest tier will not affect the calculation of
       the lowest tier. *)
    let to_tier_or_fail : t -> Tier.Tier_or_fail.t = function
      | Pass (tier, _) ->
          Tier tier
      | Fail _ ->
          Fail
      | Na ->
          Tier Tier.t1

    (* TODO: there is logic below to handle the NA condition...should it be
       moved here? *)

    let check' c tier_map =
      of_tier_or_fail c @@ Tier.Map.find tier_map @@ String.of_char c

    let check : El.t option -> tier_map:Tier.Map.t -> t =
     fun el ~tier_map ->
      match el with
      | None | Some Gap ->
          Fail '-'
      | Some (Residue c) ->
          check' c tier_map

    let to_string = function
      | Pass (tier, residue) ->
          [%string "Pass (%{tier#Tier} %{residue#Char})"]
      | Fail v ->
          [%string "Fail (%{v#Char})"]
      | Na ->
          "NA"
  end

  [@@@coverage off]

  (** These all refer to the intein on the query. *)
  type t =
    { intein_length: int option
    ; start_residue: Start_residue_check.t
    ; end_residues: End_residues_check.t
    ; end_plus_one_residue: End_plus_one_residue_check.t
    ; start_position: Position_check.t
    ; end_position: Position_check.t
    ; region: Full_region_check.t }
  [@@deriving sexp_of, fields]

  [@@@coverage on]

  (* Note that order of these fields defines the order of the fields fold
     to_string function below.*)

  let of_intein_query_info :
      Intein_query_info.t -> C.Query_aln_to_raw.t -> int -> config:Config.t -> t
      =
   fun { intein_start_minus_one= _
       ; intein_start
       ; intein_penultimate
       ; intein_end
       ; intein_end_plus_one
       ; intein_start_index
       ; intein_end_index
       ; intein_start_to_the_right_of_hit_region_start
       ; intein_end_to_the_left_of_hit_region_end }
       aln_to_raw
       raw_query_len
       ~config ->
    let intein_start_index_raw =
      let%map.Option i = intein_start_index in
      C.Query_aln_to_raw.find_exn aln_to_raw i
    in
    let intein_end_index_raw =
      let%map.Option i = intein_end_index in
      C.Query_aln_to_raw.find_exn aln_to_raw i
    in
    let intein_length =
      let%bind.Option start, end_ =
        Option.both intein_start_index_raw intein_end_index_raw
      in
      C.Query_aln_to_raw.Value.length ~start ~end_
    in
    let start_residue =
      Start_residue_check.check
        intein_start
        ~tier_map:config.checks.start_residue
    in
    let end_residues =
      End_residues_check.check
        ~penultimate:intein_penultimate
        ~end_:intein_end
        ~tier_map:config.checks.end_residues
    in
    let end_plus_one_residue =
      let check intein_end_plus_one =
        End_plus_one_residue_check.check
          intein_end_plus_one
          ~tier_map:config.checks.end_plus_one_residue
      in
      match intein_end_index_raw with
      | Some C.Query_aln_to_raw.Value.After ->
          End_plus_one_residue_check.Na
      | Some (C.Query_aln_to_raw.Value.At i) ->
          if C.(incr i |> to_int) = raw_query_len then
            End_plus_one_residue_check.Na
          else check intein_end_plus_one
      | _ ->
          check intein_end_plus_one
    in
    let start_position =
      Position_check.check_intein_start_index
        ~intein_start_index
        ~intein_start_to_the_right_of_hit_region_start
        ~aln_to_raw
    in
    let end_position =
      Position_check.check_intein_end_index
        ~intein_end_index
        ~intein_end_to_the_left_of_hit_region_end
        ~aln_to_raw
    in
    let region = Full_region_check.check ~start_position ~end_position in
    { intein_length
    ; start_residue
    ; end_residues
    ; end_plus_one_residue
    ; start_position
    ; end_position
    ; region }

  let pass : t -> bool =
   fun t ->
    let use pass _ _ v = pass v in
    let ignore _ _ _ = true in
    Fields.Direct.for_all
      t
      ~start_residue:(use Start_residue_check.pass)
      ~end_residues:(use End_residues_check.pass)
      ~end_plus_one_residue:(use End_plus_one_residue_check.pass)
      ~start_position:(use Position_check.pass)
      ~end_position:(use Position_check.pass)
      ~region:(use Full_region_check.pass)
      ~intein_length:ignore

  (* Fold the record down to Pass with tier or fail. *)
  let to_tier_or_fail_list t : Tier.Tier_or_fail.t list =
    let conv to_tier_or_fail acc _ _ v = to_tier_or_fail v :: acc in
    let ignore acc _ _ _ = acc in
    Fields.Direct.fold
      t
      ~init:[]
      ~start_residue:(conv Start_residue_check.to_tier_or_fail)
      ~end_residues:(conv End_residues_check.to_tier_or_fail)
      ~end_plus_one_residue:(conv End_plus_one_residue_check.to_tier_or_fail)
      ~start_position:(conv Position_check.to_tier_or_fail)
      ~end_position:(conv Position_check.to_tier_or_fail)
      ~region:(conv Full_region_check.to_tier_or_fail)
      ~intein_length:ignore

  (* TODO: rename *)
  let overall_pass_string : t -> string =
   fun t ->
    t
    |> to_tier_or_fail_list
    |> Tier.Tier_or_fail.worst_tier
    |> Option.value_exn ~message:"tier or fail list should never be empty"
    |> Tier.Tier_or_fail.to_string

  let to_string t =
    let conv to_s acc _ _ v = to_s v :: acc in
    let l =
      Fields.Direct.fold
        t
        ~init:[]
        ~intein_length:(conv Utils.string_of_int_option)
        ~start_residue:(conv Start_residue_check.to_string)
        ~end_residues:(conv End_residues_check.to_string)
        ~end_plus_one_residue:(conv End_plus_one_residue_check.to_string)
        ~start_position:(conv Position_check.to_string)
        ~end_position:(conv Position_check.to_string)
        ~region:(conv Full_region_check.to_string)
    in
    let l = overall_pass_string t :: l in
    l |> List.rev |> String.concat ~sep:"\t"

  let to_string_header () =
    [ "intein_length"
    ; "start_residue_check"
    ; "end_residues_check"
    ; "end_plus_one_residue_check"
    ; "start_position_check"
    ; "end_position_check"
    ; "region_check"
    ; "overall_check" ]
end

let uber_header () =
  String.concat ~sep:"\t"
  @@ Intein_query_info.to_string_with_info_header ()
  @ Checks.to_string_header ()

module Mafft = struct
  module Sh = Shexp_process

  type opts = {exe: string; in_file: string; out_file: string}

  let opts ~exe ~in_file ~out_file = {exe; in_file; out_file}

  type proc = {prog: string; args: string list}

  let proc {exe; in_file; _} =
    let args = ["--quiet"; "--auto"; "--thread"; "1"; in_file] in
    {prog= exe; args}

  (* Printable representation of a command run by Process.run *)
  let cmd_to_string {prog; args; _} =
    let args = String.concat args ~sep:" " in
    [%string "%{prog} %{args}"]

  (** Returns the output file name if successful. *)
  let run : opts:opts -> log_base:string -> string Async.Deferred.Or_error.t =
   fun ~opts ~log_base ->
    let open Async in
    let in_file_check =
      if Sys_unix.file_exists_exn opts.in_file then Deferred.Or_error.return ()
      else
        Deferred.Or_error.errorf
          "expected file '%s' to exist, but it did not"
          opts.in_file
    in
    let out_file_check =
      if Sys_unix.file_exists_exn opts.out_file then
        Deferred.Or_error.errorf
          "expected file '%s' not to exist, but it did"
          opts.out_file
      else Deferred.Or_error.return ()
    in
    let%bind.Deferred.Or_error () =
      Deferred.Or_error.all_unit [in_file_check; out_file_check]
    in
    let log = Utils.log_name ~log_base ~desc:"mafft" in
    let ({prog; args} as proc) = proc opts in
    match%bind Process.run ~prog ~args () with
    | Ok stdout ->
        let%bind _ =
          Writer.with_file opts.out_file ~f:(fun writer ->
              Deferred.Or_error.return
              @@ Writer.write_line writer
              @@ String.strip stdout )
        in
        Deferred.Or_error.return opts.out_file
    | Error e ->
        Writer.with_file log ~f:(fun writer ->
            let cmd = cmd_to_string proc in
            let msg =
              [%string "There was a problem running the following command"]
            in
            Writer.write_line writer msg ;
            Writer.write_line writer cmd ;
            Writer.write_line writer "ERROR:" ;
            Writer.write_line writer (Error.to_string_hum e) ;
            let%bind () = Writer.flushed writer in
            Deferred.Or_error.error_string (Error.to_string_hum e) )
end

let aln_io_file_names ~aln_dir ~query_name ~intein_name
    ~(region_index : Zero_indexed_int.t) ~hit_index =
  let basename in_or_out =
    sprintf
      "mafft_%s___%s___%s___%d___%d.fa"
      in_or_out
      query_name
      intein_name
      (Zero_indexed_int.to_one_indexed_int region_index)
      (* TODO: indexing *)
      (hit_index + 1)
  in
  let aln_in_file = aln_dir ^/ basename "in" in
  let aln_out_file = aln_dir ^/ basename "out" in
  (aln_in_file, aln_out_file)

module Trim_inteins = struct
  let should_trim alignment_checks = Checks.pass alignment_checks

  let trim_intein :
         alignment_checks:Checks.t
      -> raw_query:Record.query_raw
      -> (string * string) option =
   fun ~alignment_checks ~raw_query:(Record.Query_raw raw_query) ->
    if should_trim alignment_checks then
      match
        (alignment_checks.start_position, alignment_checks.end_position)
      with
      | Pass (At start_coord as start), Pass (At end_coord as end_) ->
          let%map.Option len =
            Coord.Query_aln_to_raw.Value.length ~start ~end_
          in
          let intein =
            String.sub
              (Bio_io.Fasta.Record.seq raw_query)
              ~pos:(Coord.to_zero_indexed_int start_coord)
              ~len
          in
          let region_string =
            let start = Coord.to_one_indexed_string start_coord in
            let end_ = Coord.to_one_indexed_string end_coord in
            [%string "start_%{start}___end_%{end_}"]
          in
          (intein, region_string)
      | _ ->
          None
    else None

  let trim_and_write_intein :
         alignment_checks:Checks.t
      -> raw_query:Record.query_raw
      -> query_name:string
      -> region_index:Zero_indexed_int.t
      -> writer:Async.Writer.t
      -> unit Async.Deferred.t =
   fun ~alignment_checks
       ~raw_query:(Record.Query_raw _ as raw_query)
       ~query_name
       ~region_index
       ~writer ->
    match trim_intein ~alignment_checks ~raw_query with
    | None ->
        Async.Deferred.return ()
    | Some (intein, region) ->
        let region_index =
          Zero_indexed_int.to_one_indexed_string region_index
        in
        let region_index = [%string "region_%{region_index}"] in
        let id = [%string ">%{query_name}___%{region_index}___%{region}\n"] in
        let record = [%string "%{id}%{intein}"] in
        Async.Writer.write_line writer record ;
        Async.Writer.flushed writer
end

(** Writes the alignment checks, and if necessary the trimmed intein. *)
let write_aln_checks aln_out_file ~hit_region ~raw_query_length ~raw_query
    ~query_new_name_to_old_name ~query_name ~intein_name
    ~(region_index : Zero_indexed_int.t) ~intein_checks_writer
    ~should_remove_aln_files ~trimmed_inteins_writer ~config =
  let aln_out = read_aln_out_file aln_out_file in
  let intein_query_info : Intein_query_info.t =
    parse_aln_out
      ~hit_region_start:hit_region.Region.start
      ~hit_region_end:hit_region.end_
      ~raw_query_length
      aln_out
  in
  let aln_to_raw = aln_to_raw aln_out.query in
  let checks =
    Checks.of_intein_query_info
      intein_query_info
      aln_to_raw
      raw_query_length
      ~config
  in
  let query_name = Map.find_exn query_new_name_to_old_name query_name in
  let first =
    Intein_query_info.to_string_with_info
      intein_query_info
      ~query_name
      ~intein_name
      ~region_index
  in
  let second = Checks.to_string checks in
  Async.Writer.write_line intein_checks_writer [%string "%{first}\t%{second}"] ;
  let%bind.Async.Deferred () = Async.Writer.flushed intein_checks_writer in
  let%bind.Async.Deferred () =
    if should_remove_aln_files then Async_unix.Sys.remove aln_out_file
    else Async.Deferred.return ()
  in
  if Checks.pass checks then
    let%map.Async.Deferred () =
      Trim_inteins.trim_and_write_intein
        ~alignment_checks:checks
        ~raw_query
        ~query_name
        ~region_index
        ~writer:trimmed_inteins_writer
    in
    raise Exit
  else Async.Deferred.return ()

(* Note: some of these values I can calulate from others, but they are also
   known from the call site. Clean up at some point. *)
let run_alignment_and_write_checks ~aln_dir ~(region_index : Zero_indexed_int.t)
    ~hit_index ~query_name ~query_seq:(Record.Query_raw query_seq' as query_seq)
    ~intein_seq:(Record.Intein_raw intein_record as intein_seq) ~log_base
    ~clip_region_padding ~region ~query_new_name_to_old_name
    ~intein_checks_writer ~trimmed_inteins_writer ~should_remove_aln_files
    ~config =
  let intein_name intein_seq' = Record.id intein_seq' in
  let query_len = Record.seq_length query_seq' in
  (* Function to actually run the alignment. *)
  let run_alignment () =
    let clipping_region =
      Region.clip_region region ~padding:clip_region_padding ~query_len ()
    in
    let clipped_query_seq = clip_sequence query_seq clipping_region in
    let aln_in_file, aln_out_file =
      aln_io_file_names
        ~aln_dir
        ~query_name
        ~intein_name:(intein_name intein_record)
        ~region_index
        ~hit_index
    in
    let () =
      write_aln_in_file
        ~query:query_seq
        ~clipped_query:clipped_query_seq
        ~intein:intein_seq
        ~file_name:aln_in_file
    in
    let%bind.Async.Deferred mafft_out =
      Mafft.run
        ~opts:
          (Mafft.opts ~exe:"mafft" ~in_file:aln_in_file ~out_file:aln_out_file)
        ~log_base
    in
    (* We always remove the aln_in file, even if the user wants to keep the
       intermediate aln files. *)
    let%bind.Async.Deferred aln_file_exists =
      Async_unix.Sys.file_exists_exn aln_in_file
    in
    let%map.Async.Deferred () =
      if aln_file_exists then Async_unix.Sys.remove aln_in_file
      else Async.Deferred.return ()
    in
    mafft_out
  in
  let write_aln_checks =
    write_aln_checks
      ~hit_region:region
      ~raw_query_length:query_len
      ~query_new_name_to_old_name
      ~query_name
      ~intein_name:(intein_name intein_record)
      ~region_index
      ~intein_checks_writer
      ~should_remove_aln_files
      ~raw_query:query_seq
      ~trimmed_inteins_writer
      ~config
  in
  Utils.iter_if_ok (run_alignment ()) ~f:write_aln_checks

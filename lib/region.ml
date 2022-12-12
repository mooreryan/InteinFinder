open! Core
module C = Coord

(* These should all be canonical. The constructor assures this...so need to make
   the type private eventually. The btab record should be canonical when it
   comes in. Probably should check or assert that though. *)

[@@@coverage off]

type t =
  {start: C.one_raw; end_: C.one_raw; index: Zero_indexed_int.t; query: string}
[@@deriving fields, sexp_of]

[@@@coverage on]

let canonicalize t =
  if C.(t.start > t.end_) then {t with start= t.end_; end_= t.start} else t

(* Displays the index as 1-indexed. *)
let to_string' :
    t -> query_new_name_to_old_name:string Map.M(String).t -> string option =
 fun t ~query_new_name_to_old_name ->
  let start = C.to_one_indexed_string t.start in
  let end_ = C.to_one_indexed_string t.end_ in
  let region_index = Zero_indexed_int.to_one_indexed_string t.index in
  let%map.Option query = Map.find query_new_name_to_old_name t.query in
  String.concat ~sep:"\t" [query; region_index; start; end_]

let to_string_header () =
  String.concat ~sep:"\t" ["query"; "region_index"; "start"; "end"]

let with_index t ~index = {t with index}

(* Zero-based indices. *)

(* TODO: move this in to the zero indexed int. *)
let assert_index_good index =
  let index' = Zero_indexed_int.to_zero_indexed_int index in
  if index' < 0 then Or_error.errorf "Expected index >= 0, but got %d" index'
  else Or_error.return ()

(** Fails if the caller provides a negative index. *)
let v_exn ~start ~end_ ~query ?(index = Zero_indexed_int.zero ()) () =
  Or_error.ok_exn @@ assert_index_good index ;
  canonicalize {start; end_; index; query}

(** Make a [Region.t] from the query start and stop of the btab record. *)
let of_btab_record_exn ?index r =
  let module R = Bio_io.Btab.Record.Parsed in
  let start = C.one_raw_exn r.R.qstart in
  let end_ = C.one_raw_exn r.R.qend in
  v_exn ~start ~end_ ~query:r.R.query ?index ()

let pad_start ~start:(C.One_raw start) ~padding =
  let padded_start = start - padding in
  let padded_start = if padded_start < 1 then 1 else padded_start in
  C.one_raw_exn padded_start

let pad_end ~end_:(C.One_raw end_) ~padding ~query_len =
  let padded_end = end_ + padding in
  (* These coordinates are 1-based!! *)
  let padded_end = if padded_end > query_len then query_len else padded_end in
  C.one_raw_exn padded_end

let clip_region {start; end_; index; query} ~padding ~query_len =
  let start = pad_start ~start ~padding in
  let end_ = pad_end ~end_ ~padding ~query_len in
  (* Use the value function here so we get the same assertions. *)
  v_exn ~start ~end_ ~index ~query

let length {start= C.One_raw start; end_= C.One_raw end_; _} = end_ - start + 1

(* "Position" that is dead center of the region. See tests for the spec, but
   [1,1] would be 1, [1,2] would be 1.5, [1,3] would be 2, etc. *)
let center t =
  let l = length t + 1 in
  Float.(of_int l /. 2.0)

(** [contains this other] returns true if [other] is contained within [this], or
    if [other = this]. *)
let contains ~this ~other =
  C.(this.start <= other.start) && C.(other.end_ <= this.end_)

(** If the start of this region is beyond the stop of the previous region, then
    you need to start a new region. Note that an end of 19 and new start of 20
    will NOT start a new region. Because we are talking about blast hits...we
    want to merge regions that butt up against one another. *)
let needs_new_region ~this_record ~current_region =
  let module R = Bio_io.Btab.Record.Parsed in
  (* Clamp it because you can have a start of 1, and 1 - 1 goes beyond the
     allowable range. But that case will be false so the logic is still fine. *)
  C.(current_region.end_ < one_raw_clamped (this_record.R.qstart - 1))

(* Note, this assumes that the inputs are sorted properly. *)
let needs_extending ~this_record ~current_region =
  let module R = Bio_io.Btab.Record.Parsed in
  (* use _exn here as if the record has a bad coordinate, then its a bug that
     the caller should have dealt with before. *)
  C.(current_region.end_ < one_raw_exn this_record.R.qend)

let extend_region ~this_record ~current_region =
  let module R = Bio_io.Btab.Record.Parsed in
  (* Records should have valid coords, so use _exn. The caller should manage
     this. *)
  {current_region with end_= C.one_raw_exn this_record.R.qend}

let update_regions regions this_record =
  match regions with
  | current_region :: previous_regions ->
      (* The start can NEVER be before the start of the last added region. (If
         you call the sort first.) *)
      assert (
        C.(
          current_region.start
          <= one_raw_exn this_record.Bio_io.Btab.Record.Parsed.qstart ) ) ;
      if needs_new_region ~this_record ~current_region then
        of_btab_record_exn this_record :: current_region :: previous_regions
      else if needs_extending ~this_record ~current_region then
        extend_region ~this_record ~current_region :: previous_regions
      else
        (* This hit doesn't extend the current region or define a new one. *)
        current_region :: previous_regions
  | [] ->
      Utils.impossible "regions list should not be empty here" [@coverage off]

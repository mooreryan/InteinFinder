open! Core

module Fasta = struct
  module Record = struct
    include Bio_io.Fasta.Record

    [@@@coverage off]

    type query_aln = Query_aln of t [@@deriving sexp_of]

    type query_raw = Query_raw of t [@@deriving sexp_of]

    type clipped_query_aln = Clipped_query_aln of t [@@deriving sexp_of]

    type clipped_query_raw = Clipped_query_raw of t [@@deriving sexp_of]

    type intein_aln = Intein_aln of t [@@deriving sexp_of]

    type intein_raw = Intein_raw of t [@@deriving sexp_of]

    type query_clipped_or_intein =
      | Query of query_aln
      | Clipped_query of clipped_query_aln
      | Intein of intein_aln
    [@@deriving sexp_of]

    [@@@coverage on]

    let query_aln r = Query_aln r

    let query_raw r = Query_raw r

    let clipped_query_aln r = Clipped_query_aln r

    let clipped_query_raw r = Clipped_query_raw r

    let intein_aln r = Intein_aln r

    let intein_raw r = Intein_raw r

    let query_prefix = "IF_USER_QUERY___"

    let intein_prefix = "IF_INTEIN_DB___"

    let clipped_query_prefix = "IF_CLIPPED_QUERY___"

    let is_query_seq record = String.is_prefix (id record) ~prefix:query_prefix

    let is_clipped_query_seq record =
      String.is_prefix (id record) ~prefix:clipped_query_prefix

    let is_intein_seq record =
      String.is_prefix (id record) ~prefix:intein_prefix

    (** This also ensures that the sequence is in all uppercase. *)
    let query_clipped_or_intein_of_record record =
      let uppercase_seq = seq record |> String.uppercase in
      let record = with_seq uppercase_seq record in
      match
        (is_intein_seq record, is_clipped_query_seq record, is_query_seq record)
      with
      | true, false, false ->
          Or_error.return @@ Intein (intein_aln record)
      | false, true, false ->
          Or_error.return @@ Clipped_query (clipped_query_aln record)
      | false, false, true ->
          Or_error.return @@ Query (query_aln record)
      | false, false, false ->
          Or_error.errorf
            "The record (%s) was not an intein, query, or clipped query."
            (id record)
      | _ ->
          (* If you get here, it is a programmar error, as this should only be
             called with valid data. *)
          invalid_argf
            "The record (%s) looks like more than one of intein, query, or \
             clipped query. Should be impossible."
            (id record)
            () [@coverage off]
  end
end

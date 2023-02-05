open! Core

module T = struct
  [@@@coverage off]

  (* Read: "with respect to" *)
  type aln = Aln [@@deriving sexp_of]

  type raw = Raw [@@deriving sexp_of]

  (* Read: "indexing" *)
  type one = One [@@deriving sexp_of]

  type zero = Zero [@@deriving sexp_of]

  (* Just don't create these by hand! It will become private type when I'm
     done. *)
  type ('idx, 'wrt) t =
    | Zero_raw : int -> (zero, raw) t
    | Zero_aln : int -> (zero, aln) t
    | One_raw : int -> (one, raw) t
    | One_aln : int -> (one, aln) t
  [@@deriving sexp_of]

  (* Shorthand aliases *)
  type zero_raw = (zero, raw) t [@@deriving sexp_of]

  type zero_aln = (zero, aln) t [@@deriving sexp_of]

  type one_raw = (one, raw) t [@@deriving sexp_of]

  type one_aln = (one, aln) t [@@deriving sexp_of]

  [@@@coverage on]
end

include T

let zero_min = 0

let one_min = 1

let zero_raw x = if x < zero_min then None else Some (Zero_raw x)

let zero_aln x = if x < zero_min then None else Some (Zero_aln x)

let one_raw x = if x < one_min then None else Some (One_raw x)

let one_aln x = if x < one_min then None else Some (One_aln x)

let zero_raw_exn x =
  Option.value_exn ~error:(Error.createf "Coord.zero_raw_exn failed (%d)" x)
  @@ zero_raw x

let zero_aln_exn x =
  Option.value_exn ~error:(Error.createf "Coord.zero_aln_exn failed (%d)" x)
  @@ zero_aln x

let one_raw_exn x =
  Option.value_exn ~error:(Error.createf "Coord.one_raw_exn failed (%d)" x)
  @@ one_raw x

let one_aln_exn x =
  Option.value_exn ~error:(Error.createf "Coord.one_aln_exn failed (%d)" x)
  @@ one_aln x

let zero_raw_clamped x = if x < zero_min then Zero_raw zero_min else Zero_raw x

let zero_aln_clamped x = if x < zero_min then Zero_aln zero_min else Zero_aln x

let one_raw_clamped x = if x < one_min then One_raw one_min else One_raw x

let one_aln_clamped x = if x < one_min then One_aln one_min else One_aln x

let btab_qstart r = one_raw_exn @@ Bio_io.Btab.Record.qstart r

let btab_qend r = one_raw_exn @@ Bio_io.Btab.Record.qend r

let to_int : type idx wrt. (idx, wrt) t -> int = function
  | Zero_raw x | Zero_aln x | One_raw x | One_aln x ->
      x

let to_float : type idx wrt. (idx, wrt) t -> float =
 fun t -> Float.of_int @@ to_int t

let zero_to_one : type wrt. (zero, wrt) t -> (one, wrt) t = function
  | Zero_raw x ->
      One_raw (x + 1)
  | Zero_aln x ->
      One_aln (x + 1)

let one_to_zero : type wrt. (one, wrt) t -> (zero, wrt) t = function
  | One_raw x ->
      Zero_raw (x - 1)
  | One_aln x ->
      Zero_aln (x - 1)

let to_zero_indexed_int : type idx wrt. (idx, wrt) t -> int = function
  | Zero_raw _ as x ->
      to_int x
  | Zero_aln _ as x ->
      to_int x
  | One_raw _ as x ->
      one_to_zero x |> to_int
  | One_aln _ as x ->
      one_to_zero x |> to_int

let to_one_indexed_int : type idx wrt. (idx, wrt) t -> int = function
  | Zero_raw _ as x ->
      x |> zero_to_one |> to_int
  | Zero_aln _ as x ->
      x |> zero_to_one |> to_int
  | One_raw _ as x ->
      x |> to_int
  | One_aln _ as x ->
      x |> to_int

let to_one_indexed_string : type idx wrt. (idx, wrt) t -> string =
 fun t -> t |> to_one_indexed_int |> Int.to_string

(* You can compare positions that have different indexing. They are converted to
   the same indexing internally and then compared. *)

let rec ( = ) : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> bool =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let ( =* ) : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> bool =
   fun x y -> x = y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(x = y)
  | Zero_raw x, Zero_raw y ->
      Int.(x = y)
  | One_aln x, One_aln y ->
      Int.(x = y)
  | Zero_aln x, Zero_aln y ->
      Int.(x = y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      x =* zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      x =* one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      x =* zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      x =* one_to_zero y

let equal = ( = )

let rec compare : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> int =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let compare' : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> int =
   fun x y -> compare x y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(compare x y)
  | Zero_raw x, Zero_raw y ->
      Int.(compare x y)
  | One_aln x, One_aln y ->
      Int.(compare x y)
  | Zero_aln x, Zero_aln y ->
      Int.(compare x y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      compare' x @@ zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      compare' x @@ one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      compare' x @@ zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      compare' x @@ one_to_zero y

(* Need this for tests. *)
let compare_zero_aln : zero_aln -> zero_aln -> int = compare

let rec ( > ) : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> bool =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let ( >* ) : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> bool =
   fun x y -> x > y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(x > y)
  | Zero_raw x, Zero_raw y ->
      Int.(x > y)
  | One_aln x, One_aln y ->
      Int.(x > y)
  | Zero_aln x, Zero_aln y ->
      Int.(x > y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      x >* zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      x >* one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      x >* zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      x >* one_to_zero y

let rec ( >= ) : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> bool =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let ( >=* ) : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> bool =
   fun x y -> x >= y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(x >= y)
  | Zero_raw x, Zero_raw y ->
      Int.(x >= y)
  | One_aln x, One_aln y ->
      Int.(x >= y)
  | Zero_aln x, Zero_aln y ->
      Int.(x >= y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      x >=* zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      x >=* one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      x >=* zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      x >=* one_to_zero y

let rec ( < ) : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> bool =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let ( <* ) : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> bool =
   fun x y -> x < y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(x < y)
  | Zero_raw x, Zero_raw y ->
      Int.(x < y)
  | One_aln x, One_aln y ->
      Int.(x < y)
  | Zero_aln x, Zero_aln y ->
      Int.(x < y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      x <* zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      x <* one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      x <* zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      x <* one_to_zero y

let rec ( <= ) : type idx1 idx2 wrt. (idx1, wrt) t -> (idx2, wrt) t -> bool =
 fun x y ->
  (* So you don't mess up the flips below! *)
  let ( <=* ) : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> bool =
   fun x y -> x <= y
  in
  match (x, y) with
  | One_raw x, One_raw y ->
      Int.(x <= y)
  | Zero_raw x, Zero_raw y ->
      Int.(x <= y)
  | One_aln x, One_aln y ->
      Int.(x <= y)
  | Zero_aln x, Zero_aln y ->
      Int.(x <= y)
  (* Flips! *)
  | (One_raw _ as x), (Zero_raw _ as y) ->
      x <=* zero_to_one y
  | (Zero_raw _ as x), (One_raw _ as y) ->
      x <=* one_to_zero y
  | (One_aln _ as x), (Zero_aln _ as y) ->
      x <=* zero_to_one y
  | (Zero_aln _ as x), (One_aln _ as y) ->
      x <=* one_to_zero y

(* Position is closed over addition, so no need to check return values. *)
let add : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> (idx, wrt) t =
 fun x y ->
  match (x, y) with
  | One_raw x, One_raw y ->
      One_raw (x + y)
  | Zero_raw x, Zero_raw y ->
      Zero_raw (x + y)
  | One_aln x, One_aln y ->
      One_aln (x + y)
  | Zero_aln x, Zero_aln y ->
      Zero_aln (x + y)

(* Adding raw int does require checking though OR asserting that the other
   number is positive. We do the assert. *)
let add' : type idx wrt. (idx, wrt) t -> int -> (idx, wrt) t =
 fun t i ->
  assert (Int.(i >= 0)) ;
  match t with
  | Zero_raw x ->
      Zero_raw (x + i)
  | Zero_aln x ->
      Zero_aln (x + i)
  | One_raw x ->
      One_raw (x + i)
  | One_aln x ->
      One_aln (x + i)

let add'' : type idx wrt. int -> (idx, wrt) t -> (idx, wrt) t =
 fun i t ->
  assert (Int.(i >= 0)) ;
  match t with
  | Zero_raw x ->
      Zero_raw (x + i)
  | Zero_aln x ->
      Zero_aln (x + i)
  | One_raw x ->
      One_raw (x + i)
  | One_aln x ->
      One_aln (x + i)

let sub : type idx wrt. (idx, wrt) t -> (idx, wrt) t -> (idx, wrt) t option =
 fun x y ->
  match (x, y) with
  | One_raw x, One_raw y ->
      one_raw (x - y)
  | Zero_raw x, Zero_raw y ->
      zero_raw (x - y)
  | One_aln x, One_aln y ->
      one_aln (x - y)
  | Zero_aln x, Zero_aln y ->
      zero_aln (x - y)

let sub' : type idx wrt. (idx, wrt) t -> int -> (idx, wrt) t option =
 fun t i ->
  match t with
  | Zero_raw x ->
      zero_raw (x - i)
  | Zero_aln x ->
      zero_aln (x - i)
  | One_raw x ->
      one_raw (x - i)
  | One_aln x ->
      one_aln (x - i)

let incr t = add' t 1

let decr t = sub' t 1

let decr_exn t =
  match sub' t 1 with
  | None ->
      failwithf "decr failed with %s" (to_int t |> Int.to_string) ()
  | Some x ->
      x

(** Maps the Query alignment columns to the raw positions. *)
module Query_aln_to_raw : sig
  module Key : sig
    type t = zero_aln [@@deriving sexp_of]
  end

  module Value : sig
    (** Here's what this does...
        [|
     query : --X-X-X--
    intein : YY--YY-YY
    before : ^^
        at :   ^ ^ ^
   between :     ^
     after :        ^^
  |] *)
    type t =
      | Before
      | At of zero_raw
      | Between of (zero_raw option * zero_raw option)
      | After
    [@@deriving sexp_of]

    val sub : t -> t -> int option

    val length : start:t -> end_:t -> int option

    val to_string : t -> string
  end

  type t [@@deriving sexp_of]

  val empty : t

  val add_exn : t -> key:Key.t -> data:Value.t -> t

  val find_exn : t -> Key.t -> Value.t
end = struct
  include Int.Map

  module Key = struct
    [@@@coverage off]

    type t = zero_aln [@@deriving sexp_of]

    [@@@coverage on]
  end

  module Value = struct
    [@@@coverage off]

    type t =
      | Before
      | At of zero_raw
      | Between of (zero_raw option * zero_raw option)
      | After
    [@@deriving sexp_of]

    [@@@coverage on]

    let sub a b =
      (* NOTE: technically you COULD subtract Betweens, but it would be a bit
         weird, so we don't allow it. *)
      match (a, b) with At x, At y -> Some (to_int x - to_int y) | _ -> None

    (** [length ~start ~end_] returns the length on a sequences where [start]
        and [end_] are both inclusive. *)
    let length ~start ~end_ =
      let%map.Option y = sub end_ start in
      y + 1

    let to_string = function
      | Before ->
          "Before"
      | At x ->
          [%string "At %{to_one_indexed_string x}"]
      | Between (x, y) ->
          let x' =
            match x with None -> "None" | Some x -> to_one_indexed_string x
          in
          let y' =
            match y with None -> "None" | Some y -> to_one_indexed_string y
          in
          [%string "Between (%{x'}, %{y'}"]
      | After ->
          "After"
  end

  [@@@coverage off]

  type t = Value.t Int.Map.t [@@deriving sexp_of]

  [@@@coverage on]

  let add_exn m ~key ~data = Int.Map.add_exn m ~key:(to_int key) ~data

  let find_exn m key = Int.Map.find_exn m (to_int key)
end

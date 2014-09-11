let rec fprintf_list ~sep f fmt = function
  | []   -> ()
  | [e]  -> f fmt e
  | x::r -> Format.fprintf fmt "%a%(%)%a" f x sep (fprintf_list ~sep f) r


module type MONOMIAL_BASIS =
sig
  val dim: int (* nb of variables *)
  type t (* A monomial *)

  val nth: int -> t (* Returns the n-th monomial of the basis over dim variables . Starts at 0. *)
  val get_id: t -> int (* Return the idx of the monomials in the basis *)
  (* We should have nth (get_id x) = x and get_id (nth x) = x *)
    
    
  val fprintf: Format.formatter -> t -> string array -> unit
(* TODO: add functions to 
   - obtain the classical rep of each monomial
   - compute the product of monomials   
*)
end



module type LINEXPR = 
sig
  (* type base_t *)
  type expr
  val sos : expr
 
end


module ClassicalMonomialBasis =
  functor (Dim: sig val dim: int end) ->
struct
  let dim = Dim.dim

  type t = int array (* array of size: dim + 1 *)

  let gen_base deg =

(* A base is precomputed for a degree up to  *)
  let base = ref []

  let fprintf fmt monomial names = 
    assert (Array.length names = Array.length monomial);
    (*Format.fprintf fmt "[%a]" (fprintf_list ~sep:"; " Format.pp_print_int) (Array.to_list monomial)*)
    if Array.fold_left (fun accu pow -> accu && pow = 0) true monomial then
      Format.fprintf fmt "1"
    else
      List.iter2 (fun pow name -> 
	if pow > 0 then
	  if pow > 1 then
	    Format.fprintf fmt "%s^%i" name pow
	  else
	    Format.pp_print_string fmt name
	else 
	  () ) (Array.to_list monomial) (Array.to_list names)


end

module Ident =
struct
  type t = int
  let cpt = ref 0
  let create () = incr cpt; !cpt
  let fprintf fmt = Format.fprintf fmt "P%i"
end

(* Linear Polynomial Expression:
   define polynomial expressions, linear in their (polynomial) variables
*)
module LinPolyExpr =
  functor (M: MONOMIAL_BASIS) ->
struct
  
  (* [(a1, [|v1;v2;v3|]); (a12 [|v'1;v'2;v'3|])] denotes the polynomial
     a1*x^v1*y^v2* z^v3 + a2*x^v1'* y^v2'* z^v3' *)
  type scalar_t = (float * M.t) list  
    

  type expr = | Var of id * int    (* Var(id, n) : Polynomial variable id of degree n *)
	    | Scalar of scalar_t (* Polynomial with known coefficients *)
	    | Add of expr * expr 
	    | Sub of expr * expr
	    | ScalMul of Scalar * expr

  (* We bind a new polynomial variable. 
     new_sos_var "foo" 3 returns (id, build, sdp_vars): Ident.t * (float list -> scalar_t) * LMI.Sig.matrix_expr
     We create a new id, and provide two functions: one to 
  *)
  let new_sos_var name deg =
    let id = Ident.create () in
    


  let sos expr = 
end


(* Tests *)
module MonBase3 = ClassicalMonomialBasis(struct let dim = 3 end)
let nth = MonBase3.nth

let _ =
  List.iter 
    (fun el -> 
      MonBase3.fprintf Format.std_formatter el [|"x";"y";"z"|];
    Format.pp_print_newline Format.std_formatter ()
    ) (List.map nth [0;1;2;3;4;5;6;7;8;9;10])
(*
module LinearPolynomialExpr =
  functor (MonomialBase: sig
    type t 
    val int -> t
  end ->
struct
  type base_t = polynome de deg d sur un ensemble de variable V et une base de monome B de degre au plus d
degre d'un monome

  type expr = 
  | Const of base_t
  | ConstMult of base_t * expr
  | Add of expr * expr
  | Sub of expr * expr

  let const =      
    
end
*)


(* OLD 
  (* Compute the number of monomials of degree = d with v variables *)
  let rec nb_mon_of_fix_deg v d =
    match v,d  with
    | 1, _ -> 1
    | _, 1 -> v
    | _ -> nb_mon_of_fix_deg (v-1) d + nb_mon_of_fix_deg v (d-1)

  let nth k = 
    let new_array = Array.make (dim) 0 in
    let rec aux k deg max = 
      if k < max then (
	Format.printf "%i-th vecteur of deg %i@." k deg;
	(*Array.set new_array k 1*)()
      )
      else (* k >= accu *)
	aux (k-max) (deg+1) (nb_mon_of_fix_deg dim (deg+1))
    in
    if k > 0 then
      aux (k-1) 1 dim;
    new_array   


*)

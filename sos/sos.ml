(*
Take a list of expressions that have to be SOS
Each  expression is expressed over sos_unknown of fixed degree in a provided monomial basis
It returns
- a set of sdp vars
- a list of constraints of those
- a list of mapping from sdp vars to SOS

each sos unknown is expressed as a SOS over the monomial basis. 
on deplie les equations sUr nos variables SOS : base^t P base 
et on reconstruit une version SOS sur la base

on a besoin pour ca de structures de donnee efficaces pour 
- etant donne un monome, savoir l'exprimer dans la base SOS, par ex. comme expression des variables sdp: monome en x = 2*b, donc si on cree le monome avec le coeff 2: 2*x, on doit avoir b = 1
- etant donne deux expressions, calculer le produit des deux: savoir efficace le deplier en monomes et reidentifier les variables sdp associées.
- si la base en exotique, ca peut demander de renormaliser pour retomber dans la base

it requires a hashtbl from monomial to set of indices ...
*)
module Ident = LMI.Ident

exception Incompatible_dim

let sos_to_sdp expressions vars degree basis = ()


(*
dans une matrice M sym matrix of dim n *n, appliqué à une base monomiale B^n
le coeff associé au monome x_a * x_b où x_a,x_b \in B^n
est:
si exist x_c \in B^n et k \in [1,n], tq x_a * x_b = x_c^k
alors coeff(x_a * x_b] = [M()
*)



(*
on a deux polynome

*)
open Monomials
module C = ClassicalMonomialBasis 
module H = HermiteS 

module Vars = LinearExpr.Vars
module VN = LinearExpr.VN
module VNConstraints = Constraints

module CN = LinearExpr.MakeLE (LinearExpr.N) (struct include C module Set= Set.Make(C) end)
module CVN = LinearExpr.MakeLE (VN) (struct include C module Set= Set.Make(C) end)

(* Type of expressions: it should be linear in SOSVar, SDPVar, PolyVar *)
type expr = | Var of Vars.t 
    (*SOSVar of Ident.t * int (* SOSVar(id, d) : Positive Polynomial variable 
					 id of degree d *)
	    | PolyVar of Ident.t * int 
	    | SDPVar of LMI.Num_mat.var
    *)
	    | Scalar of CN.t (* Polynomial with known coefficients, no free (sdp) vars *)
	    | Add of expr * expr 
	    | Sub of expr * expr
	    | ScalMul of CN.t * expr

let (+%) x y = Add(x,y)  
let (-%) x y = Sub(x,y)  
let ( *% ) x y = ScalMul(x,y)  
let (?%) x = Scalar x
let (!%) x = Var x

module Make = functor (M: MONOMIAL_BASIS) ->
struct
  module M = M

  (*******************************************************************************)
  (*                                                                             *)
  (*                                                                             *)
  (*                                                                             *)
  (*                                                                             *)
  (*                                                                             *)
  (*                                                                             *)
  (*******************************************************************************)
  module MVN = LinearExpr.MakeLE (VN) (struct include M module Set= Set.Make(M) end)
  module CMVN = LinearExpr.MakeLE (MVN) (struct include C module Set= Set.Make(C) end)



(*
(* Polynomial in C *)
type CN.t = (N.t * C.t) list
    
(* Polynomials in the classical basis with scalar in LEVarsNum *)
type CVN.t = (LEV.t_levarsnum * C.t) list


let pp_cvn ?(names=None) = pp_xvn (C.fprintf ~names:names)

  (* Polynomials in base M with scalar in LEVarsNum *)
  (* module MVN = PolyLinExpr (LEVarsNum) (M) *)
  type MVN.t = (LEV.t_levarsnum * M.t) list 

  let pp_mvn ?(names=None) = pp_xvn (M.fprintf ~names:names)
    
  (* Polynomials in the classical basis with scalar in MVN *)
  (* module CMVN = PolyLinExpr (MVN) (C)  *)
  type CMVN.t = (MVN.t * C.t) list


  let MVN.add l1 l2 = 
    let res = merge_sorted_lists (cmp M.cmp) (add VN.is_zero VN.add) l1 l2 in
    (* Format.eprintf "Merging l1 with l2@.l1 = %a@.l2=%a@.ress=%a@.@?" *)
    (*   (pp_mvn ~names:None) l1 (pp_mvn ~names:None) l2 (pp_mvn ~names:None) res; *)
    res

  let cvn_add = merge_sorted_lists (cmp C.cmp) (add VN.is_zero VN.add) 
*)    






   (*******************************************************************************)
   (*                                                                             *)
   (*                                                                             *)
   (*                                                                             *)
   (*                                                                             *)
   (*                                                                             *)
   (*                                                                             *)
   (*******************************************************************************)

   (* Hash table to store the computed generated sos variables *)
let hash_sosvars : 
    (Ident.t, 
     int *
       LMI.Num_mat.var list * 
       (LMI.Num_mat.Mat.elt list -> LMI.Num_mat.Mat.t) * 
       LMI.Num_mat.matrix_expr *
       MVN.t
    ) Hashtbl.t  
    = Hashtbl.create 13

let hash_polyvars = Hashtbl.create 13

   (* copy of LMI.sym_mat_of_var *)
let pp_sos dim fmt (vl:LMI.Num_mat.var list) = 
  let expected_length = (dim*dim + dim)/2 in
  if List.length vl != expected_length then
    raise (Failure ("Invalid input list for pp_sos: expecting " 
		    ^ string_of_int expected_length ^ ", we have " 
		    ^ string_of_int (List.length vl)));
  let new_mat = Array.make_matrix dim dim (None) in
  let i = ref 0 and j = ref 0 in
  List.iter (fun elem -> 
       (* Report.debugf ~kind:"sdp" 
	  (fun fmt -> "%i, %i@.@?" !i !j); *)
    if !i > dim then assert false;
    (if !i = !j then
	new_mat.(!i).(!j) <- Some elem
     else
	(new_mat.(!i).(!j) <- Some elem;
	 new_mat.(!j).(!i) <- Some elem)
    );
       (* Incrementing i and j *)
    if !j = dim-1 then
      (incr i; j := !i)
    else
      (incr j)
  ) vl;
  Format.fprintf fmt "@[<v>[";
  Array.iter (fun m -> Format.fprintf fmt "@[<h>%t@]@ "
    (fun fmt -> Array.iter (fun v -> match v with None -> Format.fprintf fmt "0@ 
" | Some v -> Format.fprintf fmt "%a@ " LMI.Num_mat.pp_var v) m)
  ) new_mat;
  Format.fprintf fmt "@ ]@]"




    (* Vieille explication: 
       We bind a new polynomial variable.  new_sos_var
       "foo" 3 returns (id, build, sdp_vars): Ident.t * (BT.t list -> scalar_t)
       * LMI.Sig.matrix_expr

       id is a new identifier

       build is a map from a list of BT.t to the polynomial representation

       sdp_vars is the sdp matrix
    *)
    
let new_sos_var name dim deg : Ident.t * Vars.t =
  let id = Ident.create name in
  let deg_monomials = M.get_sos_base_size dim deg in
  Format.eprintf "nb element base monomiale: %i@." deg_monomials;
  let vars = LMI.Num_mat.vars_of_sym_mat id deg_monomials in
  Format.eprintf "nb vars: %i@." (List.length vars);
  let expr : MVN.t = 
    List.fold_left  
      (fun res v -> 
	MVN.add res 
	  (match LMI.Num_mat.get_var_indices v with 
	  | Some (i, j) -> 
	    let v = Vars.SDPVar v in
	    let monomials: M.LE.t = 
	      try M.prod (M.nth dim i) (M.nth dim j) with Failure _ -> assert false 
	    in
	    MVN.inject (List.map
	      (fun (coeff, m) -> 
		if i = j then
		  VN.inject [coeff, v],m 
		else (* todo utiliser plutot les fonctions du modules pour mult et of_int*)
		  (VN.inject [LinearExpr.N.mult (LinearExpr.N.of_int 2) coeff, v], m)
	      ) 
	      monomials)
	  | _ -> assert false)
	  
      ) MVN.zero vars 
  in
  let build_poly elems = LMI.Num_mat.sym_mat_of_var deg_monomials elems in
  let unknown_sdp = LMI.Num_mat.symmat (id, deg_monomials) in
  Hashtbl.add hash_sosvars id (deg_monomials, vars, build_poly, unknown_sdp, expr);
  id, Vars.SOSVar(id, deg)
    
let get_sos_dim  id = match Hashtbl.find hash_sosvars id with a, _, _, _, _ -> a
let get_sos_vars id = match Hashtbl.find hash_sosvars id with _, a, _, _, _ -> a
let get_sos_mat  id = match Hashtbl.find hash_sosvars id with _, _, a, _, _ -> a
let get_sos_var  id = match Hashtbl.find hash_sosvars id with _, _, _, a, _ -> a
let get_sos_expr id = match Hashtbl.find hash_sosvars id with _, _, _, _, a -> a


let new_poly_var name dim deg =
  let id = Ident.create name in
  let monomials = M.get_monomials dim deg in
  let vars = List.mapi (fun idx _ -> LMI.Var (id, idx, 0)) monomials in
  let expr : MVN.t = 
    MVN.inject 
      (List.map2 (fun v m -> (VN.inject [LinearExpr.N.of_int 1, Vars.SDPVar v], m)) vars monomials) 
  in
  Hashtbl.add hash_polyvars id (deg, vars, expr);
  id, Vars.PolyVar (id, deg)

let get_poly_deg id  = match Hashtbl.find hash_polyvars id with  a, _, _ -> a
let get_poly_vars id = match Hashtbl.find hash_polyvars id with  _, a, _ -> a
let get_poly_expr id =  match Hashtbl.find hash_polyvars id with _, _, a -> a
  
    (*******************************************************************************)
    (*                                                                             *)
    (*                                                                             *)
    (*                                                                             *)
    (*                                                                             *)
    (*                                                                             *)
    (*                                                                             *)
    (*******************************************************************************)
  

    (* STEP 1: parse the expression and return a cvn polynomial.  *)
let rec simplify dim expr : CVN.t =
  let zero_c dim = Array.make dim 0 in
  match expr with
  | Var (Vars.Cst) -> assert false
  | Var (Vars.SOSVar (v, d))  -> CVN.inject [VN.inject [LinearExpr.N.of_int 1,  Vars.SOSVar (v, d)] , zero_c dim]
  | Var(Vars.SDPVar v) -> CVN.inject [VN.inject [LinearExpr.N.of_int 1,  Vars.SDPVar v] , zero_c dim]
  | Scalar s -> CVN.inject (CN.map (fun (n,m) -> VN.inject [n, Vars.Cst] ,m) s) (* Constant polynomial in C *)
  | Var(Vars.PolyVar (v,d)) -> CVN.inject [VN.inject [LinearExpr.N.of_int 1,  Vars.PolyVar (v, d)] , zero_c dim]
  | Add (e1, e2) -> CVN.add (simplify dim e1) (simplify dim e2)

  | Sub (e1, e2) -> 
    let minus_one_poly : CN.t = CN.inject [LinearExpr.N.of_int (-1), zero_c dim] in
    let minus_e2 = ScalMul(minus_one_poly, e2) in
    simplify dim (Add (e1, minus_e2))

  | ScalMul (s,e) ->
    List.fold_left  (
      fun res (le, m) ->
	if C.dim m <> dim then raise Incompatible_dim;
	List.fold_left (
	  fun res' (n1,m') ->
	    if C.dim m' <> dim then raise Incompatible_dim;
	    let prod_m_m' = C.prod m m' in
	    CVN.add res' (CVN.inject (List.map (fun (n2,m) -> 
	      let le' = VN.ext_mult (LinearExpr.N.mult n1 n2) le in
	      le', m) prod_m_m'))
	) res (CN.extract s) 
    ) CVN.zero (CVN.extract (simplify dim e))


    (*   STEP 2: convert a cvn into a mvn:

	 CVN -> CMVN -- chaque variable est remplacée par un polynome en M
	 - les scalaires s par s * M(0)
	 - les variables polynomiales par un element de MVN
	 
	 CMVN -> MVN -- on deplie les equations et on recaster en base M
    *)
let unfold_poly dim cvn =
  let cst_monomial_M = try M.nth dim 0 with Failure _ -> assert false in
  let cmvn : CMVN.t = CMVN.inject (
    CVN.map ( 
      fun (s,m) -> (* s: linear expr over vars (VN) , m: a classical monomial (C) *)
	let s_mvn : MVN.t = (* s expressed in base M  *)
	  List.fold_right (
	    fun (n,v) res' -> (* n a numerical coeff and v a (SDP/SOS/Poly) variable *)
	      let v_mvn = (* = ( (c * v) * {base M} ) *)
		match v with
		| Vars.SDPVar _ -> (* M.nth 0 : the constant monomial : 1 *)
		  MVN.inject [VN.inject [n, v], cst_monomial_M]
		| Vars.PolyVar (id, d) -> 
		  let mvn_v = get_poly_expr id in
		  MVN.ext_mult n mvn_v
		| Vars.Cst -> MVN.inject[VN.inject[n, Vars.Cst], cst_monomial_M]
		| Vars.SOSVar (id, d) -> 
		  let mvn_v = get_sos_expr id in
		  MVN.ext_mult n mvn_v
	      in
	      MVN.add v_mvn res'
	  ) (VN.extract s) MVN.zero 
	in
	s_mvn, m
    ) cvn
  )
  in
 
  let mvn, degree = 
    List.fold_right  (
      fun (s, mc) (res, deg) -> 
	List.fold_right (
	  fun (expr_v, mm) (res', deg) -> 
	    let m_expr = M.var_prod mc mm in
	    let new_term, deg' = 
	      List.fold_right (
		fun (c,m) (accu,deg) -> 
		  (VN.ext_mult c expr_v, m)::accu, max deg (M.deg m)) 
		m_expr ([], deg)
	    in
	    MVN.add res' (MVN.inject new_term) , deg'
	) (MVN.extract s) (res, deg) 
    ) (CMVN.extract cmvn) (MVN.zero, 0) 
  in

  mvn, degree


    (* TODO 
       each time we introduce (x,[])
       if x is a singleton (coeff, var) we store that var = 0
       and we simplify accu: every occurence of var is replaced by 0. If we obtain a new var = 0, this is removed from accu and stored in the zero table.

       if it is more complex, x is simplidied using the list of zero vars and store into accu
    *)
let sos ?(names=None) dim id expr =

  let rec build_constraints mvn1 mvn2 =
    match mvn1, mvn2 with
    | [], [] -> ()
    | (_::_ as l), []
    | [], (_::_ as l) -> List.iter (fun (c,_) -> VNConstraints.add_cons c VN.zero) l
    | (c1, m1)::tl1, (c2, m2)::tl2 -> (
      let order = M.compare m1 m2 in
	  (* Format.eprintf "Comparing %a with %a: %i@." (M.fprintf names) m1 (M.fprintf names) m2 order; *)
      if order = 0 then (
	    (* Format.eprintf "%a = %a@." *)
	    (*   pp_levarsnum c1 pp_levarsnum c2; *)
	VNConstraints.add_cons c1 c2;
	build_constraints tl1 tl2
      )
      else if order < 0 then (* m1 < m2 *) (
	VNConstraints.add_cons c1 VN.zero;
	build_constraints tl1 mvn2 
      )
      else (
	VNConstraints.add_cons c2 VN.zero;
	build_constraints mvn1 tl2 
      )
    )
  in
  let _ = 
    match names with 
    | Some a -> if dim <> Array.length a then assert false
    | _ -> ()
  in
  
  let cvn = simplify dim expr in 
      (* Format.eprintf "cvn = %a@." (pp_cvn ~names:names) cvn; *)
  let mvn, degree = unfold_poly dim cvn in
      (* Format.eprintf "d(mvn)=%i, mvn = %a@." degree (pp_mvn ~names:names) mvn; *)
  Format.eprintf "new sos var: deg=%i, dim=%i@." degree dim;
  let sos_var, sos_id_expr = new_sos_var id dim degree in
  let sos_expr : MVN.t = get_sos_expr sos_var in
      (* Format.eprintf "sos expr mvn = %a@." (pp_mvn ~names:names) sos_expr; *)
  let _ = build_constraints (MVN.extract mvn) (MVN.extract sos_expr) in
  let constraints = VNConstraints.get_cons () in
      (* List.iter (fun c ->  *)
      (* 	Format.printf "%a = 0@." pp_levarsnum c *)
      (* ) constraints; *)
  sos_var, sos_id_expr, constraints

end

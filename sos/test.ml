open Monomials
open LinearExpr

module C = ClassicalMonomialBasis 
module H = HermiteMonomialBasis 

    
 



module Test =
  functor (M: MONOMIAL_BASIS) ->
struct
let _ =
  
let nb_vars = 3 in 
let deg = 10 in
let nb_mon = M.get_sos_base_size nb_vars deg in

Format.printf "nb monomials: %i@.@?" nb_mon;
let rec aux n accu = 
  if n > 0 then
    aux (n-1) ((M.nth nb_vars (n-1))::accu)
  else 
    accu
in
let base = aux nb_mon [] in
Format.printf "Base monomiale SOS en dimension %i de degré %i:@.@[<h>%a@]@."
  nb_vars 
  deg
  (Utils.fprintf_list ~sep:",@," (M.fprintf ~names:None)) base;

Format.printf "Computing products of monomials@.";
let rec aux l1 l2 =
match l1, l2 with
| hd1::tl1, hd2::tl2 ->
  List.iter (fun m2 -> 
    let res = M.prod hd1 m2 in
    Format.printf "%a * %a = %a@."
      (M.fprintf ~names:None) hd1
      (M.fprintf ~names:None) m2
      (M.LE.fprintf ~names:None) res;
    ()
      
  ) l2;
  aux tl1 tl2
| [], [] -> 
  ()
| _ -> assert false
  ;  
  
in
aux base base
end






(*
let _ =
  let nb_vars = 10 in 
  let deg = 16 in
  let nb_mon = C.get_sos_deg nb_vars deg in

()

*)

(*
dule TC =  Test(C)

module TH = Test(H)
*)


module SOS = LinearExpr.Make (C)
module N = LinearExpr.N
module Vars = LinearExpr.Vars


  let x () =
  (*
    let dim = 4 in
    let sos1 = SOS.new_sos_var "p1" 4 dim in
    let sos1_dim = SOS.get_sos_dim sos1 in
    Format.printf "sos1: %a@." (SOS.pp_sos sos1_dim) (SOS.get_sos_vars sos1);

    let sos1_expr = SOSVar(sos1, dim) in

    let expr = sos1_expr in
  (* let expr = Add (sos1_expr, sos1_expr) in *) 
    let expr = ScalMul ([LinearExpr.N.of_int 2, [|0;2;1;0|]], sos1_expr) in
    
    let sos2,_ = SOS.sos dim [|"x";"y";"z";"k"|] "t" expr in
    let sos2_dim = SOS.get_sos_dim sos2 in

    Format.printf "sos2: %a" (SOS.pp_sos sos2_dim) (SOS.get_sos_vars sos2);
  *)
    let dim = 4 in
    let deg = 12 in
    let sos1 = SOS.new_sos_var "p" deg dim in
    let sos1_dim = SOS.get_sos_dim sos1 in
  (* Format.printf "sos1: %a@." (SOS.pp_sos sos1_dim) (SOS.get_sos_vars sos1); *)

    let sos1_expr = SOSVar(sos1, dim) in

    let expr = sos1_expr in
    let expr = Add (sos1_expr, sos1_expr) in 
    let expr = ScalMul ([LinearExpr.N.of_int 2, [|0;2;1;0|]], sos1_expr) in
  (*   let expr = ScalMul ([LinearExpr.N.of_int 2, [|5;3|]], sos1_expr) in*)
    
    let sos2, constraints = SOS.sos dim "t" expr in
    let sos2_dim = SOS.get_sos_dim sos2 in

    Format.printf "sos2: %a@.with constraints @[<v>%a@]@." 
      (SOS.pp_sos sos2_dim) (SOS.get_sos_vars sos2)
      (Utils.fprintf_list ~sep:"@ " (fun fmt c -> Format.printf "%a = 0" pp_levarsnum c)) constraints;
    ()

  let _ =   
    MeasuresTest.run ()

(*module X = LinearExpr.PolyScalar*)





open Minic_ast

(* Utils *)
let minimum a b c =
  min a (min b c)

(* Remarque :  
   La priorité est donnée à l'enviornement local, càd : si on a "longueur1" une var globale et "longueur2" une var locale, alors find_best_match(longueur) = longueur2
   L'ordre est donné via l'ordre de concaténation : (Env.bindings local_env)@(Env.bindings global_env)
   NB : btw, sans doute pas la meilleur chose à faire, but if it works, it works
 *)
let bindings_to_var_names local_env global_env = List.fold_left (fun acc (v,_) -> v::acc) [] (local_env@global_env)

let fun_def_to_fun_names funs_def = List.fold_left (fun acc f -> (f.name)::acc) [] funs_def

let typ_to_string t = match t with
  | Int -> "int"
  | Bool -> "bool"
  | Void -> "void"

let fun_def_to_arguments_as_string params = 
  fst (List.fold_left (fun (acc,b) (n,t) -> 
    if b then 
      (acc^(typ_to_string t)^" "^n, true)
    else 
     (acc^(typ_to_string t)^" "^n^", ", true) ) 
  ("", false) params)

(* Auto-suggestion *)

exception No_close_match


let levenshtein_distance s t =
  let m = String.length s
  and n = String.length t in
  (* for all i and j, d.(i).(j) will hold the Levenshtein distance between
     the first i characters of s and the first j characters of t *)
  let d = Array.make_matrix (m+1) (n+1) 0 in

  for i = 0 to m do
    d.(i).(0) <- i  (* the distance of any first string to an empty second string *)
  done;
  for j = 0 to n do
    d.(0).(j) <- j  (* the distance of any second string to an empty first string *)
  done;

  for j = 1 to n do
    for i = 1 to m do

      if s.[i-1] = t.[j-1] then
        d.(i).(j) <- d.(i-1).(j-1)  (* no operation required *)
      else
        d.(i).(j) <- minimum
            (d.(i-1).(j) + 1)   (* a deletion *)
            (d.(i).(j-1) + 1)   (* an insertion *)
            (d.(i-1).(j-1) + 1) (* a substitution *)
    done;
  done;

  d.(m).(n)


let find_best_match w l = 
  let best_match = List.fold_left 
  (fun (current_best_match, current_best_ldist) v -> 
    let ldist = levenshtein_distance v w in if ldist < current_best_ldist then (v,ldist) else (current_best_match, current_best_ldist)) 
  ("",100) l in
  if (snd best_match) > 2 then raise No_close_match else fst best_match

let did_u_mean v env =  
    try ("Did you mean '" ^ (find_best_match v env) ^ "' ?") with No_close_match -> (v^" : Unboud Value")
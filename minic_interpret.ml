(*

en entrée : un prog avec liste de variables globale et liste de déclaration de fonctions

étape 1 : créer un environnement de variables globales.

*)

open Minic_ast


exception ExcepSkip

type env = (string, int) Hashtbl.t


(*évaluation d'une expression :*)

let rec eval_expr e genv fenv=
	match e with
	  | Cst n -> n
    | BCst b -> if b then 1 else 0
    | Get x -> Hashtbl.find genv x
    | Add(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      v1 + v2
    | Mul(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      v1 * v2
    | Lt(e1, e2) ->
      let v1 = eval_expr e1 genv fenv in
      let v2 = eval_expr e2 genv fenv in
      if v1 < v2 then 1 else 0
    | Null(_) -> -1  (*not initialised variable*)
    | Call(f, p) -> let local_fun_env = Hashtbl.create 1024 in (*création d'un environnement local à la fonction*)
                    try List.iter2 (fun x y -> let pvalue = eval_expr x genv fenv in Hashtbl.add local_fun_env (fst y) pvalue ) p (Hashtbl.find fenv f).params; 
                    let _, _, _, e, b = exec_function_code (Hashtbl.find fenv f).code genv fenv local_fun_env in if b then e else failwith "error calculation function value"
                    with Invalid_argument(_) -> failwith ("wrong arguments in function " ^ f) 
                    | Not_found -> failwith "Error function name"

    | _ -> failwith "not implemented expr"
and exec_code i genv fenv lenv= 
  match i with
    | Set(x, e) ->
      let v = eval_code e genv fenv lenv in
      let () = print_int v in
      let () = Hashtbl.add lenv x v in 
      genv, fenv, lenv, -1, false
    | If(e, b1, b2) ->
      let v = eval_code e genv fenv lenv in
      if v = 1
      then exec_function_code b1 genv fenv lenv
      else exec_function_code b2 genv fenv lenv
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval_code e genv fenv lenv in
            if v = 0 then genv, fenv, lenv, -1, false
            else let genv', fenv, lenv, e, b = exec_function_code b genv fenv lenv in
                 if b then genv', fenv, lenv, e, b else exec_code i genv' fenv lenv
          end
        with
          | ExcepSkip ->  let genv', fenv, lenv, e, b = exec_code (While (e, b)) genv fenv lenv in
                              if b then genv', fenv, lenv, e, b else exec_code i genv' fenv lenv
          | _ -> failwith "unknown exception"
      end
    | Skip -> raise ExcepSkip
    | Putchar(e) -> let tmp = eval_code e genv fenv lenv in
                    print_int tmp; print_string "\n"; genv, fenv, lenv, -1, false
    | Return(e) -> let tmp = eval_code e genv fenv lenv in genv, fenv, lenv, tmp, true
    |_ -> failwith  "not implemented instr"

and exec_function_code b genv fenv lenv= 
  match b with
      | [] -> genv, fenv, lenv, -1, false
      | i :: b' -> let genv', fenv, lenv, e, b = exec_code i genv fenv lenv in
                   if b then genv', fenv, lenv, e, b else exec_function_code b' genv' fenv lenv
and eval_code e genv fenv lenv=
  match e with
    | Cst n -> n
    | BCst b -> if b then 1 else 0
    | Get x -> let tmp = try Hashtbl.find lenv x with  Not_found -> Hashtbl.find genv x in tmp
    | Add(e1, e2) ->
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      v1 + v2
    | Mul(e1, e2) ->
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      v1 * v2
    | Lt(e1, e2) ->
      let v1 = eval_code e1 genv fenv lenv in
      let v2 = eval_code e2 genv fenv lenv in
      if v1 < v2 then 1 else 0
    | Null(_) -> -1  (*not initialised variable*)
    | _ -> failwith "not implemented expr in recursion"








  
(*****************************************************)
(*évaluation des instruction et listes d'instructions*)
let rec execinstr i genv fenv = 
  match i with
    | Set(x, e) ->
      let v = eval_expr e genv fenv in
      let () = print_int v in
      let () = Hashtbl.add genv x v in 
      genv, fenv
    | If(e, b1, b2) ->
      let v = eval_expr e genv fenv in
      if v = 1
      then execseq b1 genv fenv
      else execseq b2 genv fenv
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval_expr e genv fenv in
            if v = 0 then genv, fenv
            else let genv', fenv = execseq b genv fenv in
                 execinstr i genv' fenv
          end
        with
          | ExcepSkip ->  let genv', fenv = execinstr (While (e, b)) genv fenv in
                              execinstr i genv' fenv
          | _ -> failwith "unknown exception"
      end
    | Skip -> raise ExcepSkip
    | Putchar(e) -> let tmp = eval_expr e genv fenv in
                    print_int tmp; print_string "\n"; genv, fenv
    | Return(_) -> genv, fenv
    |_ -> failwith  "not implemented instr"

and execseq b genv fenv= 
	match b with
      | [] -> genv, fenv
      | i :: b' -> let genv', fenv = execinstr i genv fenv in
                   execseq b' genv' fenv



let interpret prog =

  (*environnement global*)
  let global_env = Hashtbl.create 1024 in
  (*//////////////////////////////*)
  (*ajout des variables globales :*)
  let rec add_globals g genv fenv = 
    match g with
      |[] -> genv
      |(id, _, ex)::s -> Hashtbl.add genv id (eval_expr ex genv fenv);
                       add_globals s genv fenv
  in
  
  (*///////////////////////////*)
  (*environnement des fonctions*)
  let function_env = Hashtbl.create 1024 in

  (*ajout des fonctions :*)
  let rec add_functions f genv fenv=
    match f with
      |[] -> fenv
      |fundef::s -> Hashtbl.add fenv fundef.name fundef; add_functions s genv fenv
  in

  (*///////////////////////////////////*)
  (*initialisation des environnements :*)
  let global_env = add_globals prog.globals global_env function_env in
  let function_env = add_functions prog.functions global_env function_env in

  (*interpretatin du main*)

  let interpret_main main genv fenv=
    match main with
      |[main] -> execseq main.code genv fenv
      |_ -> failwith "error in main interpretation"
  in
  let global_env, function_env = interpret_main prog.main global_env function_env in

  Hashtbl.iter (fun s e -> print_string s; print_string " : "; print_int e; print_string " ") global_env; print_string "\n"

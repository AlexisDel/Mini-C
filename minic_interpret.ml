(*

en entrée : un prog avec liste de variables globale et liste de déclaration de fonctions

étape 1 : créer un environnement de variables globales.

*)

open Minic_ast


exception ExcepSkip

type env = (string, int) Hashtbl.t


(*évaluation d'une expression :*)

let rec eval_expr e env =
	match e with
	  | Cst n -> n
    | BCst b -> if b then 1 else 0
    | Get x -> Hashtbl.find env x
    | Add(e1, e2) ->
      let v1 = eval_expr e1 env in
      let v2 = eval_expr e2 env in
      v1 + v2
    | Mul(e1, e2) ->
      let v1 = eval_expr e1 env in
      let v2 = eval_expr e2 env in
      v1 * v2
    | Lt(e1, e2) ->
      let v1 = eval_expr e1 env in
      let v2 = eval_expr e2 env in
      if v1 < v2 then 1 else 0
    | Null(_) -> -1  (*not initialised variable*)
    | _ -> failwith "not implemented expr"

(*évaluation des instruction et listes d'instructions*)

let rec execinstr i env = 
  match i with
    | Set(x, e) ->
      let v = eval_expr e env in
      let () = print_int v in
      let () = Hashtbl.add env x v in 
      env
    | If(e, b1, b2) ->
      let v = eval_expr e env in
      if v = 1
      then execseq b1 env
      else execseq b2 env
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval_expr e env in
            if v = 0 then env
            else let env' = execseq b env in
                 execinstr i env'
          end
        with
          | ExcepSkip ->  let env' = execinstr (While (e, b)) env in
                              execinstr i env'
          | _ -> failwith "unknown exception"
      end
    | Skip -> raise ExcepSkip
    | Putchar(e) -> let tmp = eval_expr e env in
                    print_int tmp; print_string "\n"; env
    | Return(_) -> env
    |_ -> failwith  "not implemented instr"

and execseq b env = 
	match b with
      | [] -> env
      | i :: b' -> let env' = execinstr i env in
                   execseq b' env'



let interpret prog =

  (*environnement global*)
  let global_env = Hashtbl.create 1024 in

  (*ajout des variables globales :*)
  let rec add_globals g env = 
    match g with
      |[] -> env
      |(id, _, ex)::s -> Hashtbl.add env id (eval_expr ex env);
                       add_globals s env
  in
  let global_env = add_globals prog.globals global_env in
  (*add_globals prog.globals global_env*)
  (*List.iter (fun x -> print_int x; print_string " ") (Hashtbl.iter (add_globals prog.globals global_env))*)

  (*environnement des fonctions*)
  let function_env = Hashtbl.create 1024 in

  (*ajout des fonctions :*)
  let rec add_functions f env=
    match f with
      |[] -> env
      |fundef::s -> Hashtbl.add env fundef.name (fundef.params, fundef.locals, fundef.code); add_functions s env
  in
  let function_env = add_functions prog.functions function_env in

  (*interpretatin du main*)

  let interpret_main main env=
    match main with
      |[main] -> execseq main.code env
      |_ -> failwith "error in main interpretation"
  in
  let global_env = interpret_main prog.main global_env in
  Hashtbl.iter (fun s e -> print_string s; print_string " : "; print_int e; print_string " ") global_env; print_string "\n"

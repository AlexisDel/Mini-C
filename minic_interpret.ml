open Minic_ast


exception ExcepSkip


type env = (string, int) Hashtbl.t

let rec eval e env = 
  match e with
    | Cst n -> n
    | BCst b -> if b then 1 else 0
    | Get x -> Hashtbl.find env x
    | Add(e1, e2) ->
      let v1 = eval e1 env in
      let v2 = eval e2 env in
      v1 + v2
    | Mul(e1, e2) ->
      let v1 = eval e1 env in
      let v2 = eval e2 env in
      v1 * v2
    | Lt(e1, e2) ->
      let v1 = eval e1 env in
      let v2 = eval e2 env in
      if v1 < v2 then 1 else 0
    | _ -> failwith "not implemented"

(**************************************************)

let rec execinstr i env = 
  match i with
    | Set(x, e) ->
      let v = eval e env in
      let () = print_int v in
      let () = Hashtbl.add env x v in 
      env
    | If(e, b1, b2) ->
      let v = eval e env in
      if v = 1
      then execseq b1 env
      else execseq b2 env
    | While(e, b) ->
      begin
        try 
          begin 
            let v = eval e env in
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
    |_ -> failwith  "not implemented"

and execseq (b: instr list) (env: env): 
  env = match b with
      | [] -> env
      | i :: b' -> let env' = execinstr i env in
                   execseq b' env'


module Env = Map.Make(String)

let rec interp_glov_variable l env =
    match l with
      |[] -> env
      |(x, _, e)::s -> let env' = execinstr (Set(x, e)) env in
                    interp_glov_variable s env'

let interpret ast =
  let global_env =
    List.fold_left (fun env (x, ty, e) -> Env.add x (ty, e) env) Env.empty prog.globals
  in
  let global_env = execseq ast global_env in
  print_string "ok\n"
  


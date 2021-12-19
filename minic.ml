let () =
  let file = Sys.argv.(1) in
  let in_channel = open_in file in
  let lexbuf = Lexing.from_channel in_channel in
  let ast = Minic_parser.program Minic_lexer.token lexbuf in
  close_in in_channel;
  Minic_typechecker.typecheck_program ast;
  Printf.printf "Successfully checked program %s\n" file;
  (* On pourrait ajouter ici des étapes suivantes. *)
  (*Minic_interpret.interpret ast;*)
  exit 0

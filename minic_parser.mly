%{

  open Lexing
  open Minic_ast

%}

(* Déclaration des lexèmes *)
%token <int> CST
%token <bool> BOOL_CST
%token <string> IDENT
%token LPAR RPAR BEGIN END
%token RETURN SET
%token IF ELSE WHILE
%token SEMI COMMA
%token INT BOOL VOID
%token PLUS TIMES LT
%token PUTCHAR
%token EOF

%start program
%type <Minic_ast.prog> program

%%

(* Un programme est une liste de déclarations.
   On ajoute une règle déclenchée en cas d'erreur, donnant une
   information minimale : la position. *)
program:
| dl=declaration_list EOF
       { let var_list, fun_list = dl in
         { globals = var_list; functions = fun_list; } }
| error { let pos = $startpos in
          let message =
            Printf.sprintf
              "Syntax error at %d, %d"
              pos.pos_lnum (pos.pos_cnum - pos.pos_bol)
          in
          failwith message }
;

(* Chaque déclaration peut concerner une variable ou une fonction. *)
declaration_list:
| (* vide *) { [], [] }    
| vd=variable_decl dl=declaration_list { let vl, fl = dl in
                                         vd :: vl, fl }
| fd=function_decl dl=declaration_list { let vl, fl = dl in
                                         vl, fd :: fl }
;

(* Déclaration de variable.
   Note : on ne traite ici que le cas où une valeur initiale est fournie.

   À COMPLÉTER
*)
variable_decl:
| t=typ x=IDENT SET e=expression SEMI { (x, t, e) }
| t=typ x=IDENT SEMI { (x, t, Null(x))}
;

(* Indication de type.

   À COMPLÉTER
*)
typ:
| INT { Int }
| BOOL { Bool }
| VOID { Void }
;

(* Déclaration de fonction.
   Note : on ne traite ici que le cas d'une fonction sans argument et
   sans variable locale.

   À COMPLÉTER
*)
function_decl:
| t=typ f=IDENT LPAR p=list(params) RPAR BEGIN v=list(variable_decl) s=list(instruction) END
    { { name=f; code=s; params=p; return=t; locals=v } }
;
params:
| t=typ x=IDENT COMMA { (x, t) }
| t=typ x=IDENT { (x, t) }
;

(* Instructions.

   À COMPLÉTER
*)
instruction:
| PUTCHAR LPAR e=expression RPAR SEMI { Putchar(e) }
| x=IDENT SET n=IDENT SEMI { Set(x,Get(n)) }
| x=IDENT SET e=expression SEMI { Set(x,e) }
| IF LPAR e=expression RPAR BEGIN s1=list(instruction) END { If(e, s1, [Skip])}
| IF LPAR e=expression RPAR BEGIN s1=list(instruction) END ELSE BEGIN s2=list(instruction) END { If(e,s1,s2) }
| WHILE LPAR e=expression RPAR BEGIN s=list(instruction) END { While(e,s) }
| RETURN e=expression SEMI { Return(e) }
| e=expression SEMI { Expr(e) }
;

(* Expressions.

   À COMPLÉTER
*)
expression:
| n=CST { Cst(n) }
| b=BOOL_CST { BCst(b) }
| e1=expression PLUS e2=expression { Add(e1, e2) }
| e1=expression TIMES e2=expression { Mul(e1, e2) }
| e1=expression LT e2=expression { Lt(e1, e2) }
| x=IDENT { Get(x) }
| f=IDENT LPAR a=list(args) RPAR { Call(f,a) }
;

args:
| e=expression COMMA { e }
| e=expression { e }
;
(* Ohm is © 2012 Victor Nicollet *)

open BatPervasives

let hub = Hub.make (function
  | "verb" | "verbatim" -> Some Lex_verbatim.lex 
  | "html" -> Some Lex_html.lex
  | "url" -> Some Lex_url.lex 
  | _ -> None
) 

let putfile path contents = 

  let should = 
    try Digest.file path <> Digest.string contents
    with _ -> true
  in

  if should then begin
    try let channel = Pervasives.open_out_bin path in 
	Pervasives.output_string channel contents ;
	Pervasives.close_out channel 
    with exn -> 
      Printf.printf "Could not write file %S : %s\n" 
	path (Printexc.to_string exn) ;
      exit (-1) ;
  end ;

  should

let extract file = 

  try 

    let channel = Pervasives.open_in file in 
    
    try 
      
      let lexer = 
	if BatString.ends_with file ".htm" then Lex_html.lex else
	  if BatString.ends_with file ".html" then Lex_html.lex else 	    
	    (Printf.printf "-- Warning : unknown format %s\n" file ;
	     Lex_verbatim.lex )
      in
      
      let lexbuf = Lexing.from_channel channel in 
      
      let buf = new Buf.t in 
      
      lexer hub buf lexbuf ;
      Pervasives.close_in channel ;
      
      buf # contents
	
    with exn -> 
      
      Pervasives.close_in channel ;
      raise exn
	
  with exn ->
    
    Printf.printf "Could not process file %S : %s\n"
      file (Printexc.to_string exn) ;

    exit (-1) 

let rec directory path = 

  let stat = 
    try Unix.stat path       
    with exn ->      
      Printf.printf "Could not stat %S : %s\n" 
	path (Printexc.to_string exn) ;
      exit (-1) 
  in

  match stat.Unix.st_kind with 
    | Unix.S_REG -> [ path, extract path ]
    | Unix.S_DIR -> 

      let contents = 
	try Array.to_list (Sys.readdir path) 
	with exn -> 
	  Printf.printf "Could not list directory %S : %s\n" 
	    path (Printexc.to_string exn) ;
	  exit (-1)
      in

      let valid = 
	List.filter (fun str -> 
	  not (BatString.starts_with str ".")
	  && not (BatString.ends_with str "~") 
	  && not (BatString.starts_with str "#")
	) contents
      in

      List.concat (List.map (Filename.concat path |- directory) valid)

    | _ -> []

let generate ?name root = 

  let root = 
    if Filename.is_implicit root then Filename.concat (Sys.getcwd ()) root 
    else root
  in

  let list = directory root in
  let clean = List.map (fun (path,contents) -> 

    let path = 
      if BatString.starts_with path root 
      then BatString.tail path (String.length root) 
      else path 
    in

    let path = 
      if BatString.starts_with path "/"
      then path
      else "/" ^ path 
    in

    path, contents

  ) list in 
 
  let mlfile = 
    let mlbuf = Buffer.create 1024 in
    
    Buffer.add_string mlbuf "(* This file was generated by plugin ohmStatic *)\n" ;
    Buffer.add_string mlbuf "let pages = BatPMap.of_enum (BatList.enum [\n" ;
    
    List.iter (fun (path,contents) ->
      Buffer.add_string mlbuf (Printf.sprintf "  %S, `Page begin fun url html -> \n" path) ;
      List.iter (function 
	| `RAW s -> Buffer.add_string mlbuf 
	  (Printf.sprintf "    Ohm.Html.str %S html ;\n" s) 
	| `URL s -> Buffer.add_string mlbuf 
	  (Printf.sprintf "    Ohm.Html.esc (url %S) html ;\n" s)) contents ;
      Buffer.add_string mlbuf "  end ;\n" 
    ) clean ;
    
    Buffer.add_string mlbuf "])\n\n" ;    
    Buffer.contents mlbuf
  in

  let mlifile = 
    "val pages : OhmStatic.site\n"
  in

  let name = BatOption.default (String.lowercase (Filename.basename root)) name in 
  let modname = if name = "static" then "static" else "static_" ^ name in
  
  let mlpath  = Filename.(concat (concat (Sys.getcwd ()) "_build") modname ^ ".ml") in
  let mlipath = mlpath ^ "i" in
 
  if putfile mlpath mlfile then
    Printf.printf "Generated %s\n" mlpath ;

  if putfile mlipath mlifile then 
    Printf.printf "Generated %s\n" mlipath 

let () = 
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "dwim" then
    generate ~name:"static" (Filename.concat (Sys.getcwd ()) "static")
  else if Array.length Sys.argv = 2 then
    generate Sys.argv.(1)
  else if Array.length Sys.argv > 2 then
    generate ~name:Sys.argv.(2) Sys.argv.(1) 
  else
    Printf.printf "plugin:ohmStatic requires at least one argument" 

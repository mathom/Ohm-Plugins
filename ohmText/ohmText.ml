(* Ohm is © 2012 Victor Nicollet *)

let cut ?ellipsis length text = 
  let split = BatString.nsplit text " " in
  let out   = Buffer.create (length + (BatOption.default 0 (BatOption.map String.length ellipsis))) in
  let rec accum n = function 
    | [] -> Buffer.contents out
    | word :: tail -> let n = n + 1 + String.length word in 
		      if n > length then begin
			(match ellipsis with None -> () | Some e -> Buffer.add_string out e) ;
			Buffer.contents out
		      end else begin
			Buffer.add_char out ' ' ;
			Buffer.add_string out word ;
			accum n tail 
		      end
  in
  accum 0 split

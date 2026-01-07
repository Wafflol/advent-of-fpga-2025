open! Core
open! Hardcaml
open! Day_3

let generate_rtl () =
  let module C = Circuit.With_interface (Joltage.I) (Joltage.O) in
  let circuit = C.create_exn ~name:"hardcaml_template_toplevel" (Joltage.create) in
  let rtl_circuits =
    Rtl.create Verilog [ circuit ]
  in
  let rtl = Rtl.full_hierarchy rtl_circuits |> Rope.to_string in
  print_endline rtl
;;

let rtl_cmd =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_rtl ()]
;;

let () =
  Command_unix.run
    (Command.group ~summary:"" [ "hardcaml_template", rtl_cmd])
;;

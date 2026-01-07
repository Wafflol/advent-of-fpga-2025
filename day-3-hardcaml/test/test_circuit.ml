open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module In_channel = Stdlib.In_channel
module String = Stdlib.String
module Circuit_to_test = Day_3.Joltage
module Simulator = Cyclesim.With_interface (Circuit_to_test.I) (Circuit_to_test.O)
let ( <--. ) = Bits.( <--. )

let read_lines file =
  let contents = (In_channel.with_open_bin) file (In_channel.input_all) in
    String.split_on_char '\n' contents
;;

let filename = "input.txt";; 
let input_lines = read_lines filename;;

let testbench (create_design_fn : Signal.t Circuit_to_test.I.t -> Signal.t Circuit_to_test.O.t) =
    (* Construct the simulation and get its input and output ports. *)
    let sim = Simulator.create create_design_fn in
    let waves, sim = Waveform.create sim in
    let inputs : _ Circuit_to_test.I.t = Cyclesim.inputs sim in
    let outputs : _ Circuit_to_test.O.t = Cyclesim.outputs sim in

    let set_init ~clear ~start ~valid =
        inputs.clear := if clear=1 then Bits.vdd else Bits.gnd;
        inputs.start := if start=1 then Bits.vdd else Bits.gnd;
        inputs.data_valid := if valid=1 then Bits.vdd else Bits.gnd;
    in

    (* unused
    let step ~val_ =
        inputs.line <--. val_;
        Cyclesim.cycle sim;
        while Stdlib.Bool.not @@ Bits.to_bool !(outputs.done_sig) do
            Cyclesim.cycle sim;
        done;
    in
    *)

    (* takes a BCD coded line string (ex 100123) *)
    let step_string bcd_line = 
        match bcd_line with
        | "" -> (); (* last line is empty *)
        | string_line -> (
                inputs.line := Bits.of_string @@ (Circuit_to_test.line_length_verilog ^ string_line);
                Cyclesim.cycle sim;
                while Stdlib.Bool.not @@ Bits.to_bool !(outputs.done_sig) do
                    Cyclesim.cycle sim;
                done;
            );
    in

    set_init ~clear:1 ~start:0 ~valid:0;
    Cyclesim.cycle sim;
    set_init ~clear:0 ~start:1 ~valid:1;

    List.iter input_lines ~f:step_string;

    set_init ~clear:0 ~start:0 ~valid:0;
    Cyclesim.cycle sim;

    Stdio.printf "jolts_1='%d'\n" (Bits.to_int_trunc !(outputs.joltage_1));
    Stdio.printf "jolts_2='%d'\n" (Bits.to_int_trunc !(outputs.joltage_2));
;
    waves
;;


let%expect_test "something" = 
    let waves = testbench Circuit_to_test.create in
    waves |> Waveform.print ~start_cycle:1000000
        ~wave_width:2 ~display_width:100
        ~display_rules:
        Display_rule.[ 
            port_name_is "clock";
            port_name_is "line";
            port_name_is "done_sig";
            port_name_is "shift_1_state";
            port_name_is "joltage_1" ~wave_format:Unsigned_int;
            port_name_is "joltage_2" ~wave_format:Unsigned_int;
        ];
(*             port_name_matches Re.Posix.(compile (re ".*"))] *)
    [%expect {|
      jolts_1='17412'
      jolts_2='172681562473501'
      ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
      │clock             ││┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  │
      │                  ││   └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──│
      │                  ││──────                                                                        │
      │line              ││ 1212.                                                                        │
      │                  ││──────                                                                        │
      │                  ││──────                                                                        │
      │done_sig          ││ 1                                                                            │
      │                  ││──────                                                                        │
      │                  ││──────                                                                        │
      │joltage_1         ││ 17412                                                                        │
      │                  ││──────                                                                        │
      │                  ││──────                                                                        │
      │joltage_2         ││ 1726.                                                                        │
      │                  ││──────                                                                        │
      └──────────────────┘└──────────────────────────────────────────────────────────────────────────────┘
      |}];

;;

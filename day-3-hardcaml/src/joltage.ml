open! Core
open! Hardcaml
open! Hardcaml.Bits
open! Signal

let line_digits = 100
let line_length = (4 * line_digits) (* n BCD characters *)
let line_length_verilog = (string_of_int line_length) ^ "'h"
let buffer_length = line_length - 8
let counter_size = float_of_int line_length |> Float.log2 |> Float.round_up |> int_of_float

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; data_valid : 'a
    ; line : 'a [@bits line_length]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { done_sig: 'a
    ; joltage_1: 'a [@bits 16]
    ; joltage_2: 'a [@bits 64]
    }
  [@@deriving hardcaml]
end

module States = struct
    type t =
    | Idle
    | Data_in
    | Calc
    | Sum
    | Done
    [@@deriving sexp_of, compare ~localize, enumerate]
end

let create (i: _ I.t) =
    let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
    let open Always in
    let sm = State_machine.create (module States) spec in

    let buffer = Variable.reg spec ~width:buffer_length in
    let counter = Variable.reg spec ~width:counter_size in

    let shift_1 = Variable.reg spec ~width:(4*2) in (* 2 BCD is 8 bits *)
    let shift_1_bin = Variable.wire ~default:(zero 7) () in (* shift_1 can have up to the value 99 *)
    let shift_2 = Variable.reg spec ~width:(4*12) in 
    let shift_2_bin = Variable.wire ~default:(zero 40) () in (* log2ceil (10^12 - 1) = 40 *)

    let shift_1_en = Variable.wire ~default:(zero 2) () in
    let shift_2_en = Variable.wire ~default:(zero 12) () in

    let done_wire = Variable.wire ~default:gnd () in
    let joltage_1_reg = Variable.reg spec ~width:(16) in  
    let joltage_1_wire = Variable.wire ~default:(zero 16) () in
    let joltage_2_reg = Variable.reg spec ~width:(64) in  
    let joltage_2_wire = Variable.wire ~default:(zero 64) () in

    let char_pos char = char * 4 in
    (* use applicative operator *)
    let sig_add a b = a +: b in
    let sig_mult_ten a = a *: (of_int_trunc 10 ~width:4) in

    compile 
    [ sm.switch
        [ ( Idle
          , [ 
                joltage_1_reg <-- of_string "16'd0";
                joltage_2_reg <-- of_string "64'd0";

                 when_ i.start [sm.set_next Data_in]
            ] )
        ; ( Data_in
          , [ 
                when_ i.data_valid [
                            counter <-- of_int_trunc 0 ~width:counter_size;
                            buffer <-- i.line.:[line_length-1, 8];
                            shift_1 <-- i.line.:[(char_pos 2) - 1, 0];
                            shift_2 <-- i.line.:[(char_pos 12) - 1, 0];
                            sm.set_next Calc;
                ]
            ] )
        ; ( Calc
          , [ 
                        shift_1_en <-- ((buffer.value.:[(char_pos 1) - 1,0]) >=: (shift_1.value.:[(char_pos 2) - 1,(char_pos 1)]))
                                        @: ((shift_1.value.:[(char_pos 2) - 1,(char_pos 1)])  >=: (shift_1.value.:[(char_pos 1) - 1,0]));
                        shift_1 <-- cases (leading_ones shift_1_en.value) ~default: shift_1.value
                            [
                                of_int_trunc ~width:2 1,buffer.value.:[(char_pos 1) - 1,0] @: shift_1.value.:[(char_pos 1) - 1,0];
                                of_int_trunc ~width:2 2,buffer.value.:[(char_pos 1) - 1,0] @: shift_1.value.:[(char_pos 2) - 1,char_pos 1]
                            ];

                        (* part two only starts after part 1 has processed (12 - 2 = 10) digits *)
                        when_ (counter.value >: (of_int_trunc (9) ~width:counter_size))
                            [ 
                                shift_2_en <-- ((buffer.value.:[(char_pos 1) - 1,0]) >=: (shift_2.value.:[(char_pos 12) - 1,char_pos 11]))
                                                @: ((shift_2.value.:[(char_pos 12) - 1,char_pos 11]) >=: (shift_2.value.:[(char_pos 11) - 1,char_pos 10]))
                                                @: ((shift_2.value.:[(char_pos 11) - 1,char_pos 10]) >=: (shift_2.value.:[(char_pos 10) - 1,char_pos 9]))
                                                @: ((shift_2.value.:[(char_pos 10) - 1,char_pos 9]) >=: (shift_2.value.:[(char_pos 9) - 1,char_pos 8]))
                                                @: ((shift_2.value.:[(char_pos 9) - 1,char_pos 8]) >=: (shift_2.value.:[(char_pos 8) - 1,char_pos 7]))
                                                @: ((shift_2.value.:[(char_pos 8) - 1,char_pos 7]) >=: (shift_2.value.:[(char_pos 7) - 1,char_pos 6]))
                                                @: ((shift_2.value.:[(char_pos 7) - 1,char_pos 6]) >=: (shift_2.value.:[(char_pos 6) - 1,char_pos 5]))
                                                @: ((shift_2.value.:[(char_pos 6) - 1,char_pos 5]) >=: (shift_2.value.:[(char_pos 5) - 1,char_pos 4]))
                                                @: ((shift_2.value.:[(char_pos 5) - 1,char_pos 4]) >=: (shift_2.value.:[(char_pos 4) - 1,char_pos 3]))
                                                @: ((shift_2.value.:[(char_pos 4) - 1,char_pos 3]) >=: (shift_2.value.:[(char_pos 3) - 1,char_pos 2]))
                                                @: ((shift_2.value.:[(char_pos 3) - 1,char_pos 2]) >=: (shift_2.value.:[(char_pos 2) - 1,char_pos 1]))
                                                @: ((shift_2.value.:[(char_pos 2) - 1,char_pos 1]) >=: (shift_2.value.:[(char_pos 1) - 1,char_pos 0]));
                                shift_2 <-- cases (leading_ones shift_2_en.value) ~default:shift_2.value
                                [
                                    of_int_trunc ~width:4 1,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 11) - 1,0];
                                    of_int_trunc ~width:4 2,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 11] @: shift_2.value.:[(char_pos 10) - 1,0];
                                    of_int_trunc ~width:4 3,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 10] @: shift_2.value.:[(char_pos 9) - 1,0];
                                    of_int_trunc ~width:4 4,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 9] @: shift_2.value.:[(char_pos 8) - 1,0];
                                    of_int_trunc ~width:4 5,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 8] @: shift_2.value.:[(char_pos 7) - 1,0];
                                    of_int_trunc ~width:4 6,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 7] @: shift_2.value.:[(char_pos 6) - 1,0];
                                    of_int_trunc ~width:4 7,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 6] @: shift_2.value.:[(char_pos 5) - 1,0];
                                    of_int_trunc ~width:4 8,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 5] @: shift_2.value.:[(char_pos 4) - 1,0];
                                    of_int_trunc ~width:4 9,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 4] @: shift_2.value.:[(char_pos 3) - 1,0];
                                    of_int_trunc ~width:4 10,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 3] @: shift_2.value.:[(char_pos 2) - 1,0];
                                    of_int_trunc ~width:4 11,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 2] @: shift_2.value.:[(char_pos 1) - 1,0];
                                    of_int_trunc ~width:4 12,buffer.value.:[3,0] @: shift_2.value.:[(char_pos 12) - 1,char_pos 1];
                                ];
                            ];

                        buffer <-- (of_string "4'h0") @: (buffer.value.:[buffer_length - 1, 4]);

                        counter <-- counter.value +: (of_int_trunc 1 ~width:counter_size);
                        when_ (counter.value ==: (of_int_trunc (line_digits- 3) ~width:counter_size))
                            [ sm.set_next Sum; ]
            ] )
        ; ( Sum
          , [
                    shift_1_bin <-- (
                                shift_1.value.:[(char_pos 2)-1,char_pos 1] |> sig_mult_ten 
                                |> sig_add ((of_int_trunc 0 ~width:4) @: shift_1.value.:[(char_pos 1) - 1,0])
                        ).:[6,0];
                    joltage_1_reg <-- (joltage_1_reg.value +: ((of_int_trunc 0 ~width:9) @: shift_1_bin.value));

                    shift_2_bin <-- (
                                shift_2.value.:[(char_pos 12)-1,char_pos 11]
                                |> sig_mult_ten 
                                |> sig_add ((of_int_trunc 0 ~width:4) @: shift_2.value.:[(char_pos 11) - 1,char_pos 10])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:8) @: shift_2.value.:[(char_pos 10) - 1,char_pos 9])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:12) @: shift_2.value.:[(char_pos 9) - 1,char_pos 8])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:16) @: shift_2.value.:[(char_pos 8) - 1,char_pos 7])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:20) @: shift_2.value.:[(char_pos 7) - 1,char_pos 6])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:24) @: shift_2.value.:[(char_pos 6) - 1,char_pos 5])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:28) @: shift_2.value.:[(char_pos 5) - 1,char_pos 4])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:32) @: shift_2.value.:[(char_pos 4) - 1,char_pos 3])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:36) @: shift_2.value.:[(char_pos 3) - 1,char_pos 2])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:40) @: shift_2.value.:[(char_pos 2) - 1,char_pos 1])
                                |> sig_mult_ten
                                |> sig_add ((of_int_trunc 0 ~width:44) @: shift_2.value.:[(char_pos 1) - 1,char_pos 0])
                        ).:[39,0];

                    joltage_2_reg <-- (joltage_2_reg.value +: ((of_int_trunc 0 ~width:24) @: shift_2_bin.value));

                    sm.set_next Done;
        ] )
        ; ( Done
          , [ 
                    done_wire <-- vdd;

                when_ i.start [
                        sm.set_next Data_in
                        ]
            ] )
        ];
        joltage_1_wire <-- joltage_1_reg.value;(* buffer.value.:[15,0]; *)
        joltage_2_wire <-- joltage_2_reg.value;
        when_ i.clear [ sm.set_next Idle ]
    ];

    {
        O.done_sig = done_wire.value
        ; O.joltage_1 = joltage_1_wire.value
        ; O.joltage_2 = joltage_2_wire.value
    }
;;

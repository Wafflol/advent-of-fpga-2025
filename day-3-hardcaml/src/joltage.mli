(** An example design that takes a series of input values and calculates the range between
    the largest and smallest one. *)

open! Core
open! Hardcaml

val line_length_verilog: string

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; data_valid : 'a
    ; line : 'a[@bits line_length]
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { done_sig: 'a
    ; joltage_1: 'a[@bits 16]
    ; joltage_2: 'a[@bits 64]
    }
  [@@deriving hardcaml]
end

val create : Signal.t I.t -> Signal.t O.t

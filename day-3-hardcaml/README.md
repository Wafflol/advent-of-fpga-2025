# Day 3 - Hardcaml

## Design

The design uses the same protocol as the systemverilog implementation, and uses the same algorithm - see the README in `day-3-sv/` for it.

The state machine is mostly the same, except `CALC_1` and `CALC_2` have been condensed into just one `Calc` state.

The logic for deciding which registers need to shift takes advantage of the `leading_ones`, function by using the >= comparisons between registers as the input. The logic naturally uses `leading_ones` to decide the enables for the registers.

## Testbench

The testbench is similar to the SystemVerilog version, and it prints out the final outputs at the end of execution.

## How to run

To run the design, replace input.txt with your own desired input file in the test directory, and in the main directory, run `dune build bin/generate.exe @runtest` and `dune promote`.
The outputs should appear in test/test_circuit.ml

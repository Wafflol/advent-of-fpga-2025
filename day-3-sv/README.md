# Day 3 - SystemVerilog

## Design

This design operates off of the following protocol:

- The module begins when `start` is set to 1 (on the positive edge of the clock)
- The module can be completely restarted, setting outputs to 0, by setting `rst` to 1
- The reset is active-high and synchronous
- Once reset, the module resets the counters for the part 1 and part 2 outputs, `joltage1_out` and `joltage2_out` respectively
- Once the module is reset, every time a line needs to be passed in as input, the module should receive 1 on the `start` input bus (for 1 cycle), and then the module will wait until `data_valid` is 1, at which point the module reads whatever is on the `line` bus and calculates the max joltage of `line` for both part 1 and 2 and adds it to the total joltage outputs
- Once it is done the calculations, it sets `done` to high, and is ready to receive another start input
- The input is passed one line at a time as a BCD

The design works as follows:

The module is parametrized, and can take input lines of any reasonable length (restricted by hardware), and can take as many lines as possible, until output registers overflow (in which case widths can be adjusted). For the purpose of the explanation, an input length of 100 is used, which is the same as the AoC input.

It starts by initializing the candidate joltage for the line as the least significant digits for each part (2 digits for part 1 and 12 digits for part 2). The digits are stored in shift registers with enables leading to the right.

In the same state, a shift register buffer is intialized with the 98 digits that aren't intialized by part 1. This allows the circuit to find the max joltage by the following algorithm:

Using the following setup of shift registers: Buffer<sub>0</sub> -> Buffer<sub>1</sub> -> ... Buffer<sub>n</sub> -> Joltage<sub>0</sub> -> Joltage<sub>1</sub> -> ... -> Joltage<sub>m</sub>
Where Buffer<sub>x</sub> is the x<sup>th</sup> digit in the buffer, and Joltage<sub>y</sub> is the y<sup>th</sup> digit in the candidate max Joltage. Buffer is made up of normal shift registers, while Joltage is made up of shift registers with enables.

- Take the last digit in the buffer (least significant), Buffer<sub>n</sub>, and if it is greater than or equal to Joltage<sub>0</sub>, then set the enable for Joltage<sub>0</sub> to 1 (meaning that Joltage<sub>0</sub> will take the value of Buffer<sub>n</sub> in the next clock cycle)

- For all other Joltage<sub>y</sub>, the enable is set to 1 if Joltage<sub>y-1</sub> >= Joltage<sub>y</sub>, and the enable of Joltage<sub>y-1</sub> is also active

- Essentially, what this means is that a digit may only be shifted to the right if it will be replaced in the next cycle and next digit is lesser/equal.


This algorithm ensures that at every step, the Joltage shift registers hold the maximum joltage obtainable from what has already been passed in. Therefore, a design choice could have been made to allow any size lines to be passed in.

Since part 2 is initialized with 12 digits instead of 2, and both parts share the same buffer input, it is delayed by 10 cycles.


Once all of the input has been processed, to convert BCD back into binary, it is trivial for part 1 (Joltage<sub>0</sub> * 10 + Joltage<sub>1</sub>).
However, since multipliers with larger numbers are resource-intensive, to simplify the powers of 10, the sum was evaluated in 12 stages. Each stages multiplies the previous stage by 10 and and then adds one digit by splitting x*10 into x<<3 + x<<1.
Thus, if used in part 1, it would look like:

Joltage<sub>0</sub> << 3 + Joltage<sub>0</sub> << 1 + Joltage<sub>1</sub>

## Testbench

asdf

## How to run

asdf

module joltage #(parameter int LENGTH = 100) (
    input logic clk, rst, start, data_valid,
    input logic [3:0] line [0:LENGTH-1],
    output logic [15:0] joltage1_out,
    output logic [63:0] joltage2_out,
    output logic done
    );

    /*
    * On start, this module waits for data_valid to be high
    * it then takes in a line of length LENGTH and sets done to low
    * then it calculates the max joltage from it
    * it then sets done to high and adds the value to p1_out and p2_out
    * The module then waits for start and then data_valid to be high again and repeats
    *
    * this can be repeated for any amount of lines (assert start first)
    */

    parameter IDLE   = 4'b000_0,
              DATA   = 4'b001_0,
              CALC_1 = 4'b010_0,
              CALC_2 = 4'b011_0,
              SUM    = 4'b100_0,
              DONE   = 4'b101_1;

    logic [3:0] state;
    assign done = state[0];

    logic [3:0] buffer [0:LENGTH-1-2];
    /* Last shift register output wire*/
    logic [3:0] shift_last;
    assign shift_last = buffer[LENGTH-1-2];

    logic [$clog2(LENGTH)-1:0] counter;

    /* Part 1 */
    logic [3:0] p1_curr_jolt [0:1];
    logic p1_jolt_en [0:1];
    always_comb begin : p1_comb 
        p1_jolt_en[0] = shift_last >= p1_curr_jolt[0];
        p1_jolt_en[1] = (p1_curr_jolt[0] >= p1_curr_jolt[1]) && p1_jolt_en[0];
    end

    always_ff @(posedge clk) begin : p1_seq
        if (state == DATA) begin
            p1_curr_jolt[0] <= line[LENGTH-2];
            p1_curr_jolt[1] <= line[LENGTH-1];
        end
        else if (state == CALC_1 || state == CALC_2) begin
            p1_curr_jolt[0] <= p1_jolt_en[0] ? shift_last : p1_curr_jolt[0];
            p1_curr_jolt[1] <= p1_jolt_en[1] ? p1_curr_jolt[0] : p1_curr_jolt[1];
        end

        if (state == IDLE)
            joltage1_out <= 16'd0;
        else if (state == SUM)
            joltage1_out <= joltage1_out + p1_curr_jolt[0] * 4'd10 + p1_curr_jolt[1];
    end

    /* Part 2 */
    logic [3:0] p2_curr_jolt [0:11];
    logic p2_jolt_en [0:11];
    always_comb begin : p2_comb
        p2_jolt_en[0] = (shift_last >= p2_curr_jolt[0]);

        for (int z = 1; z < 12; z++) begin
            p2_jolt_en[z] = (p2_curr_jolt[z-1] >= p2_curr_jolt[z]) && p2_jolt_en[z-1];
        end
    end
    genvar i;
    generate
        for (i = 0; i < 12; i++) begin
            always_ff @(posedge clk) begin : p2_seq
                if (state == DATA) begin
                    p2_curr_jolt[i] <= line[LENGTH-12+i];
                end
                else if (state == CALC_2) begin
                    if (i == 0)
                        p2_curr_jolt[i] <= p2_jolt_en[i] ? shift_last : p2_curr_jolt[i];
                    else
                        p2_curr_jolt[i] <= p2_jolt_en[i] ? p2_curr_jolt[i-1] : p2_curr_jolt[i];
                end
            end
        end
    endgenerate

    logic [39:0] stage1, stage2, stage3, stage4, stage5, stage6;
    logic [39:0] stage7, stage8, stage9, stage10, stage11, stage12;

    always_comb begin : mult_add //this block iteratively sums the BCD
        stage1  = p2_curr_jolt[0];
        stage2  = (stage1  * 10) + p2_curr_jolt[1];
        stage3  = (stage2  * 10) + p2_curr_jolt[2];
        stage4  = (stage3  * 10) + p2_curr_jolt[3];
        stage5  = (stage4  * 10) + p2_curr_jolt[4];
        stage6  = (stage5  * 10) + p2_curr_jolt[5];
        stage7  = (stage6  * 10) + p2_curr_jolt[6];
        stage8  = (stage7  * 10) + p2_curr_jolt[7];
        stage9  = (stage8  * 10) + p2_curr_jolt[8];
        stage10 = (stage9  * 10) + p2_curr_jolt[9];
        stage11 = (stage10 * 10) + p2_curr_jolt[10];
        stage12 = (stage11 * 10) + p2_curr_jolt[11];
    end

    always_ff @(posedge clk) begin : p2_joltage_sum
        if (state == IDLE)
            joltage2_out <= 64'd0;
        else if (state == SUM) begin
            joltage2_out <= joltage2_out + stage12;
        end
    end

    /* Global logic (inputs and counter)*/
    always_ff @(posedge clk) begin : counter_logic
        if (state == DATA)
            counter <= '0;
        else if (state == CALC_1 || state == CALC_2)
            counter <= counter + 1'b1;
    end

    genvar j;
    generate
        for (j = 0; j < LENGTH-2; j++) begin
            always_ff @(posedge clk) begin : shift_reg
                if ((state == DATA) && data_valid) begin
                    buffer[j] <= line[j];
                end
                if (state == CALC_1 || state == CALC_2) begin
                    buffer[j] <= buffer[j-1];
                    if (j == 0)
                        buffer[j] <= 4'd0;
                end
            end
        end
    endgenerate

    /* State Machine Logic */
    always_ff @(posedge clk) begin : state_transitions
        if (rst) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: state <= start ? DATA : IDLE;
                DATA: state <= data_valid ? CALC_1 : DATA;
                CALC_1: state <= counter == 4'd9 ? CALC_2 : CALC_1;
                CALC_2: state <= counter == LENGTH - 2'd3 ? SUM : CALC_2;
                SUM: state <= DONE;
                DONE: state <= start ? DATA : DONE;
                default : ;
            endcase
        end
    end
endmodule

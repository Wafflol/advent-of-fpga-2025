module joltage_tb ();
    parameter LENGTH = 100;
    logic clk, rst, start, data_valid;
    logic [3:0] line [0:LENGTH-1];
    logic [15:0] joltage1_out;
    logic [63:0] joltage2_out;
    logic done;

    joltage #(.LENGTH(LENGTH)) DUT(.*);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        int fd;
        int rc;
        string read_line;

        fd = $fopen("input.txt", "r");

        if (fd)  $display("File was opened successfully : %0d", fd);
        else     $display("File was NOT opened successfully : %0d", fd);

        rst = 1'b1;
        start = 1'b0;
        data_valid = 1'b0;
        #10;
        rst = 1'b0;
        start = 1'b1;
        #10;
        data_valid = 1'b1;

        while (1) begin
            rc = $fgets(read_line, fd);
            if (read_line.len() < 1) break;
            for (int i = 0; i < LENGTH; i++) begin
                line[i] = read_line.substr(i,i).atoi();
            end
            @(posedge done);
        end
        $display("Joltage 1 is: %0d", joltage1_out);
        $display("Joltage 2 is: %0d", joltage2_out);
        #10;
        $stop;
    end
endmodule

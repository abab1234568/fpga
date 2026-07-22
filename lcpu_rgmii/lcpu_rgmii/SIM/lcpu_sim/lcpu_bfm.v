`timescale 1ns / 1ns

module lcpu_bfm #(parameter delay_time = 1000) (
    input  logic        clk, reset_l, OP_DONE,
    input  logic [31:0] RD_DATA,
    output logic [31:0] ADDRESS, WR_DATA,
    output logic        RH_WL, EXEC
);
    integer file, rc;
    reg [1023:0] line;
    reg [31:0] temp_addr, temp_data;

    initial begin
        file = $fopen("test_cmds.txt", "r");
        if (file == 0) file = $fopen("lcpu_sim/test_cmds.txt", "r");
        if (file == 0) file = $fopen("/home/huamingh/work/FPGA_Prj/test/lcpu_rgmii/lcpu_sim/test_cmds.txt", "r");
        if (file == 0) begin $display("BFM: Error opening test_cmds.txt"); $finish; end

        ADDRESS=0; WR_DATA=0; RH_WL=1; EXEC=0;
        #delay_time;
        $display("BFM: reading...");

        while (!$feof(file)) begin
            rc = $fgets(line, file);
            if (rc == 0) begin end
            else begin
                rc = $sscanf(line, " jwrite %h %h", temp_addr, temp_data);
                if (rc == 2) begin
                    @(posedge clk);
                    ADDRESS=temp_addr; WR_DATA=temp_data; RH_WL=0; EXEC=1;
                    @(posedge clk); EXEC=0;
                    wait(OP_DONE);
                    $display("BFM: jwrite 0x%h 0x%h", temp_addr, temp_data);
                end else begin
                    rc = $sscanf(line, " jread %h", temp_addr);
                    if (rc == 1) begin
                        @(posedge clk);
                        ADDRESS=temp_addr; RH_WL=1; EXEC=1;
                        @(posedge clk); EXEC=0;
                        wait(OP_DONE);
                        $display("BFM: jread  0x%h -> 0x%h", temp_addr, RD_DATA);
                    end
                end
            end
        end
        $fclose(file);
        $display("BFM: done.");
    end
endmodule

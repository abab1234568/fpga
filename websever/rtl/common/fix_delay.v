//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        fix_delay					                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2014-12-3 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         fix delay for data bus by clock and clock enable
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2014-12-3 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module fix_delay (
    clk,
    reset_l,
    clk_en,

    data_in,
    data_out
);
  parameter delay_cycles = 10;  //could set delay_cycles>=0, any value
  parameter data_width = 8;
  parameter ram_type = "registers";  // Cyclone IV device : "M9K","registers"


  function integer fun_log2;
    input integer data_in;
    integer cnt;
    integer div;
    begin
      div = data_in - 1;
      cnt = 0;
      while (div > 0) begin
        div = div / 2;
        cnt = cnt + 1;
      end
      fun_log2 = cnt;
    end
  endfunction

  parameter addr_width = fun_log2(delay_cycles);
  input clk;
  input reset_l;
  input clk_en;

  input [data_width-1:0] data_in;
  output [data_width-1:0] data_out;

  reg  [data_width-1:0] data_out;
  reg  [addr_width-1:0] di_addr;
  reg  [addr_width-1:0] do_addr;
  reg  [data_width-1:0] di_data;
  reg  [data_width-1:0] dii_data;
  wire [data_width-1:0] do_data;

  always @(negedge reset_l or posedge clk)  //di_addr+1=do_addr
    if (reset_l == 1'b0) begin
      di_addr  <= 0;
      do_addr  <= 0;
      di_data  <= 0;
      dii_data <= 0;
    end else begin
      if (clk_en == 1'b1) begin
        di_data  <= data_in;
        dii_data <= di_data;
        if (di_addr >= delay_cycles - 1) begin
          di_addr <= 0;
        end else begin
          di_addr <= di_addr + 1;
        end
        do_addr <= di_addr + 2;  //choose 3
        if (di_addr == delay_cycles - 2) begin  //choose 2
          do_addr <= 0;
        end
        if (di_addr == delay_cycles - 1) begin  //choose 1
          do_addr <= 1;
        end
      end
    end

  always @(*) begin
    data_out <= do_data;
    if (delay_cycles == 0) begin
      data_out <= data_in;
    end
    if (delay_cycles == 1) begin
      data_out <= di_data;
    end
    if (delay_cycles == 2) begin
      data_out <= dii_data;
    end
  end


  generate
    if (delay_cycles > 2) begin : delay_using_ram_generation
      simple_dual_port_ram #(
          .addr_width(addr_width),
          .data_width(data_width),
          .ram_type  (ram_type)
      ) u_dly_data_buf (
          .aclk    (clk),
          .aclk_en (clk_en),
          .awr_en  (1'b1),
          .awr_addr(di_addr),
          .awr_data(data_in),
          .bclk    (clk),
          .bclk_en (clk_en),
          .brd_addr(do_addr),
          .brd_data(do_data)
      );
    end
  endgenerate

endmodule  // fix_delay


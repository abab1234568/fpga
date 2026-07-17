//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        single_clock_fifo					                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2010-12-23 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         synchronizing fifo design
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2010-12-23 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module single_clock_fifo (
    clk,
    reset_l,
    //write
    write_en,
    write_data,
    full,
    //read
    read_en,
    read_data,
    empty
);
  parameter addr_width = 4;
  parameter data_width = 8;
  parameter ram_type = "registers";  // Cyclone IV device : "M9K","registers"

  input clk;
  input reset_l;

  input write_en;
  input [data_width-1:0] write_data;
  output full;
  input read_en;
  output [data_width-1:0] read_data;
  output empty;

  //reg define
  reg  [addr_width-1:0] write_no_i;
  wire [addr_width-1:0] next_write_no;
  reg  [addr_width-1:0] read_no_i;
  wire                  wr_en;
  wire                  rd_en;
  reg                   full;
  reg  [data_width-1:0] read_data;
  reg                   empty;
  (* ramstyle = ram_type *)reg  [data_width-1:0] mem_array     [(2**addr_width)-1:0];

  /*******************************************************************************************************
**                              Main Program
**
********************************************************************************************************/
  assign wr_en = ((write_en == 1'b1) && (full == 1'b0)) ? 1'b1 : 1'b0;
  assign rd_en = ((read_en == 1'b1) && (empty == 1'b0)) ? 1'b1 : 1'b0;

  always @(*)
    if (write_no_i == read_no_i) begin
      empty <= 1'b1;
    end else begin
      empty <= 1'b0;
    end
  assign next_write_no = write_no_i + 1;
  always @(*)
    if (next_write_no == read_no_i) begin
      full <= 1'b1;
    end else begin
      full <= 1'b0;
    end

  always @(negedge reset_l or posedge clk)
    if (reset_l == 1'b0) begin
      write_no_i <= 0;
      read_no_i  <= 0;
    end else begin
      if (wr_en == 1'b1) begin
        write_no_i <= write_no_i + 1;
        mem_array[write_no_i] <= write_data;
      end
      if (rd_en == 1'b1) begin
        read_no_i <= read_no_i + 1;
        read_data <= mem_array[read_no_i];
      end
    end

endmodule

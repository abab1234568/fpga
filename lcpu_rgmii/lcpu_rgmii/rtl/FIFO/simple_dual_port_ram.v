//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        simple_dual_port_ram					                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2014-11-29 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         general simple dual port ram
//                                                                            //
// Modification history:[including time, version, author and abstract]        //
// 2014-11-29 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module simple_dual_port_ram (
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,

    bclk,
    bclk_en,
    brd_addr,
    brd_data
);

  parameter	 addr_width = 4,
					 data_width = 8,
					 ram_type = "registers"; // Cyclone IV E device : "M9K", "registers"

  input aclk;
  input aclk_en;
  input awr_en;
  input [addr_width-1:0] awr_addr;
  input [data_width-1:0] awr_data;
  input bclk;
  input bclk_en;
  input [addr_width-1:0] brd_addr;
  output [data_width-1:0] brd_data;

  generate
    if (ram_type == "M9K" || ram_type == "BLOCK_RAM") begin : M9K_RAM_Gen
      simple_dual_port_ram_b #(
          .addr_width(addr_width),
          .data_width(data_width)
      ) u_ram_b (
          .aclk    (aclk),
          .aclk_en (aclk_en),
          .awr_en  (awr_en),
          .awr_addr(awr_addr),
          .awr_data(awr_data),
          .bclk    (bclk),
          .bclk_en (bclk_en),
          .brd_addr(brd_addr),
          .brd_data(brd_data)
      );
    end
  endgenerate

  generate
    if (ram_type == "registers" || ram_type == "distributed") begin : Register_RAM_Gen
      simple_dual_port_ram_r #(
          .addr_width(addr_width),
          .data_width(data_width)
      ) u_ram_r (
          .aclk    (aclk),
          .aclk_en (aclk_en),
          .awr_en  (awr_en),
          .awr_addr(awr_addr),
          .awr_data(awr_data),
          .bclk    (bclk),
          .bclk_en (bclk_en),
          .brd_addr(brd_addr),
          .brd_data(brd_data)
      );
    end
  endgenerate


endmodule



//ram by registers
module simple_dual_port_ram_r (
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,

    bclk,
    bclk_en,
    brd_addr,
    brd_data
);

  parameter addr_width = 4, data_width = 8;

  input aclk;
  input aclk_en;
  input awr_en;
  input [addr_width-1:0] awr_addr;
  input [data_width-1:0] awr_data;
  input bclk;
  input bclk_en;
  input [addr_width-1:0] brd_addr;
  output [data_width-1:0] brd_data;

  reg [data_width-1:0] brd_data;
  reg [data_width-1:0] mem_array[2**addr_width-1:0]  /* synthesis syn_ramstyle = "registers" */;
`ifdef IVL_SIM
  integer _sdpr_init_;
  initial begin
    for (_sdpr_init_ = 0; _sdpr_init_ < 2 ** addr_width; _sdpr_init_ = _sdpr_init_ + 1)
    mem_array[_sdpr_init_] = 0;
  end
`endif

  always @(posedge aclk) begin
    if (aclk_en == 1'b1) begin
      if (awr_en == 1'b1) begin
        mem_array[awr_addr] <= awr_data;
      end
    end
  end

  always @(posedge bclk) begin
    if (bclk_en == 1'b1) begin
      brd_data <= mem_array[brd_addr];
    end
  end

endmodule

//ram by block_ram
module simple_dual_port_ram_b (
    aclk,
    aclk_en,
    awr_en,
    awr_addr,
    awr_data,

    bclk,
    bclk_en,
    brd_addr,
    brd_data
);

  parameter addr_width = 4, data_width = 8;

  input aclk;
  input aclk_en;
  input awr_en;
  input [addr_width-1:0] awr_addr;
  input [data_width-1:0] awr_data;
  input bclk;
  input bclk_en;
  input [addr_width-1:0] brd_addr;
  output [data_width-1:0] brd_data;

  reg [data_width-1:0] brd_data;
  reg [data_width-1:0] mem_array[2**addr_width-1:0]  /* synthesis syn_ramstyle = "M4K" */;
`ifdef IVL_SIM
  integer _sdprb_init_;
  initial begin
    for (_sdprb_init_ = 0; _sdprb_init_ < 2 ** addr_width; _sdprb_init_ = _sdprb_init_ + 1)
    mem_array[_sdprb_init_] = 0;
  end
`endif

  always @(posedge aclk) begin
    if (aclk_en == 1'b1) begin
      if (awr_en == 1'b1) begin
        mem_array[awr_addr] <= awr_data;
      end
    end
  end

  always @(posedge bclk) begin
    if (bclk_en == 1'b1) begin
      brd_data <= mem_array[brd_addr];
    end
  end

endmodule

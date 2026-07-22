//****************************************Copyright 2013[c]************************//
// ************************Declaration***************************************//
// File name:        sop_eop_gen	                                       //
// Author:           huaming.huang@link-real.com.cn                                    //
// Date:             2015-01-08 00:00 	                                     //
// Version Number:   1.0                                                     //
// Abstract:         based on data enable, generate SOP,SOP signals          //
// Modification history:[including time, version, author and abstract]        //
// 2015-01-08 00:00        version 1.0     xxx                                //
// Abstract: Initial                                                          //
//                                                                     //
// *********************************end************************************** //

module eth_presemble #(
    parameter rx_presemble_en = 1,
    parameter tx_presemble_en = 1,
    parameter data_width = 8
) (
    input reset_l,

    input    rx_clk,
    input    rx_clk_en,
    input [data_width-1:0] rx_data_in,
    input    rx_data_en_in,
    input    rx_data_err_in,
    output reg [data_width-1:0] rx_data_out,
    output reg rx_data_en_out,
    output reg rx_data_err_out,

    input    tx_clk,
    input    tx_clk_en,
    input [data_width-1:0] tx_data_in,
    input    tx_data_en_in,
    output reg [data_width-1:0] tx_data_out,
    output reg tx_data_en_out
);

  localparam PRESEMBLE = 8'h55, SFD = 8'hd5;

  reg [13:0]rx_eth_byte_cnt; //max ethernet length is 16K bytes
  reg [6:0] rx_premble;
  reg    rx_valid_header;
  wire[8:0] tx_data_dly;
  reg [13:0]tx_eth_byte_cnt;

  always @(negedge reset_l or posedge rx_clk) begin
    if (reset_l == 1'b0) begin
      rx_data_en_out <= 1'b0;
      rx_data_out <= {data_width{1'b0}};
      rx_data_err_out <= 1'b0;
      rx_eth_byte_cnt <= 14'b0;
      rx_premble <= 7'b0;
      rx_valid_header <= 1'b0;
    end else begin
      rx_data_en_out <= 1'b0;
      rx_data_out <= {data_width{1'b0}};
      rx_data_err_out <= rx_data_err_in;
      if (rx_clk_en == 1'b1) begin
        if (rx_presemble_en == 1'b0) begin
          rx_data_en_out <= rx_data_en_in;
          rx_data_out <= rx_data_in;
        end
        if (rx_presemble_en == 1'b1) begin
          rx_eth_byte_cnt <= 14'b0;
          if (rx_data_en_in == 1'b1) rx_eth_byte_cnt <= rx_eth_byte_cnt + 1;
          if (rx_eth_byte_cnt < 7) begin
            if (rx_data_in == PRESEMBLE) begin
              rx_premble[rx_eth_byte_cnt[2:0]] <= 1'b1;
            end else begin
              rx_premble[rx_eth_byte_cnt[2:0]] <= 1'b0;
            end
          end
          if (rx_eth_byte_cnt == 7) begin
            if (rx_premble == 7'b111_1111) begin
              if (rx_data_in == SFD) begin
                rx_valid_header <= 1'b1;
              end
            end
          end
          if (rx_data_en_in == 1'b0) rx_valid_header <= 1'b0;
          if (rx_valid_header == 1'b1) begin
            rx_data_en_out <= rx_data_en_in;
            rx_data_out <= rx_data_in;
          end
        end
      end
    end
  end

  fix_delay #(
      .delay_cycles (8),
      .data_width  (9),
      .ram_type   ("M9K")//Cyclone IV device : "M9K","registers"
  ) u_fix_delay (
      .clk   (tx_clk),
      .reset_l (reset_l),
      .clk_en  (1'b1),
      .data_in ({tx_data_en_in,tx_data_in}),
      .data_out (tx_data_dly)
  );

  always @(negedge reset_l or posedge tx_clk) begin
    if (reset_l == 1'b0) begin
      tx_data_en_out <= 1'b0;
      tx_data_out <= {data_width{1'b0}};
      tx_eth_byte_cnt <= 14'b0;
    end else begin
      tx_data_en_out <= 1'b0;
      tx_data_out <= {data_width{1'b0}};
      if (tx_clk_en == 1'b1) begin
        if (tx_presemble_en == 1'b0) begin
          tx_data_en_out <= tx_data_en_in;
          tx_data_out <= tx_data_in;
        end
        if (tx_presemble_en == 1'b1) begin
          tx_eth_byte_cnt <= 14'b0;
          if (tx_data_en_in == 1'b1 || tx_data_dly[8]) tx_eth_byte_cnt <= tx_eth_byte_cnt + 1;
          if (tx_eth_byte_cnt < 7) begin
            tx_data_en_out <= tx_data_en_in;
            tx_data_out <= PRESEMBLE;
          end
          if (tx_eth_byte_cnt == 7) begin
            tx_data_en_out <= tx_data_en_in;
            tx_data_out <= SFD;
          end
          if (tx_eth_byte_cnt > 7) begin
            tx_data_en_out <= tx_data_dly[8];
            tx_data_out <= tx_data_dly[7:0];
          end
        end
      end
    end
  end

endmodule

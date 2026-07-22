module gmii2mac (
    input clk,
    input reset_l,

    output [7:0] Eth_TXD,
    output Eth_TXEN,
    output Eth_TXER,

    input    Eth_RXC, //125Mhz/25Mhz/2.5Mhz receive ref clock
    input    Eth_RXDV,
    input    Eth_RXER,
    input [7:0] Eth_RXD,

    output       mac_rx_sop,
    output       mac_rx_en,
    output [7:0] mac_rx_data,
    output       mac_rx_eop,
    output       mac_rx_err,
    input        mac_tx_sop,
    input        mac_tx_en,
    input  [7:0] mac_tx_data,
    input        mac_tx_eop,
    input        mac_tx_err,

    output reg [31:0]rx_afifo_full_cnt,
    output reg [31:0]rx_afifo_empty_cnt,
    output reg [31:0]rx_data_err_line,
    output    [31:0]rx_correct_pkt_cnt,
    output    [31:0]rx_crc_err_pkt_cnt,
    output    [31:0]tx_correct_pkt_cnt,
    output    [31:0]tx_error_pkt_cnt
);

  wire       rx_afifo_full;
  wire       rx_afifo_empty;
  wire [9:0] rx_afifo_data;
  wire       rx_data_en_mac_in;
  wire [7:0] rx_data_mac_in;
  wire       rx_data_err;
  wire       tx_data_en_mac_out;
  wire [7:0] tx_data_mac_out;

  dual_clock_fifo #(
      .addr_width(4),
      .data_width(10),
      .ram_type  ("M9K")  // Cyclone IV device : "M9K","registers"
  ) u_rx_asyncfifo (
      .reset_l   (reset_l),
      .wclk      (Eth_RXC),
      .write_en  (1'b1),
      .write_data({Eth_RXER, Eth_RXDV, Eth_RXD}),
      .full      (rx_afifo_full),
      .rclk      (clk),
      .read_en   (1'b1),
      .read_data (rx_afifo_data),
      .empty     (rx_afifo_empty)
  );

  always @(negedge reset_l or posedge Eth_RXC) begin
    if (reset_l == 1'b0) begin
      rx_afifo_full_cnt <= 32'b0;
    end else begin
      if (rx_afifo_full == 1'b1) rx_afifo_full_cnt <= rx_afifo_full_cnt + 1;
    end
  end
  always @(negedge reset_l or posedge clk) begin
    if (reset_l == 1'b0) begin
      rx_afifo_empty_cnt <= 32'b0;
      rx_data_err_line   <= 32'b0;
    end else begin
      if (rx_afifo_empty == 1'b1) rx_afifo_empty_cnt <= rx_afifo_empty_cnt + 1;
      if (rx_data_err == 1'b1) rx_data_err_line <= rx_data_err_line + 1;
    end
  end

  eth_presemble #(
      .rx_presemble_en(1),
      .tx_presemble_en(1),
      .data_width     (8)
  ) u_eth_presemble (
      .reset_l(reset_l),

      .rx_clk         (clk),
      .rx_clk_en      (1'b1),
      .rx_data_in     (rx_afifo_data[7:0]),
      .rx_data_en_in  (rx_afifo_data[8]),
      .rx_data_err_in (rx_afifo_data[9]),
      .rx_data_out    (rx_data_mac_in),
      .rx_data_en_out (rx_data_en_mac_in),
      .rx_data_err_out(rx_data_err),

      .tx_clk        (clk),
      .tx_clk_en     (1'b1),
      .tx_data_in    (tx_data_mac_out),
      .tx_data_en_in (tx_data_en_mac_out),
      .tx_data_out   (Eth_TXD),
      .tx_data_en_out(Eth_TXEN)
  );
  assign Eth_TXER = 1'b0;

  mac_top u_mac_top (
      .clk    (clk),
      .clk_en (1'b1),
      .reset_l(reset_l),

      .rx_en  (rx_data_en_mac_in),
      .rx_data(rx_data_mac_in),
      .tx_en  (tx_data_en_mac_out),
      .tx_data(tx_data_mac_out),

      .mac_rx_sop (mac_rx_sop),
      .mac_rx_en  (mac_rx_en),
      .mac_rx_data(mac_rx_data),
      .mac_rx_eop (mac_rx_eop),
      .mac_rx_err (mac_rx_err),
      .mac_tx_sop (mac_tx_sop),
      .mac_tx_en  (mac_tx_en),
      .mac_tx_data(mac_tx_data),
      .mac_tx_eop (mac_tx_eop),
      .mac_tx_err (mac_tx_err),

      .mac_rx_stat_cnt_0(rx_correct_pkt_cnt),
      .mac_rx_stat_cnt_1(rx_crc_err_pkt_cnt),
      .mac_tx_stat_cnt_0(tx_correct_pkt_cnt),
      .mac_tx_stat_cnt_1(tx_error_pkt_cnt)
  );

endmodule

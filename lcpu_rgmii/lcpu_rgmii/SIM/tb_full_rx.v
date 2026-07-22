`timescale 1ns/1ps
// Full RX path simulation: GMII→MAC→cpu_channel
// 68字节帧 (前导码8B + 数据60B = 68B total), byte61=0x77

module tb_full_rx;

  reg clk, reset_l, cpu_clk;

  // === GMII 信号 ===
  reg        gmii_rx_dv, gmii_rx_er;
  reg  [7:0] gmii_rxd;

  // === MAC RX GPIO ===
  wire       mac_rx_sop, mac_rx_en, mac_rx_eop, mac_rx_err;
  wire [7:0] mac_rx_data;

  // === CPU Channel ===
  wire       cpu_rd_empty, cpu_rd_reop_pre;
  reg        cpu_rd_rpkt_pop, cpu_rd_ren;
  reg [10:0] cpu_rd_raddr;
  wire [11:0] cpu_rd_rpkt_len;
  wire [7:0] cpu_rd_rdata;

  // ===== generate clocks =====
  always #4  clk = ~clk;       // 125MHz
  always #10 cpu_clk = ~cpu_clk;

  // ===== gmii2mac =====
  wire [7:0] gmii_txd;
  wire       gmii_tx_en, gmii_tx_er;

  gmii2mac u_gmii2mac (
    .clk(clk), .reset_l(reset_l),
    .Eth_TXD(gmii_txd), .Eth_TXEN(gmii_tx_en), .Eth_TXER(gmii_tx_er),
    .Eth_RXC(clk), .Eth_RXDV(gmii_rx_dv), .Eth_RXER(gmii_rx_er), .Eth_RXD(gmii_rxd),
    .mac_rx_sop(mac_rx_sop), .mac_rx_en(mac_rx_en),
    .mac_rx_data(mac_rx_data), .mac_rx_eop(mac_rx_eop), .mac_rx_err(mac_rx_err),
    .mac_tx_sop(0), .mac_tx_en(0), .mac_tx_data(0), .mac_tx_eop(0), .mac_tx_err(0),
    .rx_afifo_full_cnt(), .rx_afifo_empty_cnt(), .rx_data_err_line(),
    .rx_correct_pkt_cnt(), .rx_crc_err_pkt_cnt(),
    .tx_correct_pkt_cnt(), .tx_error_pkt_cnt()
  );

  // ===== cpu_channel =====
  cpu_channel #(.ADDR_WIDTH(11), .DATA_WIDTH(8), .PARA_WIDTH(3)) u_cpu (
    .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
    .mac_rx_sop(mac_rx_sop), .mac_rx_en(mac_rx_en),
    .mac_rx_data(mac_rx_data), .mac_rx_eop(mac_rx_eop),
    .mac_tx_sop(), .mac_tx_en(), .mac_tx_data(), .mac_tx_eop(), .mac_tx_err(),
    .recv_pkt_drop_cnt(),
    .cpu_rd_empty(cpu_rd_empty), .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
    .cpu_rd_rpkt_len(cpu_rd_rpkt_len), .cpu_rd_rpkt_para(), .cpu_rd_ren(cpu_rd_ren),
    .cpu_rd_raddr(cpu_rd_raddr), .cpu_rd_rdata(cpu_rd_rdata), .cpu_rd_reop_pre(cpu_rd_reop_pre),
    .cpu_wr_full(), .cpu_wr_wen(0), .cpu_wr_waddr(0), .cpu_wr_wdata(0),
    .cpu_wr_wpkt_push(0), .cpu_wr_wpkt_len(0), .cpu_wr_wpkt_para(0)
  );

  // ===== test data =====
  integer i;
  reg [7:0] pkt [0:75];  // preamble 8B + 60B data + 4B CRC = 72B... actually let me use 68B total data
  task send_gmii_frame;
    input integer len;
    integer k;
    begin
      for(k=0; k<len; k=k+1) begin
        gmii_rxd <= pkt[k];
        gmii_rx_dv <= 1;
        @(posedge clk);
      end
      gmii_rx_dv <= 0;
      @(posedge clk);
    end
  endtask

  initial begin
    $dumpfile("tb_full_rx.vcd");
    $dumpvars(0, tb_full_rx);
    clk=1; cpu_clk=1; reset_l=0;
    {gmii_rx_dv, gmii_rx_er} = 2'b0; gmii_rxd=0;
    cpu_rd_rpkt_pop=0; cpu_rd_ren=0; cpu_rd_raddr=0;

    // preamble: 55x7 + D5 (8字节)
    for(i=0;i<7;i=i+1)  pkt[i]=8'h55;
    pkt[ 7]=8'hD5;
    // -- 68字节数据帧 (DA+SA+Type+Payload+CRC) --
    // dstMAC: 30:22:cd:76:63:1a
    pkt[ 8]=8'h30; pkt[ 9]=8'h22; pkt[10]=8'hcd;
    pkt[11]=8'h76; pkt[12]=8'h63; pkt[13]=8'h1a;
    // srcMAC: 00:21:85:c5:2b:8f
    pkt[14]=8'h00; pkt[15]=8'h21; pkt[16]=8'h85;
    pkt[17]=8'hc5; pkt[18]=8'h2b; pkt[19]=8'h8f;
    // EtherType: 0800 (IPv4)
    pkt[20]=8'h08; pkt[21]=8'h00;
    // IP+UDP+Payload (bytes 22-67, 46 bytes)
    for(i=22;i<67;i=i+1) pkt[i] = 8'h00;
    pkt[67] = 8'h77;  // byte61 = dstMAC[0]开始数第62个字节 = 0x77
    // CRC: 7a 08 05 96 (bytes 68-71, 后4字节)
    pkt[68]=8'h7a; pkt[69]=8'h08; pkt[70]=8'h05; pkt[71]=8'h96;
    // 帧总长: 8(前导码) + 68(数据) = 76字节, 全部赋值完毕

    #50 reset_l = 1;
    #200;

    $display("=== Sending GMII frame (68 data bytes, byte61=0x77) ===");
    send_gmii_frame(76);  // 8B preamble + 68B data

    #5000;
    if (!cpu_rd_empty) begin
      cpu_rd_rpkt_pop <= 1;
      @(posedge cpu_clk); cpu_rd_rpkt_pop <= 0;
      repeat(2) @(posedge cpu_clk);
      $display("PKT_LEN = %d", cpu_rd_rpkt_len);
      for(i=0;i<8;i=i+1) begin
        cpu_rd_raddr <= i; cpu_rd_ren <= 1;
        repeat(2) @(posedge cpu_clk);
        $display("byte[%0d] = 0x%02h", i, cpu_rd_rdata);
        cpu_rd_ren <= 0; @(posedge cpu_clk);
      end
    end

    $display("SIM DONE"); $finish;
  end

endmodule

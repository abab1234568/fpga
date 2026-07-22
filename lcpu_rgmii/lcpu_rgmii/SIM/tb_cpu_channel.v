`timescale 1ns / 1ps
// Testbench: cpu_channel v4.0 流式过滤仿真
// 过滤条件: cnt==61 && data==0x77('w')

module tb_cpu_channel;

  reg        clk, reset_l, cpu_clk;
  reg        mac_rx_sop, mac_rx_en, mac_rx_eop;
  reg [7:0]  mac_rx_data;

  wire       mac_tx_sop, mac_tx_en, mac_tx_eop, mac_tx_err;
  wire [7:0] mac_tx_data;

  wire       cpu_rd_empty, cpu_rd_reop_pre;
  reg        cpu_rd_rpkt_pop, cpu_rd_ren;
  reg  [10:0] cpu_rd_raddr;
  wire [11:0] cpu_rd_rpkt_len;
  wire [2:0]  cpu_rd_rpkt_para;
  wire [7:0]  cpu_rd_rdata;
  wire [7:0]  recv_pkt_drop_cnt;

  cpu_channel #(.ADDR_WIDTH(11), .DATA_WIDTH(8), .PARA_WIDTH(3)) u_dut (
      .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
      .mac_rx_sop(mac_rx_sop), .mac_rx_en(mac_rx_en),
      .mac_rx_data(mac_rx_data), .mac_rx_eop(mac_rx_eop),
      .mac_tx_sop(mac_tx_sop), .mac_tx_en(mac_tx_en),
      .mac_tx_data(mac_tx_data), .mac_tx_eop(mac_tx_eop), .mac_tx_err(mac_tx_err),
      .recv_pkt_drop_cnt(recv_pkt_drop_cnt),
      .cpu_rd_empty(cpu_rd_empty), .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
      .cpu_rd_rpkt_len(cpu_rd_rpkt_len), .cpu_rd_rpkt_para(cpu_rd_rpkt_para),
      .cpu_rd_ren(cpu_rd_ren), .cpu_rd_raddr(cpu_rd_raddr),
      .cpu_rd_rdata(cpu_rd_rdata), .cpu_rd_reop_pre(cpu_rd_reop_pre),
      .cpu_wr_full(), .cpu_wr_wen(1'b0), .cpu_wr_waddr(11'd0),
      .cpu_wr_wdata(8'd0), .cpu_wr_wpkt_push(1'b0),
      .cpu_wr_wpkt_len(12'd0), .cpu_wr_wpkt_para(3'd0)
  );

  always #4   clk = ~clk;      // 125MHz
  always #10  cpu_clk = ~cpu_clk;  // 50MHz

  // 68字节帧 (用户真实数据)
  integer   i, len;

  task send_frame_pkt;
    input integer nbytes;
    input        use_pkt;  // 1=用真实数据, 0=全零
    integer k;
    reg [7:0] d;
    begin
      @(posedge clk);
      mac_rx_sop <= 1;  mac_rx_en <= 0;
      @(posedge clk);
      mac_rx_sop <= 0;  mac_rx_en <= 1;
      for (k=0; k<nbytes-1; k=k+1) begin
        d = use_pkt ? pkt[k] : 8'h00;
        mac_rx_data <= d;
        @(posedge clk);
      end
      d = use_pkt ? pkt[nbytes-1] : 8'h00;
      mac_rx_data <= d;  mac_rx_eop <= 1;
      @(posedge clk);
      mac_rx_en <= 0;  mac_rx_eop <= 0;
    end
  endtask

  task cpu_read;
    begin
      repeat(3) @(posedge cpu_clk);
      while (cpu_rd_empty) @(posedge cpu_clk);
      cpu_rd_rpkt_pop <= 1;
      @(posedge cpu_clk);  cpu_rd_rpkt_pop <= 0;
      repeat(2) @(posedge cpu_clk);
      len = cpu_rd_rpkt_len;
      $display("\n=== Frame hit! PKT_LEN=%0d ===", len);
      for (i=0; i<len && i<68; i=i+1) begin
        cpu_rd_raddr <= i;  cpu_rd_ren <= 1;
        repeat(2) @(posedge cpu_clk);
        $display("  byte[%0d] = 0x%02h (%c)", i, cpu_rd_rdata,
                 (cpu_rd_rdata>31 && cpu_rd_rdata<127) ? cpu_rd_rdata : 8'h2e);
        cpu_rd_ren <= 0;
        @(posedge cpu_clk);
      end
      $display("  ... (%0d bytes total)\n", len);
    end
  endtask

  // 用户真实 68 字节帧
  wire [7:0] pkt [0:67];
  assign pkt[ 0]=8'h30; assign pkt[ 1]=8'h22; assign pkt[ 2]=8'hcd; assign pkt[ 3]=8'h76;
  assign pkt[ 4]=8'h63; assign pkt[ 5]=8'h1a; assign pkt[ 6]=8'h00; assign pkt[ 7]=8'h21;
  assign pkt[ 8]=8'h85; assign pkt[ 9]=8'hc5; assign pkt[10]=8'h2b; assign pkt[11]=8'h8f;
  assign pkt[12]=8'h08; assign pkt[13]=8'h00; assign pkt[14]=8'h45; assign pkt[15]=8'h00;
  assign pkt[16]=8'h00; assign pkt[17]=8'h32; assign pkt[18]=8'h21; assign pkt[19]=8'hb3;
  assign pkt[20]=8'h00; assign pkt[21]=8'h00; assign pkt[22]=8'h40; assign pkt[23]=8'h11;
  assign pkt[24]=8'h9d; assign pkt[25]=8'h6d; assign pkt[26]=8'hc0; assign pkt[27]=8'ha8;
  assign pkt[28]=8'h01; assign pkt[29]=8'h64; assign pkt[30]=8'hde; assign pkt[31]=8'h49;
  assign pkt[32]=8'h1b; assign pkt[33]=8'h45; assign pkt[34]=8'h05; assign pkt[35]=8'h21;
  assign pkt[36]=8'h27; assign pkt[37]=8'h15; assign pkt[38]=8'h00; assign pkt[39]=8'h1e;
  assign pkt[40]=8'hb1; assign pkt[41]=8'h7a; assign pkt[42]=8'h00; assign pkt[43]=8'h00;
  assign pkt[44]=8'h00; assign pkt[45]=8'h00; assign pkt[46]=8'h00; assign pkt[47]=8'h00;
  assign pkt[48]=8'h00; assign pkt[49]=8'h00; assign pkt[50]=8'h00; assign pkt[51]=8'h00;
  assign pkt[52]=8'h00; assign pkt[53]=8'h00; assign pkt[54]=8'h00; assign pkt[55]=8'h00;
  assign pkt[56]=8'h00; assign pkt[57]=8'h00; assign pkt[58]=8'h77; assign pkt[59]=8'h77;
  assign pkt[60]=8'h77; assign pkt[61]=8'h77; assign pkt[62]=8'h77; assign pkt[63]=8'h77;
  assign pkt[64]=8'h7a; assign pkt[65]=8'h08; assign pkt[66]=8'h05; assign pkt[67]=8'h96;

  initial begin
    $dumpfile("tb_cpu_channel.vcd");
    $dumpvars(0, tb_cpu_channel);
    clk=1; cpu_clk=1; reset_l=0;
    {mac_rx_sop,mac_rx_en,mac_rx_eop} = 4'b0;
    mac_rx_data = 8'd0;
    cpu_rd_rpkt_pop=0; cpu_rd_ren=0; cpu_rd_raddr=0;

    // ---- 帧1: byte61=00 → 应被过滤 ----
    $display("--- Frame 1: byte61=00, filter should block ---");
    #50 reset_l = 1;  #200;
    send_frame_pkt(68, 0);   // 全零, byte61=00
    #3000;
    if (cpu_rd_empty) $display("Frame 1: FILTERED - OK\n");
    else $display("Frame 1: BUG - unexpected match\n");

    // ---- 帧2: 用户真实数据, byte61=0x77 → 应命中 ----
    $display("--- Frame 2: real packet, byte61=0x77, should match ---");
    send_frame_pkt(68, 1);   // 真实 pkt 数据
    #3000;
    if (!cpu_rd_empty) begin
      cpu_read;
      // 验证首尾字节
    end else $display("Frame 2: BUG - should have matched\n");

    #500;  $display("\nSIM DONE");  $finish;
  end
endmodule

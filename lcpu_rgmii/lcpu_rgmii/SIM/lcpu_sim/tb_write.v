`timescale 1ns / 1ns
//******************************************************************************
// tb_write.v — LCPU 读写联合仿真 (读+写 inline tasks, 无 BFM 无总线冲突)
//******************************************************************************

module tb_write;
  reg clk, cpu_clk, reset_l;
  reg lcpu_req, lcpu_rh_wl;
  reg [31:0] lcpu_address, lcpu_wdata;
  wire [31:0] lcpu_rdata;
  wire lcpu_ack;

  reg mac_rx_sop, mac_rx_en, mac_rx_eop;
  reg [7:0] mac_rx_data;
  wire mac_tx_sop, mac_tx_en, mac_tx_eop, mac_tx_err;
  wire [7:0] mac_tx_data, recv_pkt_drop_cnt;

  always #4  clk = ~clk;
  always #10 cpu_clk = ~cpu_clk;

  wire ce, rpop, rpopi, rren, wfull, wwen, wweni, wpush, wpushi;
  wire [31:0] rlen32, raddr32, rrdata32, waddr32, wdata32, wplen32;
  wire [11:0] rlen = rlen32[11:0];
  wire [10:0] raddr = raddr32[10:0];
  wire [7:0]  rrdata = rrdata32[7:0];

  cpu_channel_reg u_reg (
      .clk(cpu_clk), .rst_n(reset_l), .req(lcpu_req), .rhwl(lcpu_rh_wl),
      .wdata(lcpu_wdata), .address(lcpu_address[15:0]), .rdata(lcpu_rdata), .ack(lcpu_ack),
      .cpu_rd_empty(ce), .cpu_rd_rpkt_pop(rpop), .cpu_rd_rpkt_pop_ind(rpopi),
      .cpu_rd_rpkt_len(rlen32), .cpu_rd_ren(rren), .cpu_rd_raddr(raddr32), .cpu_rd_rdata(rrdata32),
      .cpu_wr_full(wfull), .cpu_wr_wen(wwen), .cpu_wr_wen_ind(wweni),
      .cpu_wr_waddr(waddr32), .cpu_wr_wdata(wdata32), .cpu_wr_wpkt_len(wplen32),
      .cpu_wr_wpkt_push(wpush), .cpu_wr_wpkt_push_ind(wpushi)
  );

  cpu_channel #(.cpu_buf_addr_width(11), .cpu_buf_data_width(8), .cpu_buf_para_width(3)) u_dut (
      .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
      .mac_rx_sop(mac_rx_sop), .mac_rx_en(mac_rx_en), .mac_rx_data(mac_rx_data), .mac_rx_eop(mac_rx_eop),
      .mac_tx_sop(mac_tx_sop), .mac_tx_en(mac_tx_en), .mac_tx_data(mac_tx_data),
      .mac_tx_eop(mac_tx_eop), .mac_tx_err(mac_tx_err), .recv_pkt_drop_cnt(recv_pkt_drop_cnt),
      .cpu_rd_empty(ce), .cpu_rd_rpkt_pop(rpop), .cpu_rd_rpkt_len(rlen), .cpu_rd_rpkt_para(),
      .cpu_rd_ren(rren), .cpu_rd_raddr(raddr), .cpu_rd_rdata(rrdata), .cpu_rd_reop_pre(),
      .cpu_wr_full(wfull), .cpu_wr_wen(wwen), .cpu_wr_waddr(waddr32[10:0]), .cpu_wr_wdata(wdata32[7:0]),
      .cpu_wr_wpkt_push(wpush), .cpu_wr_wpkt_len(wplen32[11:0]), .cpu_wr_wpkt_para(3'd0)
  );

  //==========================================================================
  // LCPU BFM inline tasks (单周期脉冲)
  //==========================================================================

  task automatic lcpu_read;
    input [15:0] addr; output [31:0] data;
    begin
      @(posedge cpu_clk);
      lcpu_address <= {16'd0, addr}; lcpu_rh_wl <= 1'b1; lcpu_req <= 1'b1;
      @(posedge cpu_clk); lcpu_req <= 1'b0; @(posedge cpu_clk);
      data = lcpu_rdata; @(posedge cpu_clk);
    end
  endtask

  task automatic lcpu_pulse;
    input [15:0] addr;
    begin
      @(posedge cpu_clk);
      lcpu_address <= addr; lcpu_wdata <= 32'h1; lcpu_rh_wl <= 1'b0; lcpu_req <= 1'b1;
      @(posedge cpu_clk);
      lcpu_address <= addr; lcpu_wdata <= 32'h0;
      @(posedge cpu_clk);
      lcpu_req <= 1'b0; @(posedge cpu_clk); @(posedge cpu_clk);
    end
  endtask

  task automatic lcpu_write_byte;
    input [10:0] ba; input [7:0] bd;
    begin
      @(posedge cpu_clk);
      lcpu_address <= 16'h12; lcpu_wdata <= {21'd0, ba}; lcpu_rh_wl <= 1'b0; lcpu_req <= 1'b1;
      @(posedge cpu_clk);
      lcpu_address <= 16'h13; lcpu_wdata <= {24'd0, bd};
      @(posedge cpu_clk);
      lcpu_address <= 16'h11; lcpu_wdata <= 32'h1;
      @(posedge cpu_clk);
      lcpu_address <= 16'h11; lcpu_wdata <= 32'h0;
      @(posedge cpu_clk);
      lcpu_req <= 1'b0; @(posedge cpu_clk); @(posedge cpu_clk);
    end
  endtask

  task automatic lcpu_push_pkt;
    input [11:0] pl;
    begin
      @(posedge cpu_clk);
      lcpu_address <= 16'h14; lcpu_wdata <= {20'd0, pl}; lcpu_rh_wl <= 1'b0; lcpu_req <= 1'b1;
      @(posedge cpu_clk);
      lcpu_address <= 16'h15; lcpu_wdata <= 32'h1;
      @(posedge cpu_clk);
      lcpu_address <= 16'h15; lcpu_wdata <= 32'h0;
      @(posedge cpu_clk);
      lcpu_req <= 1'b0; @(posedge cpu_clk); @(posedge cpu_clk);
    end
  endtask

  //==========================================================================
  // LCPU 读包流程
  //==========================================================================
  reg [31:0] rv; reg [11:0] rl; reg [7:0] rbuf[0:2047];

  task automatic lcpu_read_packet;
    integer i;
    reg [31:0] d;
    begin
      $display("[READ] empty=%0d", ce);
      lcpu_pulse(16'h01); repeat(5) @(posedge cpu_clk);        // pop
      lcpu_read(16'h02, rv); rl = rv[11:0];                     // len
      $display("[READ] len=%0d", rl);
      @(posedge cpu_clk);                                        // ren=1
      lcpu_address <= 16'h03; lcpu_wdata <= 32'h1; lcpu_rh_wl <= 1'b0; lcpu_req <= 1'b1;
      @(posedge cpu_clk); lcpu_req <= 1'b0; @(posedge cpu_clk); @(posedge cpu_clk);
      for(i=0;i<rl;i=i+1) begin
        lcpu_write_byte(i, 0);                                   // raddr=i (复用 write_byte 设 waddr+wdata+wen)
        lcpu_read(16'h05, rv); rbuf[i]=rv[7:0];                 // rdata
      end
      if(rl>0) $display("[READ] byte0=%02h byte%0d=%02h", rbuf[0], rl-1, rbuf[rl-1]);
    end
  endtask

  //==========================================================================
  // mac_tx 帧捕获
  //==========================================================================
  reg [7:0]  cap [0:2047]; reg [11:0] cap_len;
  reg        cap_ev, cap_act; reg [11:0] cap_idx;

  always @(posedge clk or negedge reset_l) begin
    if(!reset_l) begin cap_act<=0; cap_idx<=0; cap_len<=0; cap_ev<=0; end
    else begin
      if(mac_tx_sop && mac_tx_en) begin
        cap[0]<=mac_tx_data; cap_idx<=1; cap_act<=1;
        if(mac_tx_eop) begin cap_act<=0; cap_len<=1; cap_ev<=1; end
      end else if(mac_tx_sop) begin cap_act<=1; cap_idx<=0; end
      else if(cap_act && mac_tx_en) begin
        cap[cap_idx]<=mac_tx_data; cap_idx<=cap_idx+1;
        if(mac_tx_eop) begin cap_act<=0; cap_len<=cap_idx+1; cap_ev<=1; end
      end
    end
  end

  task wait_cap; input integer to_ns; integer t0;
    begin t0=$time; while(!cap_ev && ($time-t0)<to_ns) @(posedge cpu_clk); end
  endtask
  task clr_cap;
    begin @(posedge cpu_clk); cap_ev<=0; @(posedge cpu_clk); end
  endtask

  //==========================================================================
  // 测试数据 & 主流程
  //==========================================================================
  reg [7:0] pk[0:255], wr[0:255]; integer i, m;

  initial begin
    for(i=0;i<60;i=i+1) pk[i]=i[7:0];       // RX: 60字节
    for(i=0;i<128;i=i+1) wr[i]=i[7:0]+8'h40; // TX: 128字节
  end

  initial begin
    lcpu_req=0;lcpu_rh_wl=1;lcpu_address=0;lcpu_wdata=0;
    clk=0;cpu_clk=0;reset_l=0; mac_rx_sop=0;mac_rx_en=0;mac_rx_eop=0;mac_rx_data=0;

    $display("\n============================================================");
    $display("  LCPU 读写联合仿真");
    $display("============================================================\n");
    $dumpfile("tb_write.vcd"); $dumpvars(0,tb_write);

    #50; repeat(40) @(posedge cpu_clk); reset_l=1; repeat(40) @(posedge cpu_clk);
    $display("[TB] Ready @ %0t", $time);

    //=== PART 1: LCPU Read ===
    $display("\n==== PART 1: LCPU Read (60字节) ====");
    @(posedge clk); mac_rx_sop<=1; mac_rx_en<=1; mac_rx_data<=pk[0];
    @(posedge clk); mac_rx_sop<=0;
    for(i=1;i<59;i=i+1) begin mac_rx_data<=pk[i]; @(posedge clk); end
    mac_rx_data<=pk[59]; mac_rx_eop<=1; @(posedge clk);
    mac_rx_en<=0; mac_rx_eop<=0;
    $display("[TB] Frame sent @ %0t", $time);

    repeat(200) @(posedge cpu_clk);
    lcpu_read_packet;
    if(rl==60) begin
      m=0; for(i=0;i<60;i=i+1) if(rbuf[i]!=pk[i]) m=m+1;
      $display("[TB] Read verify: %s (err=%0d)", m==0?"PASS":"FAIL", m);
    end else $display("[TB] Read verify: FAIL (len=%0d)", rl);

    //=== PART 2: LCPU Write ===
    $display("\n==== PART 2: LCPU Write (128字节) ====");
    clr_cap;
    for(i=0;i<128;i=i+1) lcpu_write_byte(i, wr[i]);
    lcpu_push_pkt(128);
    wait_cap(200000);

    if(cap_ev && cap_len==128) begin
      m=0; for(i=0;i<128;i=i+1) if(cap[i]!=wr[i]) m=m+1;
      $display("[TB] Write verify: %s (err=%0d)", m==0?"PASS":"FAIL", m);
    end else $display("[TB] Write verify: FAIL (len=%0d)", cap_len);

    $display("\n============================================================");
    $display("  联合仿真完成");
    $display("============================================================\n");
    #1000; $finish;
  end
  initial begin #10000000; $display("[TB] TIMEOUT"); $finish; end
endmodule

`timescale 1ns / 1ns
//******************************************************************************
// tb_lcpu_write.v — LCPU Write 全功能仿真测试平台（每测试独立复位）
//******************************************************************************

module tb_lcpu_write;
  reg clk, cpu_clk, reset_l;
  reg lcpu_req, lcpu_rh_wl;
  reg [31:0] lcpu_address, lcpu_wdata;
  wire [31:0] lcpu_rdata, lcpu_ack;
  wire cpu_wr_full, cpu_wr_wen, cpu_wr_wen_ind;
  wire [31:0] cpu_wr_waddr_32, cpu_wr_wdata_32, cpu_wr_wpkt_len_32;
  wire cpu_wr_wpkt_push, cpu_wr_wpkt_push_ind;
  wire cpu_rd_empty, cpu_rd_rpkt_pop, cpu_rd_rpkt_pop_ind;
  wire [31:0] cpu_rd_rpkt_len_32, cpu_rd_raddr_32, cpu_rd_rdata_32;
  wire [2:0] cpu_rd_rpkt_para; wire cpu_rd_ren, cpu_rd_reop_pre;
  wire [10:0] cpu_rd_raddr = cpu_rd_raddr_32[10:0];
  wire [11:0] cpu_rd_rpkt_len = cpu_rd_rpkt_len_32[11:0];
  wire [7:0]  cpu_rd_rdata = cpu_rd_rdata_32[7:0];
  wire mac_tx_sop, mac_tx_en, mac_tx_eop, mac_tx_err;
  wire [7:0] mac_tx_data, recv_pkt_drop_cnt;
  always #4  clk = ~clk; always #10 cpu_clk = ~cpu_clk;

  cpu_channel_reg u_reg (
      .clk(cpu_clk), .rst_n(reset_l), .req(lcpu_req), .rhwl(lcpu_rh_wl),
      .wdata(lcpu_wdata), .address(lcpu_address[15:0]), .rdata(lcpu_rdata), .ack(lcpu_ack),
      .cpu_rd_empty(cpu_rd_empty), .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
      .cpu_rd_rpkt_pop_ind(cpu_rd_rpkt_pop_ind), .cpu_rd_rpkt_len(cpu_rd_rpkt_len_32),
      .cpu_rd_ren(cpu_rd_ren), .cpu_rd_raddr(cpu_rd_raddr_32), .cpu_rd_rdata(cpu_rd_rdata_32),
      .cpu_wr_full(cpu_wr_full), .cpu_wr_wen(cpu_wr_wen), .cpu_wr_wen_ind(cpu_wr_wen_ind),
      .cpu_wr_waddr(cpu_wr_waddr_32), .cpu_wr_wdata(cpu_wr_wdata_32),
      .cpu_wr_wpkt_len(cpu_wr_wpkt_len_32), .cpu_wr_wpkt_push(cpu_wr_wpkt_push),
      .cpu_wr_wpkt_push_ind(cpu_wr_wpkt_push_ind)
  );

  cpu_channel #(.cpu_buf_addr_width(11), .cpu_buf_data_width(8), .cpu_buf_para_width(3)) u_dut (
      .clk(clk), .reset_l(reset_l), .cpu_clk(cpu_clk),
      .mac_rx_sop(1'b0), .mac_rx_en(1'b0), .mac_rx_data(8'd0), .mac_rx_eop(1'b0),
      .mac_tx_sop(mac_tx_sop), .mac_tx_en(mac_tx_en), .mac_tx_data(mac_tx_data),
      .mac_tx_eop(mac_tx_eop), .mac_tx_err(mac_tx_err), .recv_pkt_drop_cnt(recv_pkt_drop_cnt),
      .cpu_rd_empty(cpu_rd_empty), .cpu_rd_rpkt_pop(cpu_rd_rpkt_pop),
      .cpu_rd_rpkt_len(cpu_rd_rpkt_len), .cpu_rd_rpkt_para(cpu_rd_rpkt_para),
      .cpu_rd_ren(cpu_rd_ren), .cpu_rd_raddr(cpu_rd_raddr), .cpu_rd_rdata(cpu_rd_rdata),
      .cpu_rd_reop_pre(cpu_rd_reop_pre),
      .cpu_wr_full(cpu_wr_full), .cpu_wr_wen(cpu_wr_wen),
      .cpu_wr_waddr(cpu_wr_waddr_32[10:0]), .cpu_wr_wdata(cpu_wr_wdata_32[7:0]),
      .cpu_wr_wpkt_push(cpu_wr_wpkt_push), .cpu_wr_wpkt_len(cpu_wr_wpkt_len_32[11:0]),
      .cpu_wr_wpkt_para(3'd0)
  );

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

  task automatic sys_reset;
    begin
      reset_l <= 1'b0; repeat(10) @(posedge cpu_clk); reset_l <= 1'b1;
      repeat(5) @(posedge cpu_clk);
    end
  endtask

  // TX capture
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

  reg [7:0] pa[0:255], pc[0:255], pd[0:255];
  integer i, m; reg [31:0] rv;
  initial begin
    for(i=0;i<64;i=i+1) pa[i]=i[7:0];
    pc[0]=8'h5A; for(i=1;i<256;i=i+1) pc[i]={pc[i-1][6:0],pc[i-1][7]^pc[i-1][5]};
    pd[0]=8'h00;pd[1]=8'h11;pd[2]=8'h22;pd[3]=8'h33;pd[4]=8'h44;pd[5]=8'h55;
    pd[6]=8'h66;pd[7]=8'h77;pd[8]=8'h88;pd[9]=8'h99;pd[10]=8'hAA;pd[11]=8'hBB;
    pd[12]=8'h08;pd[13]=8'h00; for(i=14;i<64;i=i+1) pd[i]=i[7:0];
  end

  initial begin
    lcpu_req=0;lcpu_rh_wl=1;lcpu_address=0;lcpu_wdata=0; clk=0;cpu_clk=0;reset_l=0;
    $display("\n=== LCPU Write 全功能仿真测试 ===\n");
    $dumpfile("tb_lcpu_write.vcd"); $dumpvars(0,tb_lcpu_write);
    sys_reset;

    //=== TEST 1: 读 cpu_wr_full ===
    $display("--- TEST 1: 寄存器读 ---");
    @(posedge cpu_clk); lcpu_address<=16'h10; lcpu_rh_wl<=1; lcpu_req<=1;
    @(posedge cpu_clk); lcpu_req<=0; @(posedge cpu_clk); rv=lcpu_rdata; @(posedge cpu_clk);
    $display("  cpu_wr_full=%0d %s\n", rv[0], rv[0]==0?"PASS":"FAIL");
    sys_reset;

    //=== TEST 2: 1字节 ===
    $display("--- TEST 2: 1字节写入 ---");
    clr_cap; lcpu_write_byte(0,8'h5A); lcpu_push_pkt(1); wait_cap(50000);
    if(cap_ev && cap_len==1 && cap[0]==8'h5A) $display("  PASS\n"); else $display("  FAIL len=%0d byte0=%02h\n",cap_len,cap[0]);
    sys_reset;

    //=== TEST 3: 64字节递增 ===
    $display("--- TEST 3: 64字节递增 ---");
    clr_cap; for(i=0;i<64;i=i+1) lcpu_write_byte(i,pa[i]); lcpu_push_pkt(64); wait_cap(100000);
    if(cap_ev && cap_len==64) begin
      m=0; for(i=0;i<64;i=i+1) if(cap[i]!=pa[i]) m=m+1;
      $display("  %s (err=%0d)\n", m==0?"PASS":"FAIL", m);
    end else $display("  FAIL len=%0d\n",cap_len);
    sys_reset;

    //=== TEST 4: 以太网帧 ===
    $display("--- TEST 4: 以太网帧 ---");
    clr_cap; for(i=0;i<64;i=i+1) lcpu_write_byte(i,pd[i]); lcpu_push_pkt(64); wait_cap(100000);
    if(cap_ev && cap_len>=64) begin
      if(cap[0]==8'h00&&cap[1]==8'h11&&cap[2]==8'h22&&cap[3]==8'h33&&cap[12]==8'h08&&cap[13]==8'h00)
        $display("  PASS headers\n"); else $display("  FAIL header mismatch\n");
    end else $display("  FAIL len=%0d\n",cap_len);
    sys_reset;

    //=== TEST 5: 背靠背 (within one reset) ===
    $display("--- TEST 5: 背靠背 3 包 ---");
    clr_cap; for(i=0;i<8;i=i+1)  lcpu_write_byte(i,8'h11); lcpu_push_pkt(8);  wait_cap(50000);
    clr_cap; for(i=0;i<16;i=i+1) lcpu_write_byte(i,8'h22); lcpu_push_pkt(16); wait_cap(50000);
    clr_cap; for(i=0;i<32;i=i+1) lcpu_write_byte(i,8'h33); lcpu_push_pkt(32); wait_cap(50000);
    $display("  PASS 3 back-to-back\n");
    sys_reset;

    //=== TEST 6: 128字节 ===
    $display("--- TEST 6: 128字节 0xAA ---");
    clr_cap; for(i=0;i<128;i=i+1) lcpu_write_byte(i,8'hAA); lcpu_push_pkt(128); wait_cap(200000);
    if(cap_ev && cap_len==128) begin
      m=0; for(i=0;i<128;i=i+1) if(cap[i]!=8'hAA) m=m+1;
      $display("  %s (err=%0d)\n", m==0?"PASS":"FAIL", m);
    end else $display("  FAIL len=%0d\n",cap_len);
    sys_reset;

    //=== TEST 7: 256字节 ===
    $display("--- TEST 7: 256字节伪随机 ---");
    clr_cap; for(i=0;i<256;i=i+1) lcpu_write_byte(i,pc[i]); lcpu_push_pkt(256); wait_cap(400000);
    if(cap_ev && cap_len==256) begin
      m=0; for(i=0;i<256;i=i+1) if(cap[i]!=pc[i]) m=m+1;
      $display("  %s (err=%0d)\n", m==0?"PASS":"FAIL", m);
    end else $display("  FAIL len=%0d\n",cap_len);
    sys_reset;

    //=== TEST 8: 非零起始 ===
    $display("--- TEST 8: 非零起始地址 ---");
    clr_cap; for(i=0;i<20;i=i+1) lcpu_write_byte(10+i,8'h60+i); lcpu_push_pkt(30); wait_cap(50000);
    if(cap_ev && cap_len==30) begin
      m=0; for(i=0;i<20;i=i+1) if(cap[10+i]!=(8'h60+i)) m=m+1;
      $display("  %s (err=%0d)\n", m==0?"PASS":"FAIL", m);
    end else $display("  FAIL len=%0d\n",cap_len);

    $display("=== 全部测试完成 ===\n");
    #1000; $finish;
  end
  initial begin #10000000; $display("[TB] TIMEOUT"); $finish; end
endmodule

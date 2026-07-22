`timescale 1ns / 1ns

module jtagCPU_Amd_Test_Top #(
    parameter sim_mod    = 1,     // 1: BFM 仿真模式 ; 0: JTAG 真实上板模式
    parameter data_width = 32
)(
    input  wire        clk,
    input  wire        rst_n,

    // CPU 读通道 (包接收) 硬件接口
    input  wire        cpu_rd_empty,
    output wire        cpu_rd_rpkt_pop,
    output wire        cpu_rd_rpkt_pop_ind,
    input  wire [31:0] cpu_rd_rpkt_len,
    output wire        cpu_rd_ren,
    output wire [31:0] cpu_rd_raddr,
    input  wire [31:0] cpu_rd_rdata,

    // CPU 写通道 (包发送) 硬件接口
    input  wire        cpu_wr_full,
    output wire        cpu_wr_wen,
    output wire        cpu_wr_wen_ind,
    output wire [31:0] cpu_wr_waddr,
    output wire [31:0] cpu_wr_wdata,
    output wire [31:0] cpu_wr_wpkt_len,
    output wire        cpu_wr_wpkt_push,
    output wire        cpu_wr_wpkt_push_ind
);

    // 内部总线连线
    wire        lcpu_req;
    wire        lcpu_rh_wl;
    wire [31:0] lcpu_wdata;
    wire [31:0] lcpu_address;
    wire        lcpu_ack;
    wire [31:0] lcpu_rdata;

    // 1. 上板模式：JTAG 硬件内核 (sim_mod == 0)
    generate
        if (sim_mod == 0) begin : jtagCPU_Amd_gen
            jtag_cpu_amd_core #(
                .data_width(32),
                .addr_width(32)
            ) u_jtag_cpu (
                .clk          (clk),
                .rst_n        (rst_n),
                .lcpu_rh_wl   (lcpu_rh_wl),
                .lcpu_req     (lcpu_req),
                .lcpu_ack     (lcpu_ack),
                .lcpu_address (lcpu_address),
                .lcpu_wdata   (lcpu_wdata),
                .lcpu_rdata   (lcpu_rdata)
            );
        end
    endgenerate

    // 2. 仿真模式：BFM 脚本测试器 (sim_mod == 1)
    generate
        if (sim_mod == 1) begin : sim_lcpu_gen
            lcpu_bfm #(5000) u_cpu (
                .clk     (clk),
                .reset_l (rst_n),
                .RH_WL   (lcpu_rh_wl),
                .EXEC    (lcpu_req),
                .OP_DONE (lcpu_ack),
                .ADDRESS (lcpu_address),
                .WR_DATA (lcpu_wdata),
                .RD_DATA (lcpu_rdata)
            );
        end
    endgenerate

    // 3. 实例化真实的包通道寄存器模块 (替换 RegTest)
    cpu_channel_reg u_cpu_channel_reg (
        // 读包通道信号
        .cpu_rd_empty       (cpu_rd_empty),
        .cpu_rd_rpkt_pop    (cpu_rd_rpkt_pop),
        .cpu_rd_rpkt_pop_ind(cpu_rd_rpkt_pop_ind),
        .cpu_rd_rpkt_len    (cpu_rd_rpkt_len),
        .cpu_rd_ren         (cpu_rd_ren),
        .cpu_rd_raddr       (cpu_rd_raddr),
        .cpu_rd_rdata       (cpu_rd_rdata),

        // 写包通道信号
        .cpu_wr_full        (cpu_wr_full),
        .cpu_wr_wen         (cpu_wr_wen),
        .cpu_wr_wen_ind     (cpu_wr_wen_ind),
        .cpu_wr_waddr       (cpu_wr_waddr),
        .cpu_wr_wdata       (cpu_wr_wdata),
        .cpu_wr_wpkt_len    (cpu_wr_wpkt_len),
        .cpu_wr_wpkt_push   (cpu_wr_wpkt_push),
        .cpu_wr_wpkt_push_ind(cpu_wr_wpkt_push_ind),

        // CPU 总线连接
        .clk                (clk),
        .rst_n              (rst_n),
        .req                (lcpu_req),
        .rhwl               (lcpu_rh_wl),
        .wdata              (lcpu_wdata),
        .address            (lcpu_address[15:0]), // 截取低 16 位地址
        .rdata              (lcpu_rdata),
        .ack                (lcpu_ack)
    );

endmodule
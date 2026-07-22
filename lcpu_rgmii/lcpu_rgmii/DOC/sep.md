{
  signal: [
    { name: "clk",      wave: "p......." },
    { name: "clk_en",   wave: "1......." },
    { name: "reset_l",  wave: "1......." },
    {},
    ["输入信号",
      { name: "i_en",   wave: "01..0..." },
      { name: "i_data", wave: "x=1=1x..", data: ["D0", "D1"] },
      { name: "i_err",  wave: "0.1.0..." }
    ],
    {},
    ["输出信号 (延迟1拍)",
      { name: "o_en",   wave: "0.1..0.." },
      { name: "o_data", wave: "x..=1=1x", data: ["D0", "D1"] },
      { name: "o_sop",  wave: "0.10...." },
      { name: "o_eop",  wave: "0..10..." },
      { name: "o_err",  wave: "0..10..." }
    ]
  ],
  head: {
    text: "sop_eop_gen 时序波形图",
    tick: 0
  },
  foot: {
    tock: 0
  }
}
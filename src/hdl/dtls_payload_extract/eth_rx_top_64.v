// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Top-level module for DTLS payload from AXI (AXI in, DTLS payload out)
 */

module eth_rx_top_64
(
  input  wire                  clk,
  input  wire                  rst,

  /*
   * AXI input
   */
  input  wire [63:0] s_axis_tdata,
  input  wire [7:0]  s_axis_tkeep,
  input  wire        s_axis_tvalid,
  output wire        s_axis_tready,
  input  wire        s_axis_tlast,
  input  wire        s_axis_tuser,

  /*
   * AXI output
   */
  output wire [63:0] m_axis_tdata,
  output wire [7:0]  m_axis_tkeep,
  output wire        m_axis_tvalid,
  input  wire        m_axis_tready,
  output wire        m_axis_tlast,
  output wire        m_axis_tuser
);

wire eth_hdr_ready;

assign eth_hdr_ready = 1'b1;

eth_axis_rx #(
  .DATA_WIDTH(64)
)
eth_axis_inst (
  .clk(clk),
  .rst(rst),

  .s_axis_tdata(s_axis_tdata),
  .s_axis_tkeep(s_axis_tkeep),
  .s_axis_tvalid(s_axis_tvalid),
  .s_axis_tready(s_axis_tready),
  .s_axis_tlast(s_axis_tlast),
  .s_axis_tuser(s_axis_tuser),

  .m_eth_hdr_valid(),
  .m_eth_hdr_ready(eth_hdr_ready),
  .m_eth_dest_mac(),
  .m_eth_src_mac(),
  .m_eth_type(),
  .m_eth_payload_axis_tdata(m_axis_tdata),
  .m_eth_payload_axis_tkeep(m_axis_tkeep),
  .m_eth_payload_axis_tvalid(m_axis_tvalid),
  .m_eth_payload_axis_tready(m_axis_tready),
  .m_eth_payload_axis_tlast(m_axis_tlast),
  .m_eth_payload_axis_tuser(m_axis_tuser),

  .busy(),
  .error_header_early_termination()
);

endmodule

`resetall

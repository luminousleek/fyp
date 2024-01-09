// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Top-level module for DTLS payload from AXI (AXI UDP Packet in, DTLS payload out)
 */

module dtls_only_top_64
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

wire dtls_hdr_ready;
wire udp_hdr_valid;

assign dtls_hdr_ready = 1;
assign udp_hdr_valid = 1;

dtls_udp_rx_64 dtls_udp_inst (
  .clk(clk),
  .rst(rst),

  .s_udp_hdr_valid(udp_hdr_valid),
  .s_udp_hdr_ready(),
  .s_eth_dest_mac(0),
  .s_eth_src_mac(0),
  .s_eth_type(0),
  .s_ip_version(0),
  .s_ip_ihl(0),
  .s_ip_dscp(0),
  .s_ip_ecn(0),
  .s_ip_length(0),
  .s_ip_identification(0),
  .s_ip_flags(0),
  .s_ip_fragment_offset(0),
  .s_ip_ttl(0),
  .s_ip_protocol(0),
  .s_ip_header_checksum(0),
  .s_ip_source_ip(0),
  .s_ip_dest_ip(0),
  .s_udp_source_port(0),
  .s_udp_dest_port(0),
  .s_udp_length(0),
  .s_udp_checksum(0),
  .s_udp_payload_axis_tdata(s_axis_tdata),
  .s_udp_payload_axis_tkeep(s_axis_tkeep),
  .s_udp_payload_axis_tvalid(s_axis_tvalid),
  .s_udp_payload_axis_tready(s_axis_tready),
  .s_udp_payload_axis_tlast(s_axis_tlast),
  .s_udp_payload_axis_tuser(s_axis_tuser),

  .m_dtls_hdr_valid(),
  .m_dtls_hdr_ready(dtls_hdr_ready),
  .m_eth_dest_mac(),
  .m_eth_src_mac(),
  .m_eth_type(),
  .m_ip_version(),
  .m_ip_ihl(),
  .m_ip_dscp(),
  .m_ip_ecn(),
  .m_ip_length(),
  .m_ip_identification(),
  .m_ip_flags(),
  .m_ip_fragment_offset(),
  .m_ip_ttl(),
  .m_ip_protocol(),
  .m_ip_header_checksum(),
  .m_ip_source_ip(),
  .m_ip_dest_ip(),
  .m_udp_source_port(),
  .m_udp_dest_port(),
  .m_udp_length(),
  .m_udp_checksum(),
  .m_dtls_type(),
  .m_dtls_version(),
  .m_dtls_epoch(),
  .m_dtls_seqnum(),
  .m_dtls_length(),
  .m_dtls_payload_axis_tdata(m_axis_tdata),
  .m_dtls_payload_axis_tkeep(m_axis_tkeep),
  .m_dtls_payload_axis_tvalid(m_axis_tvalid),
  .m_dtls_payload_axis_tready(m_axis_tready),
  .m_dtls_payload_axis_tlast(m_axis_tlast),
  .m_dtls_payload_axis_tuser(m_axis_tuser),

  .busy(),
  .error_header_early_termination(),
  .error_payload_early_termination(),
  .error_invalid_header()
);

endmodule

`resetall

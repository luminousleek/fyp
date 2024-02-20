// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Top-level module for UDP payload from AXI (AXI in, UDP payload out)
 */

module udp_rx_top_64
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

/*
 * Connections between Ethernet and IP rx modules
*/
wire        ethip_eth_hdr_valid;
wire        ethip_eth_hdr_ready;
wire [47:0] ethip_eth_dest_mac;
wire [47:0] ethip_eth_src_mac;
wire [15:0] ethip_eth_type;
wire [63:0] ethip_eth_payload_axis_tdata;
wire [7:0]  ethip_eth_payload_axis_tkeep;
wire        ethip_eth_payload_axis_tvalid;
wire        ethip_eth_payload_axis_tready;
wire        ethip_eth_payload_axis_tlast;
wire        ethip_eth_payload_axis_tuser;

/*
 * Connections between IP and UDP rx modules
 */
wire        ipudp_ip_hdr_valid;
wire        ipudp_ip_hdr_ready;
wire [47:0] ipudp_eth_dest_mac;
wire [47:0] ipudp_eth_src_mac;
wire [15:0] ipudp_eth_type;
wire [3:0]  ipudp_ip_version;
wire [3:0]  ipudp_ip_ihl;
wire [5:0]  ipudp_ip_dscp;
wire [1:0]  ipudp_ip_ecn;
wire [15:0] ipudp_ip_length;
wire [15:0] ipudp_ip_identification;
wire [2:0]  ipudp_ip_flags;
wire [12:0] ipudp_ip_fragment_offset;
wire [7:0]  ipudp_ip_ttl;
wire [7:0]  ipudp_ip_protocol;
wire [15:0] ipudp_ip_header_checksum;
wire [31:0] ipudp_ip_source_ip;
wire [31:0] ipudp_ip_dest_ip;
wire [63:0] ipudp_ip_payload_axis_tdata;
wire [7:0]  ipudp_ip_payload_axis_tkeep;
wire        ipudp_ip_payload_axis_tvalid;
wire        ipudp_ip_payload_axis_tready;
wire        ipudp_ip_payload_axis_tlast;
wire        ipudp_ip_payload_axis_tuser;

/*
 * Connections between UDP and DTLS rx modules
 */

wire        udpdtls_udp_hdr_valid;
wire        udpdtls_udp_hdr_ready;
wire [47:0] udpdtls_eth_dest_mac;
wire [47:0] udpdtls_eth_src_mac;
wire [15:0] udpdtls_eth_type;
wire [3:0]  udpdtls_ip_version;
wire [3:0]  udpdtls_ip_ihl;
wire [5:0]  udpdtls_ip_dscp;
wire [1:0]  udpdtls_ip_ecn;
wire [15:0] udpdtls_ip_length;
wire [15:0] udpdtls_ip_identification;
wire [2:0]  udpdtls_ip_flags;
wire [12:0] udpdtls_ip_fragment_offset;
wire [7:0]  udpdtls_ip_ttl;
wire [7:0]  udpdtls_ip_protocol;
wire [15:0] udpdtls_ip_header_checksum;
wire [31:0] udpdtls_ip_source_ip;
wire [31:0] udpdtls_ip_dest_ip;
wire [15:0] udpdtls_udp_source_port;
wire [15:0] udpdtls_udp_dest_port;
wire [15:0] udpdtls_udp_length;
wire [15:0] udpdtls_udp_checksum;
wire [63:0] udpdtls_udp_payload_axis_tdata;
wire [7:0]  udpdtls_udp_payload_axis_tkeep;
wire        udpdtls_udp_payload_axis_tvalid;
wire        udpdtls_udp_payload_axis_tready;
wire        udpdtls_udp_payload_axis_tlast;
wire        udpdtls_udp_payload_axis_tuser;

wire dtls_hdr_ready;

assign dtls_hdr_ready = 1'b1;

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

  .m_eth_hdr_valid(ethip_eth_hdr_valid),
  .m_eth_hdr_ready(ethip_eth_hdr_ready),
  .m_eth_dest_mac(ethip_eth_dest_mac),
  .m_eth_src_mac(ethip_eth_src_mac),
  .m_eth_type(ethip_eth_type),
  .m_eth_payload_axis_tdata(ethip_eth_payload_axis_tdata),
  .m_eth_payload_axis_tkeep(ethip_eth_payload_axis_tkeep),
  .m_eth_payload_axis_tvalid(ethip_eth_payload_axis_tvalid),
  .m_eth_payload_axis_tready(ethip_eth_payload_axis_tready),
  .m_eth_payload_axis_tlast(ethip_eth_payload_axis_tlast),
  .m_eth_payload_axis_tuser(ethip_eth_payload_axis_tuser),

  .busy(),
  .error_header_early_termination()
);

ip_eth_rx_64 ip_eth_inst (
  .clk(clk),
  .rst(rst),

  .s_eth_hdr_valid(ethip_eth_hdr_valid),
  .s_eth_hdr_ready(ethip_eth_hdr_ready),
  .s_eth_dest_mac(ethip_eth_dest_mac),
  .s_eth_src_mac(ethip_eth_src_mac),
  .s_eth_type(ethip_eth_type),
  .s_eth_payload_axis_tdata(ethip_eth_payload_axis_tdata),
  .s_eth_payload_axis_tkeep(ethip_eth_payload_axis_tkeep),
  .s_eth_payload_axis_tvalid(ethip_eth_payload_axis_tvalid),
  .s_eth_payload_axis_tready(ethip_eth_payload_axis_tready),
  .s_eth_payload_axis_tlast(ethip_eth_payload_axis_tlast),
  .s_eth_payload_axis_tuser(ethip_eth_payload_axis_tuser),

  .m_ip_hdr_valid(ipudp_ip_hdr_valid),
  .m_ip_hdr_ready(ipudp_ip_hdr_ready),
  .m_eth_dest_mac(ipudp_eth_dest_mac),
  .m_eth_src_mac(ipudp_eth_src_mac),
  .m_eth_type(ipudp_eth_type),
  .m_ip_version(ipudp_ip_version),
  .m_ip_ihl(ipudp_ip_ihl),
  .m_ip_dscp(ipudp_ip_dscp),
  .m_ip_ecn(ipudp_ip_ecn),
  .m_ip_length(ipudp_ip_length),
  .m_ip_identification(ipudp_ip_identification),
  .m_ip_flags(ipudp_ip_flags),
  .m_ip_fragment_offset(ipudp_ip_fragment_offset),
  .m_ip_ttl(ipudp_ip_ttl),
  .m_ip_protocol(ipudp_ip_protocol),
  .m_ip_header_checksum(ipudp_ip_header_checksum),
  .m_ip_source_ip(ipudp_ip_source_ip),
  .m_ip_dest_ip(ipudp_ip_dest_ip),
  .m_ip_payload_axis_tdata(ipudp_ip_payload_axis_tdata),
  .m_ip_payload_axis_tkeep(ipudp_ip_payload_axis_tkeep),
  .m_ip_payload_axis_tvalid(ipudp_ip_payload_axis_tvalid),
  .m_ip_payload_axis_tready(ipudp_ip_payload_axis_tready),
  .m_ip_payload_axis_tlast(ipudp_ip_payload_axis_tlast),
  .m_ip_payload_axis_tuser(ipudp_ip_payload_axis_tuser),

  .busy(),
  .error_header_early_termination(),
  .error_payload_early_termination(),
  .error_invalid_header(),
  .error_invalid_checksum()
);

udp_ip_rx_64 udp_ip_inst (
  .clk(clk),
  .rst(rst),

  .s_ip_hdr_valid(ipudp_ip_hdr_valid),
  .s_ip_hdr_ready(ipudp_ip_hdr_ready),
  .s_eth_dest_mac(ipudp_eth_dest_mac),
  .s_eth_src_mac(ipudp_eth_src_mac),
  .s_eth_type(ipudp_eth_type),
  .s_ip_version(ipudp_ip_version),
  .s_ip_ihl(ipudp_ip_ihl),
  .s_ip_dscp(ipudp_ip_dscp),
  .s_ip_ecn(ipudp_ip_ecn),
  .s_ip_length(ipudp_ip_length),
  .s_ip_identification(ipudp_ip_identification),
  .s_ip_flags(ipudp_ip_flags),
  .s_ip_fragment_offset(ipudp_ip_fragment_offset),
  .s_ip_ttl(ipudp_ip_ttl),
  .s_ip_protocol(ipudp_ip_protocol),
  .s_ip_header_checksum(ipudp_ip_header_checksum),
  .s_ip_source_ip(ipudp_ip_source_ip),
  .s_ip_dest_ip(ipudp_ip_dest_ip),
  .s_ip_payload_axis_tdata(ipudp_ip_payload_axis_tdata),
  .s_ip_payload_axis_tkeep(ipudp_ip_payload_axis_tkeep),
  .s_ip_payload_axis_tvalid(ipudp_ip_payload_axis_tvalid),
  .s_ip_payload_axis_tready(ipudp_ip_payload_axis_tready),
  .s_ip_payload_axis_tlast(ipudp_ip_payload_axis_tlast),
  .s_ip_payload_axis_tuser(ipudp_ip_payload_axis_tuser),

  .m_udp_hdr_valid(udpdtls_udp_hdr_valid),
  .m_udp_hdr_ready(udpdtls_udp_hdr_ready),
  .m_eth_dest_mac(udpdtls_eth_dest_mac),
  .m_eth_src_mac(udpdtls_eth_src_mac),
  .m_eth_type(udpdtls_eth_type),
  .m_ip_version(udpdtls_ip_version),
  .m_ip_ihl(udpdtls_ip_ihl),
  .m_ip_dscp(udpdtls_ip_dscp),
  .m_ip_ecn(udpdtls_ip_ecn),
  .m_ip_length(udpdtls_ip_length),
  .m_ip_identification(udpdtls_ip_identification),
  .m_ip_flags(udpdtls_ip_flags),
  .m_ip_fragment_offset(udpdtls_ip_fragment_offset),
  .m_ip_ttl(udpdtls_ip_ttl),
  .m_ip_protocol(udpdtls_ip_protocol),
  .m_ip_header_checksum(udpdtls_ip_header_checksum),
  .m_ip_source_ip(udpdtls_ip_source_ip),
  .m_ip_dest_ip(udpdtls_ip_dest_ip),
  .m_udp_source_port(udpdtls_udp_source_port),
  .m_udp_dest_port(udpdtls_udp_dest_port),
  .m_udp_length(udpdtls_udp_length),
  .m_udp_checksum(udpdtls_udp_checksum),
  .m_udp_payload_axis_tdata(udpdtls_udp_payload_axis_tdata),
  .m_udp_payload_axis_tkeep(udpdtls_udp_payload_axis_tkeep),
  .m_udp_payload_axis_tvalid(udpdtls_udp_payload_axis_tvalid),
  .m_udp_payload_axis_tready(udpdtls_udp_payload_axis_tready),
  .m_udp_payload_axis_tlast(udpdtls_udp_payload_axis_tlast),
  .m_udp_payload_axis_tuser(udpdtls_udp_payload_axis_tuser),

  .busy(),
  .error_header_early_termination(),
  .error_payload_early_termination()
);

dtls_udp_rx_64 dtls_udp_inst (
  .clk(clk),
  .rst(rst),

  .s_udp_hdr_valid(udpdtls_udp_hdr_valid),
  .s_udp_hdr_ready(udpdtls_udp_hdr_ready),
  .s_eth_dest_mac(udpdtls_eth_dest_mac),
  .s_eth_src_mac(udpdtls_eth_src_mac),
  .s_eth_type(udpdtls_eth_type),
  .s_ip_version(udpdtls_ip_version),
  .s_ip_ihl(udpdtls_ip_ihl),
  .s_ip_dscp(udpdtls_ip_dscp),
  .s_ip_ecn(udpdtls_ip_ecn),
  .s_ip_length(udpdtls_ip_length),
  .s_ip_identification(udpdtls_ip_identification),
  .s_ip_flags(udpdtls_ip_flags),
  .s_ip_fragment_offset(udpdtls_ip_fragment_offset),
  .s_ip_ttl(udpdtls_ip_ttl),
  .s_ip_protocol(udpdtls_ip_protocol),
  .s_ip_header_checksum(udpdtls_ip_header_checksum),
  .s_ip_source_ip(udpdtls_ip_source_ip),
  .s_ip_dest_ip(udpdtls_ip_dest_ip),
  .s_udp_source_port(udpdtls_udp_source_port),
  .s_udp_dest_port(udpdtls_udp_dest_port),
  .s_udp_length(udpdtls_udp_length),
  .s_udp_checksum(udpdtls_udp_checksum),
  .s_udp_payload_axis_tdata(udpdtls_udp_payload_axis_tdata),
  .s_udp_payload_axis_tkeep(udpdtls_udp_payload_axis_tkeep),
  .s_udp_payload_axis_tvalid(udpdtls_udp_payload_axis_tvalid),
  .s_udp_payload_axis_tready(udpdtls_udp_payload_axis_tready),
  .s_udp_payload_axis_tlast(udpdtls_udp_payload_axis_tlast),
  .s_udp_payload_axis_tuser(udpdtls_udp_payload_axis_tuser),

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

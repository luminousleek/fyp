/*

Copyright (c) 2014-2018 Alex Forencich
Modified by Isaac Lee from ip_eth_rx_64.v

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DTLS UDP frame receiver (UDP frame in, DTLS frame out, 64 bit datapath)
 */
module dtls_udp_rx_64
(
    input  wire        clk,
    input  wire        rst,

    /*
     * UDP frame input
     */
    input  wire        s_udp_hdr_valid,
    output wire        s_udp_hdr_ready,
    input  wire [47:0] s_eth_dest_mac,
    input  wire [47:0] s_eth_src_mac,
    input  wire [15:0] s_eth_type,
    input  wire [3:0]  s_ip_version,
    input  wire [3:0]  s_ip_ihl,
    input  wire [5:0]  s_ip_dscp,
    input  wire [1:0]  s_ip_ecn,
    input  wire [15:0] s_ip_length,
    input  wire [15:0] s_ip_identification,
    input  wire [2:0]  s_ip_flags,
    input  wire [12:0] s_ip_fragment_offset,
    input  wire [7:0]  s_ip_ttl,
    input  wire [7:0]  s_ip_protocol,
    input  wire [15:0] s_ip_header_checksum,
    input  wire [31:0] s_ip_source_ip,
    input  wire [31:0] s_ip_dest_ip,
    input  wire [15:0] s_udp_source_port,
    input  wire [15:0] s_udp_dest_port,
    input  wire [15:0] s_udp_length,
    input  wire [15:0] s_udp_checksum,
    input  wire [63:0] s_udp_payload_axis_tdata,
    input  wire [7:0]  s_udp_payload_axis_tkeep,
    input  wire        s_udp_payload_axis_tvalid,
    output wire        s_udp_payload_axis_tready,
    input  wire        s_udp_payload_axis_tlast,
    input  wire        s_udp_payload_axis_tuser,

    /*
     * DTLS frame output
     */
    output wire        m_dtls_hdr_valid,
    input  wire        m_dtls_hdr_ready,
    output wire [47:0] m_eth_dest_mac,
    output wire [47:0] m_eth_src_mac,
    output wire [15:0] m_eth_type,
    output wire [3:0]  m_ip_version,
    output wire [3:0]  m_ip_ihl,
    output wire [5:0]  m_ip_dscp,
    output wire [1:0]  m_ip_ecn,
    output wire [15:0] m_ip_length,
    output wire [15:0] m_ip_identification,
    output wire [2:0]  m_ip_flags,
    output wire [12:0] m_ip_fragment_offset,
    output wire [7:0]  m_ip_ttl,
    output wire [7:0]  m_ip_protocol,
    output wire [15:0] m_ip_header_checksum,
    output wire [31:0] m_ip_source_ip,
    output wire [31:0] m_ip_dest_ip,
    output wire [15:0] m_udp_source_port,
    output wire [15:0] m_udp_dest_port,
    output wire [15:0] m_udp_length,
    output wire [15:0] m_udp_checksum,
    output wire [7:0]  m_dtls_type,
    output wire [15:0] m_dtls_version,
    output wire [15:0] m_dtls_epoch,
    output wire [47:0] m_dtls_seqnum,
    output wire [15:0] m_dtls_length,
    output wire [63:0] m_dtls_payload_axis_tdata,
    output wire [7:0]  m_dtls_payload_axis_tkeep,
    output wire        m_dtls_payload_axis_tvalid,
    input  wire        m_dtls_payload_axis_tready,
    output wire        m_dtls_payload_axis_tlast,
    output wire        m_dtls_payload_axis_tuser,
    /*
     * Status signals
     */
    output wire        busy,
    output wire        error_header_early_termination,
    output wire        error_payload_early_termination,
    output wire        error_invalid_header
);

/*

DTLS Frame

 Field                       Length
 Destination MAC address     6 octets
 Source MAC address          6 octets
 Ethertype (0x0800)          2 octets
 Version (4)                 4 bits
 IHL (5-15)                  4 bits
 DSCP (0)                    6 bits
 ECN (0)                     2 bits
 length                      2 octets
 identification (0?)         2 octets
 flags (010)                 3 bits
 fragment offset (0)         13 bits
 time to live (64?)          1 octet
 protocol                    1 octet
 header checksum             2 octets
 source IP                   4 octets
 destination IP              4 octets
 options                     (IHL-5)*4 octets

 source port                 2 octets
 desination port             2 octets
 length                      2 octets
 checksum                    2 octets

 type                        1 octet
 version                     2 octets
 epoch                       2 octets
 sequence number             6 octets
 length                      2 octets

 payload                     length octets

This module receives a UDP frame with header fields in parallel and
payload on an AXI stream interface, decodes and strips the DTLS header fields,
then produces the header fields in parallel along with the DTLS payload in a
separate AXI stream.

*/

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_READ_HEADER = 3'd1,
    STATE_READ_PAYLOAD = 3'd2,
    STATE_READ_PAYLOAD_LAST = 3'd3,
    STATE_WAIT_LAST = 3'd4;

reg [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
reg store_udp_hdr;
reg store_hdr_word_0;
reg store_hdr_word_1;
reg store_last_word;

reg flush_save;
reg transfer_in_save;

reg [5:0] hdr_ptr_reg = 6'd0, hdr_ptr_next;
reg [15:0] word_count_reg = 16'd0, word_count_next;

reg [63:0] last_word_data_reg = 64'd0;
reg [7:0] last_word_keep_reg = 8'd0;

reg s_udp_hdr_ready_reg = 1'b0, s_udp_hdr_ready_next;
reg s_udp_payload_axis_tready_reg = 1'b0, s_udp_payload_axis_tready_next;

reg m_dtls_hdr_valid_reg = 1'b0, m_dtls_hdr_valid_next;
reg [47:0] m_eth_dest_mac_reg = 48'd0;
reg [47:0] m_eth_src_mac_reg = 48'd0;
reg [15:0] m_eth_type_reg = 16'd0;
reg [3:0] m_ip_version_reg = 4'd0;
reg [3:0] m_ip_ihl_reg = 4'd0;
reg [5:0] m_ip_dscp_reg = 6'd0;
reg [1:0] m_ip_ecn_reg = 2'd0;
reg [15:0] m_ip_length_reg = 16'd0;
reg [15:0] m_ip_identification_reg = 16'd0;
reg [2:0] m_ip_flags_reg = 3'd0;
reg [12:0] m_ip_fragment_offset_reg = 13'd0;
reg [7:0] m_ip_ttl_reg = 8'd0;
reg [7:0] m_ip_protocol_reg = 8'd0;
reg [15:0] m_ip_header_checksum_reg = 16'd0;
reg [31:0] m_ip_source_ip_reg = 32'd0;
reg [31:0] m_ip_dest_ip_reg = 32'd0;
reg [15:0] m_udp_source_port_reg = 16'd0;
reg [15:0] m_udp_dest_port_reg = 16'd0;
reg [15:0] m_udp_length_reg = 16'd0;
reg [15:0] m_udp_checksum_reg = 16'd0;
reg [7:0] m_dtls_type_reg = 8'd0;
reg [15:0] m_dtls_version_reg = 16'd0;
reg [15:0] m_dtls_epoch_reg = 16'd0;
reg [47:0] m_dtls_seqnum_reg = 48'd0;
reg [15:0] m_dtls_length_reg = 16'd0;

reg busy_reg = 1'b0;
reg error_header_early_termination_reg = 1'b0, error_header_early_termination_next;
reg error_payload_early_termination_reg = 1'b0, error_payload_early_termination_next;
reg error_invalid_header_reg = 1'b0, error_invalid_header_next;

reg [63:0] save_udp_payload_axis_tdata_reg = 64'd0;
reg [7:0] save_udp_payload_axis_tkeep_reg = 8'd0;
reg save_udp_payload_axis_tlast_reg = 1'b0;
reg save_udp_payload_axis_tuser_reg = 1'b0;

reg [63:0] shift_udp_payload_axis_tdata;
reg [7:0] shift_udp_payload_axis_tkeep;
reg shift_udp_payload_axis_tvalid;
reg shift_udp_payload_axis_tlast;
reg shift_udp_payload_axis_tuser;
reg shift_udp_payload_s_tready;
reg shift_udp_payload_extra_cycle_reg = 1'b0;

// internal datapath
reg [63:0] m_dtls_payload_axis_tdata_int;
reg [7:0]  m_dtls_payload_axis_tkeep_int;
reg        m_dtls_payload_axis_tvalid_int;
reg        m_dtls_payload_axis_tready_int_reg = 1'b0;
reg        m_dtls_payload_axis_tlast_int;
reg        m_dtls_payload_axis_tuser_int;
wire       m_dtls_payload_axis_tready_int_early;

assign s_udp_hdr_ready = s_udp_hdr_ready_reg;
assign s_udp_payload_axis_tready = s_udp_payload_axis_tready_reg;

assign m_dtls_hdr_valid = m_dtls_hdr_valid_reg;
assign m_eth_dest_mac = m_eth_dest_mac_reg;
assign m_eth_src_mac = m_eth_src_mac_reg;
assign m_eth_type = m_eth_type_reg;
assign m_ip_version = m_ip_version_reg;
assign m_ip_ihl = m_ip_ihl_reg;
assign m_ip_dscp = m_ip_dscp_reg;
assign m_ip_ecn = m_ip_ecn_reg;
assign m_ip_length = m_ip_length_reg;
assign m_ip_identification = m_ip_identification_reg;
assign m_ip_flags = m_ip_flags_reg;
assign m_ip_fragment_offset = m_ip_fragment_offset_reg;
assign m_ip_ttl = m_ip_ttl_reg;
assign m_ip_protocol = m_ip_protocol_reg;
assign m_ip_header_checksum = m_ip_header_checksum_reg;
assign m_ip_source_ip = m_ip_source_ip_reg;
assign m_ip_dest_ip = m_ip_dest_ip_reg;
assign m_udp_source_port = m_udp_source_port_reg;
assign m_udp_dest_port = m_udp_dest_port_reg;
assign m_udp_length = m_udp_length_reg;
assign m_udp_checksum = m_udp_checksum_reg;
assign m_dtls_type = m_dtls_type_reg;
assign m_dtls_version = m_dtls_version_reg;
assign m_dtls_epoch = m_dtls_epoch_reg;
assign m_dtls_seqnum = m_dtls_seqnum_reg;
assign m_dtls_length = m_dtls_length_reg;

assign busy = busy_reg;
assign error_header_early_termination = error_header_early_termination_reg;
assign error_payload_early_termination = error_payload_early_termination_reg;
assign error_invalid_header = error_invalid_header_reg;

function [3:0] keep2count;
    input [7:0] k;
    casez (k)
        8'bzzzzzzz0: keep2count = 4'd0;
        8'bzzzzzz01: keep2count = 4'd1;
        8'bzzzzz011: keep2count = 4'd2;
        8'bzzzz0111: keep2count = 4'd3;
        8'bzzz01111: keep2count = 4'd4;
        8'bzz011111: keep2count = 4'd5;
        8'bz0111111: keep2count = 4'd6;
        8'b01111111: keep2count = 4'd7;
        8'b11111111: keep2count = 4'd8;
    endcase
endfunction

function [7:0] count2keep;
    input [3:0] k;
    case (k)
        4'd0: count2keep = 8'b00000000;
        4'd1: count2keep = 8'b00000001;
        4'd2: count2keep = 8'b00000011;
        4'd3: count2keep = 8'b00000111;
        4'd4: count2keep = 8'b00001111;
        4'd5: count2keep = 8'b00011111;
        4'd6: count2keep = 8'b00111111;
        4'd7: count2keep = 8'b01111111;
        4'd8: count2keep = 8'b11111111;
    endcase
endfunction

always @* begin
    // shift udp payload by 5 octets so that start of dtls payload is aligned at start of 8 octet word
    shift_udp_payload_axis_tdata[23:0] = save_udp_payload_axis_tdata_reg[63:40];
    shift_udp_payload_axis_tkeep[2:0] = save_udp_payload_axis_tkeep_reg[7:5];

    if (shift_udp_payload_extra_cycle_reg) begin
        shift_udp_payload_axis_tdata[63:24] = 40'd0;
        shift_udp_payload_axis_tkeep[7:3] = 5'd0;
        shift_udp_payload_axis_tvalid = 1'b1;
        shift_udp_payload_axis_tlast = save_udp_payload_axis_tlast_reg;
        shift_udp_payload_axis_tuser = save_udp_payload_axis_tuser_reg;
        shift_udp_payload_s_tready = flush_save;
    end else begin
        shift_udp_payload_axis_tdata[63:24] = s_udp_payload_axis_tdata[39:0];
        shift_udp_payload_axis_tkeep[7:3] = s_udp_payload_axis_tkeep[4:0];
        shift_udp_payload_axis_tvalid = s_udp_payload_axis_tvalid;
        shift_udp_payload_axis_tlast = (s_udp_payload_axis_tlast && (s_udp_payload_axis_tkeep[7:4] == 0));
        shift_udp_payload_axis_tuser = (s_udp_payload_axis_tuser && (s_udp_payload_axis_tkeep[7:4] == 0));
        shift_udp_payload_s_tready = !(s_udp_payload_axis_tlast && s_udp_payload_axis_tvalid && transfer_in_save);
    end
end

always @* begin
    state_next = STATE_IDLE;

    flush_save = 1'b0;
    transfer_in_save = 1'b0;

    s_udp_hdr_ready_next = 1'b0;
    s_udp_payload_axis_tready_next = 1'b0;

    store_udp_hdr = 1'b0;
    store_hdr_word_0 = 1'b0;
    store_hdr_word_1 = 1'b0;

    store_last_word = 1'b0;

    hdr_ptr_next = hdr_ptr_reg;
    word_count_next = word_count_reg;

    m_dtls_hdr_valid_next = m_dtls_hdr_valid_reg && !m_dtls_hdr_ready;

    error_header_early_termination_next = 1'b0;
    error_payload_early_termination_next = 1'b0;
    error_invalid_header_next = 1'b0;

    m_dtls_payload_axis_tdata_int = 64'd0;
    m_dtls_payload_axis_tkeep_int = 8'd0;
    m_dtls_payload_axis_tvalid_int = 1'b0;
    m_dtls_payload_axis_tlast_int = 1'b0;
    m_dtls_payload_axis_tuser_int = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for header
            hdr_ptr_next = 6'd0;
            flush_save = 1'b1;
            s_udp_hdr_ready_next = !m_dtls_hdr_valid_next;

            if (s_udp_hdr_ready && s_udp_hdr_valid) begin
                s_udp_hdr_ready_next = 1'b0;
                s_udp_payload_axis_tready_next = 1'b1;
                store_udp_hdr = 1'b1;
                state_next = STATE_READ_HEADER;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_HEADER: begin
            // read header
            s_udp_payload_axis_tready_next = shift_udp_payload_s_tready;

            if (s_udp_payload_axis_tready && s_udp_payload_axis_tvalid) begin
                // word transfer in - store it
                hdr_ptr_next = hdr_ptr_reg + 6'd8;
                transfer_in_save = 1'b1;
                state_next = STATE_READ_HEADER;

                case (hdr_ptr_reg)
                    6'h00: begin
                        store_hdr_word_0 = 1'b1;
                    end
                    6'h08: begin
                        store_hdr_word_1 = 1'b1;
                        word_count_next = {s_udp_payload_axis_tdata[31:24], s_udp_payload_axis_tdata[39:32]};
                        s_udp_payload_axis_tready_next = m_dtls_payload_axis_tready_int_early && shift_udp_payload_s_tready;
                        // m_dtls_hdr_valid_next = 1'b1;
                        state_next = STATE_READ_PAYLOAD;
                        // if (m_dtls_version_reg != 16'hfefd) begin // DTLS 1.2 version is {254, 253}
                        //     error_invalid_header_next = 1'b1;
                        //     s_udp_payload_axis_tready_next = shift_udp_payload_s_tready;
                        //     state_next = STATE_WAIT_LAST;
                        // end else begin
                        //     s_udp_payload_axis_tready_next = m_dtls_payload_axis_tready_int_early && shift_udp_payload_s_tready;
                        //     state_next = STATE_READ_PAYLOAD;
                        // end
                    end
                endcase

                if (shift_udp_payload_axis_tlast) begin
                    error_header_early_termination_next = 1'b1;
                    error_invalid_header_next = 1'b0;
                    m_dtls_hdr_valid_next = 1'b0;
                    s_udp_hdr_ready_next = !m_dtls_hdr_valid_next;
                    s_udp_payload_axis_tready_next = 1'b0;
                    state_next = STATE_IDLE;
                end

            end else begin
                state_next = STATE_READ_HEADER;
            end
        end
        STATE_READ_PAYLOAD: begin
            // read payload
            s_udp_payload_axis_tready_next = m_dtls_payload_axis_tready_int_early && shift_udp_payload_s_tready;
            m_dtls_payload_axis_tdata_int = shift_udp_payload_axis_tdata;
            m_dtls_payload_axis_tkeep_int = shift_udp_payload_axis_tkeep;
            m_dtls_payload_axis_tlast_int = shift_udp_payload_axis_tlast;
            m_dtls_payload_axis_tuser_int = shift_udp_payload_axis_tuser;

            store_last_word = 1'b1;

            if (m_dtls_payload_axis_tready_int_reg && shift_udp_payload_axis_tvalid) begin
                // word transfer through
                word_count_next = word_count_reg - 16'd8;
                transfer_in_save = 1'b1;
                m_dtls_payload_axis_tvalid_int = 1'b1;
                if (word_count_reg <= (8 + 20)) begin // 20 bytes for sha hash
                    // have entire payload
                    m_dtls_payload_axis_tkeep_int = shift_udp_payload_axis_tkeep; // & count2keep(word_count_reg);
                    if (shift_udp_payload_axis_tlast) begin
                        if (keep2count(shift_udp_payload_axis_tkeep) < word_count_reg[4:0]) begin
                            // end of frame, but length does not match
                            error_payload_early_termination_next = 1'b1;
                            m_dtls_payload_axis_tuser_int = 1'b1;
                        end
                        s_udp_payload_axis_tready_next = 1'b0;
                        flush_save = 1'b1;
                        s_udp_hdr_ready_next = !m_dtls_hdr_valid_reg;
                        state_next = STATE_IDLE;
                    end else begin
                        m_dtls_payload_axis_tvalid_int = 1'b0;
                        state_next = STATE_READ_PAYLOAD_LAST;
                    end
                end else begin
                    if (shift_udp_payload_axis_tlast) begin
                        // end of frame, but length does not match
                        error_payload_early_termination_next = 1'b1;
                        m_dtls_payload_axis_tuser_int = 1'b1;
                        s_udp_payload_axis_tready_next = 1'b0;
                        flush_save = 1'b1;
                        s_udp_hdr_ready_next = !m_dtls_hdr_valid_reg;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_READ_PAYLOAD;
                    end
                end
            end else begin
                state_next = STATE_READ_PAYLOAD;
            end

        end
        STATE_READ_PAYLOAD_LAST: begin
            // read and discard until end of frame
            s_udp_payload_axis_tready_next = m_dtls_payload_axis_tready_int_early && shift_udp_payload_s_tready;

            m_dtls_payload_axis_tdata_int = last_word_data_reg;
            m_dtls_payload_axis_tkeep_int = last_word_keep_reg;
            m_dtls_payload_axis_tlast_int = shift_udp_payload_axis_tlast;
            m_dtls_payload_axis_tuser_int = shift_udp_payload_axis_tuser;

            if (m_dtls_payload_axis_tready_int_reg && shift_udp_payload_axis_tvalid) begin
                transfer_in_save = 1'b1;
                if (shift_udp_payload_axis_tlast) begin
                    s_udp_payload_axis_tready_next = 1'b0;
                    flush_save = 1'b1;
                    s_udp_hdr_ready_next = !m_dtls_hdr_valid_next;
                    m_dtls_payload_axis_tvalid_int = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_READ_PAYLOAD_LAST;
                end
            end else begin
                state_next = STATE_READ_PAYLOAD_LAST;
            end
        end
        STATE_WAIT_LAST: begin
            // read and discard until end of frame
            s_udp_payload_axis_tready_next = shift_udp_payload_s_tready;

            if (shift_udp_payload_axis_tvalid) begin
                transfer_in_save = 1'b1;
                if (shift_udp_payload_axis_tlast) begin
                    s_udp_payload_axis_tready_next = 1'b0;
                    flush_save = 1'b1;
                    s_udp_hdr_ready_next = !m_dtls_hdr_valid_next;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WAIT_LAST;
                end
            end else begin
                state_next = STATE_WAIT_LAST;
            end
        end
    endcase
end

always @(posedge clk) begin
    if (rst) begin
        state_reg <= STATE_IDLE;
        s_udp_hdr_ready_reg <= 1'b0;
        s_udp_payload_axis_tready_reg <= 1'b0;
        m_dtls_hdr_valid_reg <= 1'b0;
        save_udp_payload_axis_tlast_reg <= 1'b0;
        shift_udp_payload_extra_cycle_reg <= 1'b0;
        busy_reg <= 1'b0;
        error_header_early_termination_reg <= 1'b0;
        error_payload_early_termination_reg <= 1'b0;
        error_invalid_header_reg <= 1'b0;
        // error_invalid_checksum_reg <= 1'b0;
    end else begin
        state_reg <= state_next;

        s_udp_hdr_ready_reg <= s_udp_hdr_ready_next;
        s_udp_payload_axis_tready_reg <= s_udp_payload_axis_tready_next;

        m_dtls_hdr_valid_reg <= m_dtls_hdr_valid_next;

        error_header_early_termination_reg <= error_header_early_termination_next;
        error_payload_early_termination_reg <= error_payload_early_termination_next;
        error_invalid_header_reg <= error_invalid_header_next;
        // error_invalid_checksum_reg <= error_invalid_checksum_next;

        busy_reg <= state_next != STATE_IDLE;

        // datapath
        if (flush_save) begin
            save_udp_payload_axis_tlast_reg <= 1'b0;
            shift_udp_payload_extra_cycle_reg <= 1'b0;
        end else if (transfer_in_save) begin
            save_udp_payload_axis_tlast_reg <= s_udp_payload_axis_tlast;
            shift_udp_payload_extra_cycle_reg <= s_udp_payload_axis_tlast && (s_udp_payload_axis_tkeep[7:3] != 0);
        end
    end

    hdr_ptr_reg <= hdr_ptr_next;
    word_count_reg <= word_count_next;

    // datapath
    if (store_udp_hdr) begin
        m_eth_dest_mac_reg <= s_eth_dest_mac;
        m_eth_src_mac_reg <= s_eth_src_mac;
        m_eth_type_reg <= s_eth_type;
        m_ip_version_reg <= s_ip_version;
        m_ip_ihl_reg <= s_ip_ihl;
        m_ip_dscp_reg <= s_ip_dscp;
        m_ip_ecn_reg <= s_ip_ecn;
        m_ip_length_reg <= s_ip_length;
        m_ip_identification_reg <= s_ip_identification;
        m_ip_flags_reg <= s_ip_flags;
        m_ip_fragment_offset_reg <= s_ip_fragment_offset;
        m_ip_ttl_reg <= s_ip_ttl;
        m_ip_protocol_reg <= s_ip_protocol;
        m_ip_header_checksum_reg <= s_ip_header_checksum;
        m_ip_source_ip_reg <= s_ip_source_ip;
        m_ip_dest_ip_reg <= s_ip_dest_ip;
        m_udp_source_port_reg <= s_udp_source_port;
        m_udp_dest_port_reg <= s_udp_dest_port;
        m_udp_length_reg <= s_udp_length;
        m_udp_checksum_reg <= s_udp_checksum;
    end

    if (store_last_word) begin
        last_word_data_reg <= m_dtls_payload_axis_tdata_int;
        last_word_keep_reg <= m_dtls_payload_axis_tkeep_int;
    end

    if (store_hdr_word_0) begin
        m_dtls_type_reg <= s_udp_payload_axis_tdata[ 7: 0];
        m_dtls_version_reg[15: 0] <= s_udp_payload_axis_tdata[15: 8];
        m_dtls_version_reg[7: 0] <= s_udp_payload_axis_tdata[23:16];
        m_dtls_epoch_reg[15: 8] <= s_udp_payload_axis_tdata[31:24];
        m_dtls_epoch_reg[ 7: 0] <= s_udp_payload_axis_tdata[39:32];
        m_dtls_seqnum_reg[47:40] <= s_udp_payload_axis_tdata[47:40];
        m_dtls_seqnum_reg[39:32] <= s_udp_payload_axis_tdata[55:48];
        m_dtls_seqnum_reg[31:24] <= s_udp_payload_axis_tdata[63:56];
    end

    if (store_hdr_word_1) begin
        m_dtls_seqnum_reg[23:16] <= s_udp_payload_axis_tdata[ 7: 0];
        m_dtls_seqnum_reg[15: 8] <= s_udp_payload_axis_tdata[15: 8];
        m_dtls_seqnum_reg[ 7: 0] <= s_udp_payload_axis_tdata[23:16];
        m_dtls_length_reg[15: 8] <= s_udp_payload_axis_tdata[31:24];
        m_dtls_length_reg[ 7: 0] <= s_udp_payload_axis_tdata[39:32];
    end

    if (transfer_in_save) begin
        save_udp_payload_axis_tdata_reg <= s_udp_payload_axis_tdata;
        save_udp_payload_axis_tkeep_reg <= s_udp_payload_axis_tkeep;
        save_udp_payload_axis_tuser_reg <= s_udp_payload_axis_tuser;
    end
end

// output datapath logic
reg [63:0] m_dtls_payload_axis_tdata_reg = 64'd0;
reg [7:0]  m_dtls_payload_axis_tkeep_reg = 8'd0;
reg        m_dtls_payload_axis_tvalid_reg = 1'b0, m_dtls_payload_axis_tvalid_next;
reg        m_dtls_payload_axis_tlast_reg = 1'b0;
reg        m_dtls_payload_axis_tuser_reg = 1'b0;

reg [63:0] temp_m_dtls_payload_axis_tdata_reg = 64'd0;
reg [7:0]  temp_m_dtls_payload_axis_tkeep_reg = 8'd0;
reg        temp_m_dtls_payload_axis_tvalid_reg = 1'b0, temp_m_dtls_payload_axis_tvalid_next;
reg        temp_m_dtls_payload_axis_tlast_reg = 1'b0;
reg        temp_m_dtls_payload_axis_tuser_reg = 1'b0;

// datapath control
reg store_dtls_payload_int_to_output;
reg store_dtls_payload_int_to_temp;
reg store_dtls_payload_axis_temp_to_output;

assign m_dtls_payload_axis_tdata = m_dtls_payload_axis_tdata_reg;
assign m_dtls_payload_axis_tkeep = m_dtls_payload_axis_tkeep_reg;
assign m_dtls_payload_axis_tvalid = m_dtls_payload_axis_tvalid_reg;
assign m_dtls_payload_axis_tlast = m_dtls_payload_axis_tlast_reg;
assign m_dtls_payload_axis_tuser = m_dtls_payload_axis_tuser_reg;

// enable ready input next cycle if output is ready or if both output registers are empty
assign m_dtls_payload_axis_tready_int_early = m_dtls_payload_axis_tready || (!temp_m_dtls_payload_axis_tvalid_reg && !m_dtls_payload_axis_tvalid_reg);

always @* begin
    // transfer sink ready state to source
    m_dtls_payload_axis_tvalid_next = m_dtls_payload_axis_tvalid_reg;
    temp_m_dtls_payload_axis_tvalid_next = temp_m_dtls_payload_axis_tvalid_reg;

    store_dtls_payload_int_to_output = 1'b0;
    store_dtls_payload_int_to_temp = 1'b0;
    store_dtls_payload_axis_temp_to_output = 1'b0;
    
    if (m_dtls_payload_axis_tready_int_reg) begin
        // input is ready
        if (m_dtls_payload_axis_tready || !m_dtls_payload_axis_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_dtls_payload_axis_tvalid_next = m_dtls_payload_axis_tvalid_int;
            store_dtls_payload_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_dtls_payload_axis_tvalid_next = m_dtls_payload_axis_tvalid_int;
            store_dtls_payload_int_to_temp = 1'b1;
        end
    end else if (m_dtls_payload_axis_tready) begin
        // input is not ready, but output is ready
        m_dtls_payload_axis_tvalid_next = temp_m_dtls_payload_axis_tvalid_reg;
        temp_m_dtls_payload_axis_tvalid_next = 1'b0;
        store_dtls_payload_axis_temp_to_output = 1'b1;
    end
end

always @(posedge clk) begin
    m_dtls_payload_axis_tvalid_reg <= m_dtls_payload_axis_tvalid_next;
    m_dtls_payload_axis_tready_int_reg <= m_dtls_payload_axis_tready_int_early;
    temp_m_dtls_payload_axis_tvalid_reg <= temp_m_dtls_payload_axis_tvalid_next;

    // datapath
    if (store_dtls_payload_int_to_output) begin
        m_dtls_payload_axis_tdata_reg <= m_dtls_payload_axis_tdata_int;
        m_dtls_payload_axis_tkeep_reg <= m_dtls_payload_axis_tkeep_int;
        m_dtls_payload_axis_tlast_reg <= m_dtls_payload_axis_tlast_int;
        m_dtls_payload_axis_tuser_reg <= m_dtls_payload_axis_tuser_int;
    end else if (store_dtls_payload_axis_temp_to_output) begin
        m_dtls_payload_axis_tdata_reg <= temp_m_dtls_payload_axis_tdata_reg;
        m_dtls_payload_axis_tkeep_reg <= temp_m_dtls_payload_axis_tkeep_reg;
        m_dtls_payload_axis_tlast_reg <= temp_m_dtls_payload_axis_tlast_reg;
        m_dtls_payload_axis_tuser_reg <= temp_m_dtls_payload_axis_tuser_reg;
    end

    if (store_dtls_payload_int_to_temp) begin
        temp_m_dtls_payload_axis_tdata_reg <= m_dtls_payload_axis_tdata_int;
        temp_m_dtls_payload_axis_tkeep_reg <= m_dtls_payload_axis_tkeep_int;
        temp_m_dtls_payload_axis_tlast_reg <= m_dtls_payload_axis_tlast_int;
        temp_m_dtls_payload_axis_tuser_reg <= m_dtls_payload_axis_tuser_int;
    end

    if (rst) begin
        m_dtls_payload_axis_tvalid_reg <= 1'b0;
        m_dtls_payload_axis_tready_int_reg <= 1'b0;
        temp_m_dtls_payload_axis_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall

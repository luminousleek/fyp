`default_nettype none

module keyword_match_standalone
(
  // Clock and reset
  input wire         clk,
  input wire         reset, // active high reset

  // AXI input for text
  input  wire [63:0] s_axis_text_tdata,
  input  wire [7:0]  s_axis_text_tkeep,
  input  wire        s_axis_text_tvalid,
  output wire        s_axis_text_tready,
  input  wire        s_axis_text_tlast,
  input  wire        s_axis_text_tuser,

  // outputs for access control
  output wire        match_sig,
  output wire        no_match_sig,
  input  wire        ack
);

  // constant declarations
  reg [63:0] match_res_reg = 64'h000000686374614D; // "Match" in reverse because of how AXI stream works
  reg [63:0] no_match_res_reg = 64'h686374616D206F4E; // "No match" in reverse
  reg [127:0] keyword = 128'h626567696e6e696e6700000000000000; // "beginning"

  localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_MATCHING = 2'd1,
    STATE_MATCH_FOUND = 2'd2,
    STATE_NO_MATCH = 2'd3;

  reg [1:0] state_reg = STATE_IDLE, state_next;

  // datapath control signals
  reg [4:0] keyword_length;
  reg [127:0] reversed_kw;
  reg [4:0] bytes_matched_reg = 5'd0, bytes_matched_next;

  reg match_sig_reg = 1'b0, match_sig_next;
  reg no_match_sig_reg = 1'b0, no_match_sig_next;

  reg [63:0] lower_data;

  reg s_axis_text_tready_reg = 1'b0, s_axis_text_tready_next;

  // wires
  assign s_axis_text_tready = s_axis_text_tready_reg;
  assign match_sig = match_sig_reg;
  assign no_match_sig = no_match_sig_reg;

  // functions
  function [4:0] get_kw_len;
    input [127:0] kw;
    integer i;
    reg null_byte;
    begin
      i = 0;
      null_byte = 1'b0;
      while (i < 16 && !null_byte) begin // search for first null byte, i.e. 8'h00
        null_byte = kw[127 - i * 8 -: 8] == 8'h00;
        if (null_byte) begin
          get_kw_len = i;
        end
        i = i + 1;
      end
      if (!null_byte) begin
        get_kw_len = 5'd16;
      end
    end
  endfunction

  function [127:0] reverse_kw; // reverse byte order of keyword
    input [127:0] kw;
    integer i;
    for (i = 0; i < 16; i = i + 1) begin
      reverse_kw[i * 8 +: 8] = kw[127 - i * 8 -: 8];
    end
  endfunction

  function [63:0] to_lower; // convert string to lowercase
    input [63:0] data;
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      if (data[i * 8 +: 8] >= 8'h41 && data[i * 8 +: 8] <= 8'h5a) begin
        to_lower[i * 8 +: 8] = data[i * 8 +: 8] + 8'h20;
      end else begin
        to_lower[i * 8 +: 8] = data[i * 8 +: 8];
      end
    end
  endfunction

  function [4:0] find_first_matched_bytes; // finds how many of the initial bytes of the keyword is in the data
    input [63:0] data;
    input [127:0] kw;
    input [4:0] kw_len;
    integer i;
    integer j;
    reg match_found;
    reg curr_byte_match;
    begin
      match_found = 1'b0;
      find_first_matched_bytes = 5'b0;
      i = 0;
      while (i < 8 && !match_found) begin
        j = 0;
        curr_byte_match = 1'b1;
        while (j < 8 - i && curr_byte_match && j < 8 && j < kw_len) begin
          curr_byte_match = data[(i + j) * 8 +: 8] == kw[j * 8 +: 8];
          if (curr_byte_match && j == kw_len - 1) begin
            match_found = 1'b1;
            find_first_matched_bytes = kw_len;
          end else if (curr_byte_match && j == 8 - i - 1) begin
            match_found = 1'b1;
            find_first_matched_bytes = j + 1;
          end
          j = j + 1;
        end
        i = i + 1;
      end
    end
  endfunction

  function middle_bytes_match;
    input [63:0] data;
    input [127:0] kw;
    input [4:0] bytes_matched;
    integer i;
    reg match;
    middle_bytes_match = data == kw[bytes_matched * 8 +: 64];
  endfunction

  function last_bytes_match;
    input [63:0] data;
    input [127:0] kw;
    input [4:0] kw_len;
    input [4:0] bytes_matched;
    integer i;
    reg match;
    begin
      i = 0;
      match = 1'b1;
      while (i < kw_len - bytes_matched && match && i < 8) begin
        match = data[i * 8 +: 8] == kw[(bytes_matched + i) * 8 +: 8];
        i = i + 1;
      end
      last_bytes_match = match;
    end
  endfunction

  // FSM
  always @* begin
    state_next = STATE_IDLE;
    s_axis_text_tready_next = 1'b0;

    bytes_matched_next = bytes_matched_reg;
    match_sig_next = match_sig_reg;
    no_match_sig_next = no_match_sig_reg;

    case (state_reg)
      STATE_IDLE: begin
        if (s_axis_text_tvalid) begin
          s_axis_text_tready_next = 1'b1;
          bytes_matched_next = 5'd0;
          keyword_length = get_kw_len(keyword);
          reversed_kw = reverse_kw(keyword);
          match_sig_next = 1'b0;
          no_match_sig_next = 1'b0;
          state_next = STATE_MATCHING;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_MATCHING: begin
        if (s_axis_text_tvalid && s_axis_text_tready) begin
          s_axis_text_tready_next = 1'b1;
          lower_data = to_lower(s_axis_text_tdata);
          if (bytes_matched_reg > 0) begin 
            if (keyword_length - bytes_matched_reg <= 8) begin // end of keyword in this data word
              if (last_bytes_match(lower_data, reversed_kw, keyword_length, bytes_matched_reg)) begin
                bytes_matched_next = 5'd0;
                match_sig_next = 1'b1;
                state_next = STATE_MATCH_FOUND;
              end else begin
                bytes_matched_next = find_first_matched_bytes(lower_data, reversed_kw, keyword_length);
                if (bytes_matched_next == keyword_length) begin
                  bytes_matched_next = 5'd0;
                  match_sig_next = 1'b1;
                  state_next = STATE_MATCH_FOUND;
                end else begin
                  state_next = STATE_MATCHING;
                end
              end
            end else begin // keyword spans to the next data word, see if this data word matches
              if (middle_bytes_match(lower_data, reversed_kw, bytes_matched_reg)) begin
                bytes_matched_next = bytes_matched_reg + 8;
              end else begin
                // no need to check if bytes_matched_next == keyword_length because keyword_length > 8 so won't fit into a data word
                bytes_matched_next = find_first_matched_bytes(lower_data, reversed_kw, keyword_length);
              end
              state_next = STATE_MATCHING;
            end
          end else begin
            bytes_matched_next = find_first_matched_bytes(lower_data, reversed_kw, keyword_length);
            if (bytes_matched_next == keyword_length) begin
              bytes_matched_next = 5'd0;
              match_sig_next = 1'b1;
              state_next = STATE_MATCH_FOUND;
            end else begin
              state_next = STATE_MATCHING;
            end
          end
          if (s_axis_text_tlast && state_next != STATE_MATCH_FOUND) begin
            s_axis_text_tready_next = 1'b0;
            no_match_sig_next = 1'b1;
            state_next = STATE_NO_MATCH;
          end
        end else begin
          s_axis_text_tready_next = 1'b1;
          state_next = STATE_MATCHING;
        end
      end
      STATE_MATCH_FOUND: begin // discard incoming data until tlast is asserted
        if (ack) begin
          match_sig_next = 1'b0;
        end else begin
          match_sig_next = match_sig_reg;
        end
        if (s_axis_text_tlast) begin
          s_axis_text_tready_next = 1'b0;
          match_sig_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          s_axis_text_tready_next = 1'b1;
          state_next = STATE_MATCH_FOUND;
        end
      end
      STATE_NO_MATCH: begin
        if (ack) begin
          no_match_sig_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          state_next = STATE_NO_MATCH;
        end
      end
      default: begin
        state_next = STATE_IDLE;
      end
    endcase
  end

  // Register update
  always @(posedge clk) begin
    if (reset) begin
      state_reg <= STATE_IDLE;
      s_axis_text_tready_reg <= 1'b0;
      bytes_matched_reg <= 5'd0;
      match_sig_reg <= 1'b0;
      no_match_sig_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      s_axis_text_tready_reg <= s_axis_text_tready_next;
      bytes_matched_reg <= bytes_matched_next;
      match_sig_reg <= match_sig_next;
      no_match_sig_reg <= no_match_sig_next;
    end
  end

endmodule

`resetall

`default_nettype none

module keyword_match
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

  // AXI output for result
  output wire [63:0] m_axis_res_tdata,
  output wire [7:0]  m_axis_res_tkeep,
  output wire        m_axis_res_tvalid,
  input  wire        m_axis_res_tready,
  output wire        m_axis_res_tlast,
  output wire        m_axis_res_tuser
);

  // constant declarations
  reg [63:0] match_res_reg = 64'h000000686374614D; // "Match" in reverse because of how AXI stream works
  reg [63:0] no_match_res_reg = 64'h686374616D206F4E; // "No match" in reverse
  reg [127:0] keyword = 128'h626567696e6e696e6700000000000000; // "beginning"

  localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_MATCHING = 3'd1,
    STATE_MATCH_FOUND = 3'd2,
    STATE_NO_MATCH = 3'd3,
    STATE_WAIT_LAST = 3'd4;

  reg [2:0] state_reg = STATE_IDLE, state_next;

  // datapath control signals
  reg [4:0] keyword_length;
  reg [127:0] reversed_kw;
  reg [4:0] bytes_matched_reg = 5'd0, bytes_matched_next;

  // reg match_found_reg = 1'b0, match_found_next;
  reg [63:0] lower_data;

  reg s_axis_text_tready_reg = 1'b0, s_axis_text_tready_next;

  // internal datapath
  reg [63:0] m_axis_res_tdata_int;
  reg [7:0]  m_axis_res_tkeep_int;
  reg        m_axis_res_tvalid_int;
  reg        m_axis_res_tlast_int;
  reg        m_axis_res_tuser_int;

  // wires
  assign s_axis_text_tready = s_axis_text_tready_reg;

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
    // begin
    //   i = 0;
    //   match = 1'b1;
    //   while (i < 8 && match) begin
    //     match = data[i * 8 +: 8] == kw[(bytes_matched + i) * 8 +: 8];
    //     i = i + 1;
    //   end
    //   middle_bytes_match = match;
    // end
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

    m_axis_res_tdata_int = 64'd0;
    m_axis_res_tkeep_int = 8'd0;
    m_axis_res_tvalid_int = 1'b0;
    m_axis_res_tlast_int = 1'b0;
    m_axis_res_tuser_int = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        if (s_axis_text_tvalid) begin
          s_axis_text_tready_next = 1'b1;
          bytes_matched_next = 5'd0;
          keyword_length = get_kw_len(keyword);
          reversed_kw = reverse_kw(keyword);
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
                state_next = STATE_MATCH_FOUND;
              end else begin
                bytes_matched_next = find_first_matched_bytes(lower_data, reversed_kw, keyword_length);
                if (bytes_matched_next == keyword_length) begin
                  bytes_matched_next = 5'd0;
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
              state_next = STATE_MATCH_FOUND;
            end else begin
              state_next = STATE_MATCHING;
            end
          end
          if (s_axis_text_tlast && state_next != STATE_MATCH_FOUND) begin
            s_axis_text_tready_next = 1'b0;
            state_next = STATE_NO_MATCH;
          end
        end else begin
          s_axis_text_tready_next = 1'b1;
          state_next = STATE_MATCHING;
        end
      end
      STATE_MATCH_FOUND: begin
        m_axis_res_tdata_int = match_res_reg;
        m_axis_res_tkeep_int = 8'b11111111;
        m_axis_res_tvalid_int = 1'b1;
        m_axis_res_tlast_int = 1'b1;
        m_axis_res_tuser_int = 1'b0;
        if (s_axis_text_tlast) begin
          s_axis_text_tready_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          s_axis_text_tready_next = 1'b1;
          state_next = STATE_WAIT_LAST;
        end
      end
      STATE_NO_MATCH: begin
        m_axis_res_tdata_int = no_match_res_reg;
        m_axis_res_tkeep_int = 8'b11111111;
        m_axis_res_tvalid_int = 1'b1;
        m_axis_res_tlast_int = 1'b1;
        m_axis_res_tuser_int = 1'b0;
        state_next = STATE_IDLE;
      end
      STATE_WAIT_LAST: begin // discard incoming data until tlast is asserted
        if (s_axis_text_tlast) begin
          s_axis_text_tready_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          s_axis_text_tready_next = 1'b1;
          state_next = STATE_WAIT_LAST;
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
    end else begin
      state_reg <= state_next;
      s_axis_text_tready_reg <= s_axis_text_tready_next;
      bytes_matched_reg <= bytes_matched_next;
    end
  end

  // output datapath logic
  reg [63:0] m_axis_res_tdata_reg = 64'd0;
  reg [7:0]  m_axis_res_tkeep_reg = 8'd0;
  reg        m_axis_res_tvalid_reg = 1'b0, m_axis_res_tvalid_next;
  reg        m_axis_res_tlast_reg = 1'b0;
  reg        m_axis_res_tuser_reg = 1'b0;

  reg [63:0] temp_m_axis_res_tdata_reg = 64'd0;
  reg [7:0]  temp_m_axis_res_tkeep_reg = 8'd0;
  reg        temp_m_axis_res_tvalid_reg = 1'b0, temp_m_axis_res_tvalid_next;
  reg        temp_m_axis_res_tlast_reg = 1'b0;
  reg        temp_m_axis_res_tuser_reg = 1'b0;

  // datapath control
  reg store_res_int_to_output;
  reg store_res_int_to_temp;
  reg store_axis_res_temp_to_output;

  assign m_axis_res_tdata = m_axis_res_tdata_reg;
  assign m_axis_res_tkeep = m_axis_res_tkeep_reg;
  assign m_axis_res_tvalid = m_axis_res_tvalid_reg;
  assign m_axis_res_tlast = m_axis_res_tlast_reg;
  assign m_axis_res_tuser = m_axis_res_tuser_reg;

  always @* begin
      // transfer sink ready state to source
      m_axis_res_tvalid_next = m_axis_res_tvalid_reg;
      temp_m_axis_res_tvalid_next = temp_m_axis_res_tvalid_reg;

      store_res_int_to_output = 1'b0;
      store_res_int_to_temp = 1'b0;
      store_axis_res_temp_to_output = 1'b0;
      
      if (m_axis_res_tready || !m_axis_res_tvalid_reg) begin
          // output is ready or currently not valid, transfer data to output
          m_axis_res_tvalid_next = m_axis_res_tvalid_int;
          store_res_int_to_output = 1'b1;
      end else begin
          // output is not ready, store input in temp
          temp_m_axis_res_tvalid_next = m_axis_res_tvalid_int;
          store_res_int_to_temp = 1'b1;
      end
  end

  always @(posedge clk) begin
      m_axis_res_tvalid_reg <= m_axis_res_tvalid_next;
      temp_m_axis_res_tvalid_reg <= temp_m_axis_res_tvalid_next;

      // datapath
      if (store_res_int_to_output) begin
          m_axis_res_tdata_reg <= m_axis_res_tdata_int;
          m_axis_res_tkeep_reg <= m_axis_res_tkeep_int;
          m_axis_res_tlast_reg <= m_axis_res_tlast_int;
          m_axis_res_tuser_reg <= m_axis_res_tuser_int;
      end else if (store_axis_res_temp_to_output) begin
          m_axis_res_tdata_reg <= temp_m_axis_res_tdata_reg;
          m_axis_res_tkeep_reg <= temp_m_axis_res_tkeep_reg;
          m_axis_res_tlast_reg <= temp_m_axis_res_tlast_reg;
          m_axis_res_tuser_reg <= temp_m_axis_res_tuser_reg;
      end

      if (store_res_int_to_temp) begin
          temp_m_axis_res_tdata_reg <= m_axis_res_tdata_int;
          temp_m_axis_res_tkeep_reg <= m_axis_res_tkeep_int;
          temp_m_axis_res_tlast_reg <= m_axis_res_tlast_int;
          temp_m_axis_res_tuser_reg <= m_axis_res_tuser_int;
      end

      if (reset) begin
          m_axis_res_tvalid_reg <= 1'b0;
          temp_m_axis_res_tvalid_reg <= 1'b0;
      end
  end

endmodule

`resetall

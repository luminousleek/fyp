`resetall
`default_nettype none

// remove last x bytes of dtls payload

module dtls_remove_last_bytes
(
  input wire clk,
  input wire rst,

  input  wire        s_dtls_hdr_valid,
  input  wire [15:0] s_dtls_length,
  input  wire [63:0] s_dtls_payload_axis_tdata,
  input  wire [7:0]  s_dtls_payload_axis_tkeep,
  input  wire        s_dtls_payload_axis_tvalid,
  output wire        s_dtls_payload_axis_tready,
  input  wire        s_dtls_payload_axis_tlast,
  input  wire        s_dtls_payload_axis_tuser,

  output wire [63:0] m_dtls_payload_axis_tdata,
  output wire [7:0]  m_dtls_payload_axis_tkeep,
  output wire        m_dtls_payload_axis_tvalid,
  input  wire        m_dtls_payload_axis_tready,
  output wire        m_dtls_payload_axis_tlast,
  output wire        m_dtls_payload_axis_tuser
);

  localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_READ_PAYLOAD = 2'd1,
    STATE_WAIT_LAST = 2'd2;

  localparam BYTES_TO_REMOVE = 32;

  reg [1:0] state_reg = STATE_IDLE, state_next;

  reg [15:0] word_count_reg = 16'd0, word_count_next;
  reg s_dtls_payload_axis_tready_reg = 1'b0, s_dtls_payload_axis_tready_next;

  assign s_dtls_payload_axis_tready = s_dtls_payload_axis_tready_reg;

  // internal datapath
  reg [63:0] m_dtls_payload_axis_tdata_int;
  reg [7:0]  m_dtls_payload_axis_tkeep_int;
  reg        m_dtls_payload_axis_tvalid_int;
  reg        m_dtls_payload_axis_tready_int_reg = 1'b0;
  reg        m_dtls_payload_axis_tlast_int;
  reg        m_dtls_payload_axis_tuser_int;

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

  // FSM
  always @* begin
    state_next = STATE_IDLE;
    s_dtls_payload_axis_tready_next = 1'b0;
    word_count_next = word_count_reg;

    m_dtls_payload_axis_tdata_int = 64'd0;
    m_dtls_payload_axis_tkeep_int = 8'd0;
    m_dtls_payload_axis_tvalid_int = 1'b0;
    m_dtls_payload_axis_tlast_int = 1'b0;
    m_dtls_payload_axis_tuser_int = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        if (s_dtls_hdr_valid) begin
          s_dtls_payload_axis_tready_next = 1'b1;
          word_count_next = s_dtls_length;
          state_next = STATE_READ_PAYLOAD;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_READ_PAYLOAD: begin
        if (s_dtls_payload_axis_tvalid && s_dtls_payload_axis_tready) begin
          word_count_next = word_count_reg - 16'd8;
          s_dtls_payload_axis_tready_next = 1'b1;
          m_dtls_payload_axis_tdata_int = s_dtls_payload_axis_tdata;
          m_dtls_payload_axis_tkeep_int = s_dtls_payload_axis_tkeep;
          m_dtls_payload_axis_tvalid_int = s_dtls_payload_axis_tvalid;
          m_dtls_payload_axis_tlast_int = s_dtls_payload_axis_tlast;
          m_dtls_payload_axis_tuser_int = s_dtls_payload_axis_tuser;
          if (word_count_reg <= BYTES_TO_REMOVE + 8) begin
            m_dtls_payload_axis_tkeep_int = s_dtls_payload_axis_tkeep & count2keep(word_count_reg - BYTES_TO_REMOVE);
            m_dtls_payload_axis_tlast_int = 1'b1;
            state_next = STATE_WAIT_LAST;
          end else begin
            state_next = STATE_READ_PAYLOAD;
          end
        end else begin
          s_dtls_payload_axis_tready_next = 1'b1;
          state_next = STATE_READ_PAYLOAD;
        end
      end
      STATE_WAIT_LAST: begin
        if (s_dtls_payload_axis_tvalid && s_dtls_payload_axis_tready) begin
          // read and discard until end of frame
          if (s_dtls_payload_axis_tlast) begin
            s_dtls_payload_axis_tready_next = 1'b0;
            state_next = STATE_IDLE;
          end else begin
            s_dtls_payload_axis_tready_next = 1'b1;
            state_next = STATE_WAIT_LAST;
          end
        end
      end
      default: begin
      end
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      state_reg <= STATE_IDLE;
      s_dtls_payload_axis_tready_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      s_dtls_payload_axis_tready_reg <= s_dtls_payload_axis_tready_next;
    end

    word_count_reg <= word_count_next;
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

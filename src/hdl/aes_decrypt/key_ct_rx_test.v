`default_nettype none

module key_ct_rx_test
(
  // Clock and reset
  input wire         clk,
  input wire         reset_n, // active low reset

  // AXI input for key
  input  wire [31:0] s_axis_key_tdata,
  input  wire [3:0]  s_axis_key_tkeep,
  input  wire        s_axis_key_tvalid,
  output wire        s_axis_key_tready,
  input  wire        s_axis_key_tlast,
  input  wire        s_axis_key_tuser,

  // AXI input for ciphertext
  input  wire [31:0] s_axis_ct_tdata,
  input  wire [3:0]  s_axis_ct_tkeep,
  input  wire        s_axis_ct_tvalid,
  output wire        s_axis_ct_tready,
  input  wire        s_axis_ct_tlast,
  input  wire        s_axis_ct_tuser,

  // AXI output
  output wire [31:0] m_axis_tdata,
  output wire [3:0]  m_axis_tkeep,
  output wire        m_axis_tvalid,
  input  wire        m_axis_tready,
  output wire        m_axis_tlast,
  output wire        m_axis_tuser
);

  localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_READ_KEY = 3'd1,
    STATE_WAIT_PAYLOAD = 3'd2,
    STATE_READ_CIPHERTEXT = 3'd3;

  reg [2:0] state_reg = STATE_IDLE, state_next;

  reg [2:0] key_word_reg = 3'b0, key_word_next;

  reg s_axis_key_tready_reg, s_axis_key_tready_next;
  reg s_axis_ct_tready_reg, s_axis_ct_tready_next;

  assign s_axis_key_tready = s_axis_key_tready_reg;
  assign s_axis_ct_tready = s_axis_ct_tready_reg;

  // internal datapath
  reg [31:0] m_axis_tdata_int;
  reg [3:0]  m_axis_tkeep_int;
  reg        m_axis_tvalid_int;
  reg        m_axis_tlast_int;
  reg        m_axis_tuser_int;

  // FSM
  always @* begin
    state_next = STATE_IDLE;
    s_axis_key_tready_next = 1'b0;
    s_axis_ct_tready_next = 1'b0;

    key_word_next = key_word_reg;

    m_axis_tdata_int = 32'd0;
    m_axis_tkeep_int = 4'd0;
    m_axis_tvalid_int = 1'b0;
    m_axis_tlast_int = 1'b0;
    m_axis_tuser_int = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        if (s_axis_key_tvalid) begin
          s_axis_key_tready_next = 1'b1;
          key_word_next = 3'b0;
          state_next = STATE_READ_KEY;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_READ_KEY: begin
        if (s_axis_key_tvalid && s_axis_key_tready) begin
          key_word_next = key_word_reg + 3'd1;
          s_axis_key_tready_next = 1'b1;
          m_axis_tdata_int = s_axis_key_tdata;
          m_axis_tkeep_int = s_axis_key_tkeep;
          m_axis_tvalid_int = s_axis_key_tvalid;
          m_axis_tlast_int = 1'b0;
          m_axis_tuser_int = s_axis_key_tuser;
          if (key_word_reg == 3'd3) begin // have full key
            state_next = STATE_WAIT_PAYLOAD;
            s_axis_key_tready_next = 1'b0;
          end else begin
            state_next = STATE_READ_KEY;
          end
        end else begin
          s_axis_key_tready_next = 1'b1;
          state_next = STATE_READ_KEY;
        end
      end
      STATE_WAIT_PAYLOAD: begin
        if (s_axis_ct_tvalid) begin
          s_axis_ct_tready_next = 1;
          state_next = STATE_READ_CIPHERTEXT;
        end else begin
          state_next = STATE_WAIT_PAYLOAD;
        end
      end
      STATE_READ_CIPHERTEXT: begin
        if (s_axis_ct_tvalid && s_axis_ct_tready) begin
          s_axis_ct_tready_next = 1'b1;
          m_axis_tdata_int = s_axis_ct_tdata;
          m_axis_tkeep_int = s_axis_ct_tkeep;
          m_axis_tvalid_int = s_axis_ct_tvalid;
          m_axis_tlast_int = s_axis_ct_tlast;
          m_axis_tuser_int = s_axis_ct_tuser;
          if (s_axis_ct_tlast) begin
            s_axis_ct_tready_next = 1'b0;
            state_next = STATE_IDLE;
          end else begin
            state_next = STATE_READ_CIPHERTEXT;
          end
        end
      end
      default: begin
        state_next = STATE_IDLE;
      end
    endcase 
  end

  // Register update
  always @(posedge clk) begin
    if (!reset_n) begin
      state_reg <= STATE_IDLE;
      s_axis_key_tready_reg <= 1'b0;
      s_axis_ct_tready_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      s_axis_key_tready_reg <= s_axis_key_tready_next;
      s_axis_ct_tready_reg <= s_axis_ct_tready_next;
    end

    key_word_reg <= key_word_next;
  end

  // output datapath logic
  reg [31:0] m_axis_tdata_reg = 32'd0;
  reg [3:0]  m_axis_tkeep_reg = 4'd0;
  reg        m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
  reg        m_axis_tlast_reg = 1'b0;
  reg        m_axis_tuser_reg = 1'b0;

  reg [31:0] temp_m_axis_tdata_reg = 32'd0;
  reg [3:0]  temp_m_axis_tkeep_reg = 4'd0;
  reg        temp_m_axis_tvalid_reg = 1'b0, temp_m_axis_tvalid_next;
  reg        temp_m_axis_tlast_reg = 1'b0;
  reg        temp_m_axis_tuser_reg = 1'b0;

  // datapath control
  reg store_int_to_output;
  reg store_int_to_temp;
  reg store_axis_temp_to_output;

  assign m_axis_tdata = m_axis_tdata_reg;
  assign m_axis_tkeep = m_axis_tkeep_reg;
  assign m_axis_tvalid = m_axis_tvalid_reg;
  assign m_axis_tlast = m_axis_tlast_reg;
  assign m_axis_tuser = m_axis_tuser_reg;

  always @* begin 
    // transfer sink ready state to source
    m_axis_tvalid_next = m_axis_tvalid_reg;
    temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

    store_int_to_output = 1'b0;
    store_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;
    
    if (m_axis_tready || !m_axis_tvalid_reg) begin
      // output is ready or not valid, transfer data to output
      m_axis_tvalid_next = m_axis_tvalid_int;
      store_int_to_output = 1'b1;
    end else begin
      // output is not ready, store input in temp
      temp_m_axis_tvalid_next = m_axis_tvalid_int;
      store_int_to_temp = 1'b1;
    end
  end

  always @(posedge clk) begin
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;

    // datapath
    if (store_int_to_output) begin
      m_axis_tdata_reg <= m_axis_tdata_int;
      m_axis_tkeep_reg <= m_axis_tkeep_int;
      m_axis_tlast_reg <= m_axis_tlast_int;
      m_axis_tuser_reg <= m_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
      m_axis_tdata_reg <= temp_m_axis_tdata_reg;
      m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
      m_axis_tlast_reg <= temp_m_axis_tlast_reg;
      m_axis_tuser_reg <= temp_m_axis_tuser_reg;;
    end

    if (store_int_to_temp) begin
      temp_m_axis_tdata_reg <= m_axis_tdata_int;
      temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
      temp_m_axis_tlast_reg <= m_axis_tlast_int;
      temp_m_axis_tuser_reg <= m_axis_tuser_int;
    end

    if (!reset_n) begin
      m_axis_tvalid_reg <= 1'b0;
      temp_m_axis_tvalid_reg <= 1'b0;
    end
  end

endmodule

`resetall

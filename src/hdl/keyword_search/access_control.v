`default_nettype none

module access_control
(
  input  wire clk,
  input  wire reset,

  input  wire allow_sig,
  input  wire deny_sig,
  output wire ack,

  // AXI input
  input  wire [63:0] s_axis_tdata,
  input  wire [7:0]  s_axis_tkeep,
  input  wire        s_axis_tvalid,
  output wire        s_axis_tready,
  input  wire        s_axis_tlast,
  input  wire        s_axis_tuser,

  // AXI output
  output wire [63:0] m_axis_tdata,
  output wire [7:0]  m_axis_tkeep,
  output wire        m_axis_tvalid,
  input  wire        m_axis_tready,
  output wire        m_axis_tlast,
  output wire        m_axis_tuser
)

localparam [1:0]
  STATE_IDLE = 2'b0,
  STATE_ALLOW = 2'b1,
  STATE_DENY = 2'b2;

reg [7:0] dropped_msg_reg = 64'h00646570706F7244; // "Dropped" backwards

reg [1:0] state_reg = STATE_IDLE, state_next;
reg s_axis_tready_reg, s_axis_tready_next;
reg ack_reg, ack_next;

assign s_axis_tready = s_axis_tready_reg;
assign ack = ack_reg;

// internal datapath
reg [63:0] m_axis_tdata_int;
reg [7:0]  m_axis_tkeep_int;
reg        m_axis_tvalid_int;
reg        m_axis_tlast_int;
reg        m_axis_tuser_int;

// FSM
always @* begin
  state_next = STATE_IDLE;
  s_axis_tready_reg = 1'b0;
  ack_next = 1'b0;

  m_axis_tdata_int = 64'd0;
  m_axis_tkeep_int = 8'd0;
  m_axis_tvalid_int = 1'b0;
  m_axis_tlast_int = 1'b0;
  m_axis_tuser_int = 1'b0;

  case (state_reg)
    STATE_IDLE: begin
      if (allow_sig) begin
        ack_next = 1'b1;
        s_axis_tready_next = 1'b1;
        state_next = STATE_ALLOW;
      end else if (deny_sig) begin
        ack_next = 1'b1;
        s_axis_tready_next = 1'b1;
        state_next = STATE_DENY;
      end else begin
        state_next = STATE_IDLE;
      end
    end
    STATE_ALLOW: begin
      if (s_axis_tvalid && s_axis_tready) begin
        s_axis_tready_next = 1'b1;

        m_axis_tdata_int = s_axis_tdata;
        m_axis_tkeep_int = s_axis_tkeep;
        m_axis_tvalid_int = s_axis_tvalid;
        m_axis_tlast_int = s_axis_tlast;
        m_axis_tuser_int = s_axis_tuser;

        state_next = STATE_ALLOW;

        if (s_axis_tlast) begin
          s_axis_tready_next = 1'b0;
          state_next = STATE_IDLE;
        end
      end else begin
        s_axis_tready_next = 1'b1;
        state_next = STATE_ALLOW;
      end
    end
    STATE_DENY: begin
      if (s_axis_tvalid && s_axis_tready) begin
        // discard message
        s_axis_tready_next = 1'b1;
        state_next = STATE_DENY;

        if (s_axis_tlast) begin
          // send dropped message
          m_axis_tdata_int = dropped_msg_reg;
          m_axis_tkeep_int = 8'b11111111;
          m_axis_tvalid_int = 1'b1;
          m_axis_tlast_int = 1'b1;
          m_axis_tuser_int = 1'b0;

          s_axis_tready_next = 1'b0;
          state_next = STATE_IDLE;
        end
      end else begin
        s_axis_tready_next = 1'b1;
        state_next = STATE_DENY;
      end
    end
  endcase
end

// Register update
always @(posedge clk) begin
  if (reset) begin
    state_reg <= STATE_IDLE;
    s_axis_tready_reg <= 1'b0;
    ack_reg <= 1'b0;
  end else begin
    state_reg <= state_next;
    s_axis_tready_reg <= s_axis_tready_next;
    ack_reg <= ack_next;
  end
end

// output datapath logic
reg [63:0] m_axis_tdata_reg = 64'd0;
reg [7:0]  m_axis_tkeep_reg = 8'd0;
reg        m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
reg        m_axis_tlast_reg = 1'b0;
reg        m_axis_tuser_reg = 1'b0;

reg [63:0] temp_m_axis_tdata_reg = 64'd0;
reg [7:0]  temp_m_axis_tkeep_reg = 8'd0;
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

`default_nettype none

module keyword_match_parallel_top
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
  output wire        allow_sig,
  output wire        deny_sig,
  input  wire        ack
);

  // constant declarations
  reg [127:0] kw_0 = 128'h626567696e6e696e6700000000000000; // "beginning"
  reg [127:0] kw_1 = 128'h6A757374696669636174696F6E000000; // "justification"
  reg [127:0] kw_2 = 128'b0;
  reg [127:0] kw_3 = 128'b0;

  localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_MATCHING = 2'd1,
    STATE_MATCH_FOUND = 2'd2,
    STATE_NO_MATCH = 2'd3;

  reg [1:0] state_reg = STATE_IDLE, state_next;

  // datapath control signals
  reg allow_sig_out_reg = 1'b0, allow_sig_out_next;
  reg deny_sig_out_reg = 1'b0, deny_sig_out_next;
  reg ack_0_reg = 1'b0, ack_0_next;
  reg ack_1_reg = 1'b0, ack_1_next;
  reg ack_2_reg = 1'b0, ack_2_next;
  reg ack_3_reg = 1'b0, ack_3_next;

  reg last_reg = 1'b0, last_next;

  wire allow_0;
  wire allow_1;
  wire allow_2;
  wire allow_3;
  wire deny_0;
  wire deny_1;
  wire deny_2;
  wire deny_3;
  wire ack_0;
  wire ack_1;
  wire ack_2;
  wire ack_3;
  wire s_axis_tready_0;
  wire s_axis_tready_1;
  wire s_axis_tready_2;
  wire s_axis_tready_3;

  reg s_axis_text_tready_reg = 1'b0, s_axis_text_tready_next;

  // wires
  assign s_axis_text_tready = s_axis_text_tready_reg;
  assign allow_sig = allow_sig_out_reg;
  assign deny_sig = deny_sig_out_reg;
  assign ack_0 = ack_0_reg;
  assign ack_1 = ack_1_reg;
  assign ack_2 = ack_2_reg;
  assign ack_3 = ack_3_reg;

  // instantiate keyword search cores
  keyword_match_parallel kw_match_inst_0 (
    .clk(clk),
    .reset(reset),

    .keyword(kw_0),

    .s_axis_text_tdata(s_axis_text_tdata),
    .s_axis_text_tkeep(s_axis_text_tkeep),
    .s_axis_text_tvalid(s_axis_text_tvalid),
    .s_axis_text_tready(s_axis_tready_0),
    .s_axis_text_tlast(s_axis_text_tlast),
    .s_axis_text_tuser(s_axis_text_tuser),

    .allow_sig(allow_0),
    .deny_sig(deny_0),
    .ack(ack_0)
  );

  keyword_match_parallel kw_match_inst_1 (
    .clk(clk),
    .reset(reset),

    .keyword(kw_1),

    .s_axis_text_tdata(s_axis_text_tdata),
    .s_axis_text_tkeep(s_axis_text_tkeep),
    .s_axis_text_tvalid(s_axis_text_tvalid),
    .s_axis_text_tready(s_axis_tready_1),
    .s_axis_text_tlast(s_axis_text_tlast),
    .s_axis_text_tuser(s_axis_text_tuser),

    .allow_sig(allow_1),
    .deny_sig(deny_1),
    .ack(ack_1)
  );

  keyword_match_parallel kw_match_inst_2 (
    .clk(clk),
    .reset(reset),

    .keyword(kw_2),

    .s_axis_text_tdata(s_axis_text_tdata),
    .s_axis_text_tkeep(s_axis_text_tkeep),
    .s_axis_text_tvalid(s_axis_text_tvalid),
    .s_axis_text_tready(s_axis_tready_2),
    .s_axis_text_tlast(s_axis_text_tlast),
    .s_axis_text_tuser(s_axis_text_tuser),

    .allow_sig(allow_2),
    .deny_sig(deny_2),
    .ack(ack_2)
  );

  keyword_match_parallel kw_match_inst_3 (
    .clk(clk),
    .reset(reset),

    .keyword(kw_3),

    .s_axis_text_tdata(s_axis_text_tdata),
    .s_axis_text_tkeep(s_axis_text_tkeep),
    .s_axis_text_tvalid(s_axis_text_tvalid),
    .s_axis_text_tready(s_axis_tready_3),
    .s_axis_text_tlast(s_axis_text_tlast),
    .s_axis_text_tuser(s_axis_text_tuser),

    .allow_sig(allow_3),
    .deny_sig(deny_3),
    .ack(ack_3)
  );

  // FSM
  always @* begin
    state_next = STATE_IDLE;
    s_axis_text_tready_next = s_axis_tready_0 & s_axis_tready_1 
                            & s_axis_tready_2 & s_axis_tready_3;

    last_next = last_reg;
    allow_sig_out_next = allow_sig_out_reg;
    deny_sig_out_next = deny_sig_out_reg;
    ack_0_next = ack_0_reg;
    ack_1_next = ack_1_reg;
    ack_2_next = ack_2_reg;
    ack_3_next = ack_3_reg;

    case (state_reg)
      STATE_IDLE: begin
        ack_0_next = 1'b0;
        ack_1_next = 1'b0;
        ack_2_next = 1'b0;
        ack_3_next = 1'b0;
        allow_sig_out_next = 1'b0;
        deny_sig_out_next = 1'b0;
        last_next = last_reg;
        if (s_axis_text_tvalid) begin
          state_next = STATE_MATCHING;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_MATCHING: begin
        if (s_axis_text_tlast) begin
          last_next = 1'b1;
        end else begin
          last_next = 1'b0;
        end
        if (deny_0 || deny_1 || deny_2 || deny_3) begin
          deny_sig_out_next = 1'b1;
          ack_0_next = 1'b1;
          ack_1_next = 1'b1;
          ack_2_next = 1'b1;
          ack_3_next = 1'b1;
          state_next = STATE_MATCH_FOUND;
        end else if (allow_0 && allow_1 && allow_2 && allow_3) begin
          allow_sig_out_next = 1'b1;
          ack_0_next = 1'b1;
          ack_1_next = 1'b1;
          ack_2_next = 1'b1;
          ack_3_next = 1'b1;
          last_next = 1'b0;
          state_next = STATE_NO_MATCH;
        end else begin
          state_next = STATE_MATCHING;
        end
      end
      STATE_MATCH_FOUND: begin
        if (ack) begin
          deny_sig_out_next = 1'b0;
        end else begin
          deny_sig_out_next = deny_sig_out_next;
        end
        if (s_axis_text_tlast || last_reg) begin
          s_axis_text_tready_next = 1'b0;
          last_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          state_next = STATE_MATCH_FOUND;
        end
      end
      STATE_NO_MATCH: begin
        if (ack) begin
          allow_sig_out_next = 1'b0;
          ack_0_next = 1'b0;
          ack_1_next = 1'b0;
          ack_2_next = 1'b0;
          ack_3_next = 1'b0;
          state_next = STATE_IDLE;
        end else begin
          state_next = STATE_NO_MATCH;
        end
      end
    endcase
  end

  // Register update
  always @(posedge clk) begin
    if (reset) begin
      state_reg <= STATE_IDLE;
      s_axis_text_tready_reg <= 1'b0;
      last_reg <= 1'b0;
      allow_sig_out_reg <= 1'b0;
      deny_sig_out_reg <= 1'b0;
      ack_0_reg <= 1'b0;
      ack_1_reg <= 1'b0;
      ack_2_reg <= 1'b0;
      ack_3_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      s_axis_text_tready_reg <= s_axis_text_tready_next;
      last_reg <= last_next;
      allow_sig_out_reg <= allow_sig_out_next;
      deny_sig_out_reg <= deny_sig_out_next;
      ack_0_reg <= ack_0_next;
      ack_1_reg <= ack_1_next;
      ack_2_reg <= ack_2_next;
      ack_3_reg <= ack_3_next;
    end
  end

endmodule

`resetall

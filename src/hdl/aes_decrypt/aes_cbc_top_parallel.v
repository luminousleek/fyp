`default_nettype none

module aes_cbc_top_parallel
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

  // AXI output for plaintext
  output wire [31:0] m_axis_pt_tdata,
  output wire [3:0]  m_axis_pt_tkeep,
  output wire        m_axis_pt_tvalid,
  input  wire        m_axis_pt_tready,
  output wire        m_axis_pt_tlast,
  output wire        m_axis_pt_tuser
);

  //----------------------------------------------------------------
  // Internal constant and parameter definitions for secworks AES module
  //----------------------------------------------------------------

  localparam ADDR_CTRL         = 8'h08;
  localparam CTRL_INIT_BIT     = 0;
  localparam CTRL_NEXT_BIT     = 1;

  localparam ADDR_STATUS       = 8'h09;
  localparam STATUS_READY_BIT  = 0;
  localparam STATUS_VALID_BIT  = 1;

  localparam ADDR_CONFIG       = 8'h0a;
  localparam CTRL_ENCDEC_BIT   = 0;
  localparam CTRL_KEYLEN_BIT   = 1;

  localparam ADDR_KEY0         = 8'h10;
  localparam ADDR_KEY7         = 8'h17;

  localparam ADDR_BLOCK0       = 8'h20;
  localparam ADDR_BLOCK3       = 8'h23;

  localparam ADDR_RESULT0      = 8'h30;
  localparam ADDR_RESULT3      = 8'h33;

  localparam WAIT_CYCLES_WRITE = 2'd2;
  localparam WAIT_CYCLES_KE    = 7'd50;
  localparam WAIT_CYCLES_DEC   = 7'd10;

  localparam [3:0]
    STATE_IDLE = 4'd0,
    STATE_READ_KEY = 4'd1,
    STATE_LOAD_KEY = 4'd2,
    STATE_START_KE = 4'd3,
    STATE_WAIT_PAYLOAD = 4'd4,
    STATE_READ_IV = 4'd5,
    STATE_READ_CIPHERTEXT = 4'd6,
    STATE_WAIT_KE = 4'd7,
    STATE_LOAD_CIPHERTEXT = 4'd8,
    STATE_START_DECRYPT = 4'd9,
    STATE_WAIT_DECRYPT = 4'd10,
    STATE_READ_OUTPUT = 4'd11;

  reg [3:0] state_reg = STATE_LOAD_KEY, state_next;

  // datapath control signals
  reg cs_0_reg = 1'b0, cs_0_next;
  reg cs_1_reg = 1'b0, cs_1_next;
  reg cs_2_reg = 1'b0, cs_2_next;
  reg cs_3_reg = 1'b0, cs_3_next;
  reg we_0_reg = 1'b0, we_0_next;
  reg we_1_reg = 1'b0, we_1_next;
  reg we_2_reg = 1'b0, we_2_next;
  reg we_3_reg = 1'b0, we_3_next;
  reg [7:0]  address_0_reg = 8'h0, address_0_next;
  reg [7:0]  address_1_reg = 8'h0, address_1_next;
  reg [7:0]  address_2_reg = 8'h0, address_2_next;
  reg [7:0]  address_3_reg = 8'h0, address_3_next;
  reg [31:0] write_data_0_reg = 32'b0, write_data_0_next;
  reg [31:0] write_data_1_reg = 32'b0, write_data_1_next;
  reg [31:0] write_data_2_reg = 32'b0, write_data_2_next;
  reg [31:0] write_data_3_reg = 32'b0, write_data_3_next;

  reg [127:0] key_reg;
  reg [127:0] iv_reg_0;
  reg [127:0] iv_reg_1;
  reg [127:0] iv_reg_2;
  reg [127:0] iv_reg_3;
  reg [127:0] ct_reg;

  reg store_key;
  reg store_iv;
  reg store_ct;
  reg decrypt_ready_bit;
  
  reg [1:0] write_wait_cycle_reg = 2'b0, write_wait_cycle_next;
  reg [6:0] wait_reg = 7'b0, wait_next;
  reg last_ct_word_reg = 1'b0, last_ct_word_next;
  reg last_decrypt_reg = 1'b0, last_decrypt_next;

  reg [1:0] key_word_reg, key_word_next;
  reg [1:0] iv_word_reg, iv_word_next;
  reg [1:0] ct_word_reg, ct_word_next;
  reg [1:0] load_mux_reg = 2'b0, load_mux_next;
  reg [1:0] output_mux_reg = 2'b0, output_mux_next;

  reg s_axis_key_tready_reg, s_axis_key_tready_next;
  reg s_axis_ct_tready_reg, s_axis_ct_tready_next;

  // internal datapath
  reg [31:0] m_axis_pt_tdata_int;
  reg [3:0]  m_axis_pt_tkeep_int;
  reg        m_axis_pt_tvalid_int;
  reg        m_axis_pt_tlast_int;
  reg        m_axis_pt_tuser_int;

  // wires
  wire        cs_0;
  wire        cs_1;
  wire        cs_2;
  wire        cs_3;
  wire        we_0;
  wire        we_1;
  wire        we_2;
  wire        we_3;
  wire [7:0]  address_0;
  wire [7:0]  address_1;
  wire [7:0]  address_2;
  wire [7:0]  address_3;
  wire [31:0] write_data_0;
  wire [31:0] write_data_1;
  wire [31:0] write_data_2;
  wire [31:0] write_data_3;
  wire [31:0] read_data_0;
  wire [31:0] read_data_1;
  wire [31:0] read_data_2;
  wire [31:0] read_data_3;

  assign cs_0 = cs_0_reg;
  assign cs_1 = cs_1_reg;
  assign cs_2 = cs_2_reg;
  assign cs_3 = cs_3_reg;
  assign we_0 = we_0_reg;
  assign we_1 = we_1_reg;
  assign we_2 = we_2_reg;
  assign we_3 = we_3_reg;
  assign address_0 = address_0_reg;
  assign address_1 = address_1_reg;
  assign address_2 = address_2_reg;
  assign address_3 = address_3_reg;
  assign write_data_0 = write_data_0_reg;
  assign write_data_1 = write_data_1_reg;
  assign write_data_2 = write_data_2_reg;
  assign write_data_3 = write_data_3_reg;

  assign s_axis_key_tready = s_axis_key_tready_reg;
  assign s_axis_ct_tready = s_axis_ct_tready_reg;

  // instantiate aes cores
  aes aes_inst_0(
    .clk(clk),
    .reset_n(reset_n),

    .cs(cs_0),
    .we(we_0),

    .address(address_0),
    .write_data(write_data_0),
    .read_data(read_data_0)
  );
  aes aes_inst_1(
    .clk(clk),
    .reset_n(reset_n),

    .cs(cs_1),
    .we(we_1),

    .address(address_1),
    .write_data(write_data_1),
    .read_data(read_data_1)
  );
  aes aes_inst_2(
    .clk(clk),
    .reset_n(reset_n),

    .cs(cs_2),
    .we(we_2),

    .address(address_2),
    .write_data(write_data_2),
    .read_data(read_data_2)
  );
  aes aes_inst_3(
    .clk(clk),
    .reset_n(reset_n),

    .cs(cs_3),
    .we(we_3),

    .address(address_3),
    .write_data(write_data_3),
    .read_data(read_data_3)
  );

  // FSM
  always @* begin
    state_next = STATE_IDLE;
    s_axis_key_tready_next = 1'b0;
    s_axis_ct_tready_next = 1'b0;

    cs_0_next = 1'b0;
    cs_1_next = 1'b0;
    cs_2_next = 1'b0;
    cs_3_next = 1'b0;
    we_0_next = 1'b0;
    we_1_next = 1'b0;
    we_2_next = 1'b0;
    we_3_next = 1'b0;
    address_0_next = 8'h0;
    address_1_next = 8'h0;
    address_2_next = 8'h0;
    address_3_next = 8'h0;
    write_data_0_next = 32'h0;
    write_data_1_next = 32'h0;
    write_data_2_next = 32'h0;
    write_data_3_next = 32'h0;

    store_key = 1'b0;
    store_iv = 1'b0;
    store_ct = 1'b0;
    decrypt_ready_bit = 1'b0;

    write_wait_cycle_next = write_wait_cycle_reg;
    wait_next = wait_reg;
    last_ct_word_next = last_ct_word_reg;
    last_decrypt_next = last_decrypt_reg;

    key_word_next = key_word_reg;
    iv_word_next = iv_word_reg;
    ct_word_next = ct_word_reg;
    load_mux_next = load_mux_reg;
    output_mux_next = output_mux_reg;

    m_axis_pt_tdata_int = 32'd0;
    m_axis_pt_tkeep_int = 4'd0;
    m_axis_pt_tvalid_int = 1'b0;
    m_axis_pt_tlast_int = 1'b0;
    m_axis_pt_tuser_int = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        if (s_axis_key_tvalid) begin
          s_axis_key_tready_next = 1'b1;
          key_word_next = 2'b0;
          state_next = STATE_READ_KEY;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_READ_KEY: begin
        if (s_axis_key_tvalid && s_axis_key_tready) begin
          key_word_next = key_word_reg + 2'd1;
          s_axis_key_tready_next = 1'b1;
          store_key = 1'b1;
          if (key_word_reg == 2'd3) begin // have full key
            s_axis_key_tready_next = 1'b0;
            key_word_next = 2'b0;
            state_next = STATE_LOAD_KEY;
          end else begin
            state_next = STATE_READ_KEY;
          end
        end else begin
          s_axis_key_tready_next = 1'b1;
          state_next = STATE_READ_KEY;
        end
      end
      STATE_LOAD_KEY: begin
        cs_0_next = 1'b1;
        cs_1_next = 1'b1;
        cs_2_next = 1'b1;
        cs_3_next = 1'b1;
        we_0_next = 1'b1;
        we_1_next = 1'b1;
        we_2_next = 1'b1;
        we_3_next = 1'b1;
        address_0_next = ADDR_KEY0 + key_word_reg;
        address_1_next = ADDR_KEY0 + key_word_reg;
        address_2_next = ADDR_KEY0 + key_word_reg;
        address_3_next = ADDR_KEY0 + key_word_reg;
        write_data_0_next = key_reg[127 - 32 * key_word_reg -: 32];
        write_data_1_next = key_reg[127 - 32 * key_word_reg -: 32];
        write_data_2_next = key_reg[127 - 32 * key_word_reg -: 32];
        write_data_3_next = key_reg[127 - 32 * key_word_reg -: 32];
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          key_word_next = key_word_reg + 2'b1;
          write_wait_cycle_next = 2'd0;
        end else begin
          key_word_next = key_word_reg;
          write_wait_cycle_next = write_wait_cycle_reg + 1'd1;
        end
        if (key_word_reg == 2'd3 && write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          key_word_next = 2'b0;
          write_wait_cycle_next = 2'd0;
          state_next = STATE_START_KE;
        end else begin
          state_next = STATE_LOAD_KEY;
        end
      end
      STATE_START_KE: begin
        cs_0_next = 1'b1;
        cs_1_next = 1'b1;
        cs_2_next = 1'b1;
        cs_3_next = 1'b1;
        we_0_next = 1'b1;
        we_1_next = 1'b1;
        we_2_next = 1'b1;
        we_3_next = 1'b1;
        address_0_next = ADDR_CTRL;
        address_1_next = ADDR_CTRL;
        address_2_next = ADDR_CTRL;
        address_3_next = ADDR_CTRL;
        write_data_0_next[CTRL_INIT_BIT] = 1'b1;
        write_data_1_next[CTRL_INIT_BIT] = 1'b1;
        write_data_2_next[CTRL_INIT_BIT] = 1'b1;
        write_data_3_next[CTRL_INIT_BIT] = 1'b1;
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          write_wait_cycle_next = 2'd0;
          state_next = STATE_WAIT_PAYLOAD;
        end else begin
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
          state_next = STATE_START_KE;
        end
      end
      STATE_WAIT_PAYLOAD: begin
        if (s_axis_ct_tvalid) begin
          s_axis_ct_tready_next = 1;
          iv_word_next = 2'b0;
          state_next = STATE_READ_IV;
        end else begin
          state_next = STATE_WAIT_PAYLOAD;
        end
      end
      STATE_READ_IV: begin
        if (s_axis_ct_tvalid && s_axis_ct_tready) begin
          iv_word_next = iv_word_reg + 2'd1;
          s_axis_ct_tready_next = 1'b1;
          store_iv = 1'b1;
          if (iv_word_reg == 2'd3) begin // have full iv
            iv_word_next = 2'b0;
            ct_word_next = 2'b0;
            state_next = STATE_WAIT_KE;
          end else begin
            state_next = STATE_READ_IV;
          end
        end else begin
          s_axis_ct_tready_next = 1'b1;
          state_next = STATE_READ_IV;
        end
      end
      STATE_WAIT_KE: begin
        cs_0_next = 1'b1;
        address_0_next = ADDR_STATUS;
        if (wait_reg == WAIT_CYCLES_KE) begin
          if (read_data_0[STATUS_READY_BIT]) begin // key expansion done
            ct_word_next = 2'b0;
            write_wait_cycle_next = 2'b0;
            state_next = STATE_READ_CIPHERTEXT;
          end else begin
            state_next = STATE_WAIT_KE;
          end
        end else begin
          wait_next = wait_reg + 7'd1;
          state_next = STATE_WAIT_KE;
        end
      end
      STATE_READ_CIPHERTEXT: begin
        if (s_axis_ct_tvalid && s_axis_ct_tready) begin
          ct_word_next = ct_word_reg + 2'd1;
          s_axis_ct_tready_next = 1'b1;
          store_ct = 1'b1;
          if (ct_word_reg == 2'd3) begin // have full ct
            s_axis_ct_tready_next = 1'b0;
            ct_word_next = 2'b0;
            if (s_axis_ct_tlast) begin
              last_ct_word_next = 1'b1;
            end else begin
              last_ct_word_next = 1'b0;
            end
            state_next = STATE_LOAD_CIPHERTEXT;
          end else begin
            state_next = STATE_READ_CIPHERTEXT;
          end
        end else begin
          s_axis_ct_tready_next = 1'b1;
          state_next = STATE_READ_CIPHERTEXT;
        end
      end
      STATE_LOAD_CIPHERTEXT: begin
        case (load_mux_reg)
          2'd0: begin
            cs_0_next = 1'b1;
            we_0_next = 1'b1;
            address_0_next = ADDR_BLOCK0 + ct_word_reg;
            write_data_0_next = ct_reg[127 - 32 * ct_word_reg -: 32];
          end
          2'd1: begin
            cs_1_next = 1'b1;
            we_1_next = 1'b1;
            address_1_next = ADDR_BLOCK0 + ct_word_reg;
            write_data_1_next = ct_reg[127 - 32 * ct_word_reg -: 32];
          end
          2'd2: begin
            cs_2_next = 1'b1;
            we_2_next = 1'b1;
            address_2_next = ADDR_BLOCK0 + ct_word_reg;
            write_data_2_next = ct_reg[127 - 32 * ct_word_reg -: 32];
          end
          2'd3: begin
            cs_3_next = 1'b1;
            we_3_next = 1'b1;
            address_3_next = ADDR_BLOCK0 + ct_word_reg;
            write_data_3_next = ct_reg[127 - 32 * ct_word_reg -: 32];
          end
        endcase
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          ct_word_next = ct_word_reg + 2'd1;
          write_wait_cycle_next = 2'b0;
        end else begin
          ct_word_next = ct_word_reg;
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
        end
        if (ct_word_reg == 2'd3 && write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          ct_word_next = 2'd0;
          state_next = STATE_START_DECRYPT;
        end else begin
          state_next = STATE_LOAD_CIPHERTEXT;
        end
      end
      STATE_START_DECRYPT: begin
        case (load_mux_reg)
          2'd0: begin
            cs_0_next = 1'b1;
            we_0_next = 1'b1;
            address_0_next = ADDR_CTRL;
            write_data_0_next[CTRL_NEXT_BIT] = 1'b1;
          end
          2'd1: begin
            cs_1_next = 1'b1;
            we_1_next = 1'b1;
            address_1_next = ADDR_CTRL;
            write_data_1_next[CTRL_NEXT_BIT] = 1'b1;
          end
          2'd2: begin
            cs_2_next = 1'b1;
            we_2_next = 1'b1;
            address_2_next = ADDR_CTRL;
            write_data_2_next[CTRL_NEXT_BIT] = 1'b1;
          end
          2'd3: begin
            cs_3_next = 1'b1;
            we_3_next = 1'b1;
            address_3_next = ADDR_CTRL;
            write_data_3_next[CTRL_NEXT_BIT] = 1'b1;
          end
        endcase
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          write_wait_cycle_next = 2'd0;
          load_mux_next = load_mux_reg + 2'd1;
          if (last_ct_word_reg) begin
            last_decrypt_next = 1'b1;
          end
          if (load_mux_reg == 2'd3 || last_ct_word_reg) begin
            wait_next = 7'b0;
            cs_0_next = 1'b1;
            we_0_next = 1'b0;
            address_0_next = ADDR_STATUS;
            state_next = STATE_WAIT_DECRYPT;
          end else begin
            ct_word_next = 2'b0;
            s_axis_ct_tready_next = 1'b1;
            state_next = STATE_READ_CIPHERTEXT;
          end
        end else begin
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
          state_next = STATE_START_DECRYPT;
        end
      end
      STATE_WAIT_DECRYPT: begin 
        case (output_mux_reg)
          2'd0: begin
            cs_0_next = 1'b1;
            address_0_next = ADDR_STATUS;
            decrypt_ready_bit = read_data_0[STATUS_READY_BIT];
          end
          2'd1: begin
            cs_1_next = 1'b1;
            address_1_next = ADDR_STATUS;
            decrypt_ready_bit = read_data_1[STATUS_READY_BIT];
          end
          2'd2: begin
            cs_2_next = 1'b1;
            address_2_next = ADDR_STATUS;
            decrypt_ready_bit = read_data_2[STATUS_READY_BIT];
          end
          2'd3: begin
            cs_3_next = 1'b1;
            address_3_next = ADDR_STATUS;
            decrypt_ready_bit = read_data_3[STATUS_READY_BIT];
          end
        endcase
        if (wait_reg == WAIT_CYCLES_DEC) begin
          if (decrypt_ready_bit) begin // decrypt done
            ct_word_next = 2'b0;
            case (output_mux_reg)
              2'd0: begin
                address_0_next = ADDR_RESULT0;
              end
              2'd1: begin
                address_1_next = ADDR_RESULT0;
              end
              2'd2: begin
                address_2_next = ADDR_RESULT0;
              end
              2'd3: begin
                address_3_next = ADDR_RESULT0;
              end
            endcase
            write_wait_cycle_next = 2'b0;
            state_next = STATE_READ_OUTPUT;
          end else begin
            state_next = STATE_WAIT_DECRYPT;
          end
        end else begin
          wait_next = wait_reg + 7'd1;
          state_next = STATE_WAIT_DECRYPT;
        end
      end
      STATE_READ_OUTPUT: begin
        ct_word_next = ct_word_reg + 1'd1;
        case (output_mux_reg)
          2'd0: begin
            cs_0_next = 1'b1;
            address_0_next = address_0_reg + 1'd1;
            m_axis_pt_tdata_int[7:0] = read_data_0[31:24] ^ iv_reg_0[127 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[15:8] = read_data_0[23:16] ^ iv_reg_0[119 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[23:16] = read_data_0[15:8] ^ iv_reg_0[111 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[31:24] = read_data_0[7:0] ^ iv_reg_0[103 - 32 * ct_word_reg -: 8];
          end
          2'd1: begin
            cs_1_next = 1'b1;
            address_1_next = address_1_reg + 1'd1;
            m_axis_pt_tdata_int[7:0] = read_data_1[31:24] ^ iv_reg_1[127 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[15:8] = read_data_1[23:16] ^ iv_reg_1[119 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[23:16] = read_data_1[15:8] ^ iv_reg_1[111 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[31:24] = read_data_1[7:0] ^ iv_reg_1[103 - 32 * ct_word_reg -: 8];
          end
          2'd2: begin
            cs_2_next = 1'b1;
            address_2_next = address_2_reg + 1'd1;
            m_axis_pt_tdata_int[7:0] = read_data_2[31:24] ^ iv_reg_2[127 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[15:8] = read_data_2[23:16] ^ iv_reg_2[119 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[23:16] = read_data_2[15:8] ^ iv_reg_2[111 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[31:24] = read_data_2[7:0] ^ iv_reg_2[103 - 32 * ct_word_reg -: 8];
          end
          2'd3: begin
            cs_3_next = 1'b1;
            address_3_next = address_3_reg + 1'd1;
            m_axis_pt_tdata_int[7:0] = read_data_3[31:24] ^ iv_reg_3[127 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[15:8] = read_data_3[23:16] ^ iv_reg_3[119 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[23:16] = read_data_3[15:8] ^ iv_reg_3[111 - 32 * ct_word_reg -: 8];
            m_axis_pt_tdata_int[31:24] = read_data_3[7:0] ^ iv_reg_3[103 - 32 * ct_word_reg -: 8];
          end
        endcase
        m_axis_pt_tkeep_int = 4'b1111;
        m_axis_pt_tvalid_int = 1'b1;
        m_axis_pt_tlast_int = 1'b0;
        m_axis_pt_tuser_int = 1'b0;
        if (ct_word_reg == 2'd3) begin
          output_mux_next = output_mux_reg + 2'd1;
          if (last_decrypt_reg) begin
            m_axis_pt_tlast_int = 1'b1;
            last_ct_word_next = 1'b0;
            last_decrypt_next = 1'b0;
            load_mux_next = 2'd0;
            output_mux_next = 2'd0;
            state_next = STATE_WAIT_PAYLOAD; // assume same key for many ct payloads
          end else begin
            ct_word_next = 2'b0;
            write_wait_cycle_next = 2'b0;
            if (output_mux_reg == 2'd3) begin
              s_axis_ct_tready_next = 1'b1;
              state_next = STATE_READ_CIPHERTEXT;
            end else begin
              state_next = STATE_WAIT_DECRYPT;
            end
          end
        end else begin
          state_next = STATE_READ_OUTPUT;
        end
      end
      default: begin
      end
    endcase
  end

  always @(posedge clk) begin
    // Register update
    if (!reset_n) begin
      state_reg <= STATE_IDLE;
      s_axis_key_tready_reg <= 1'b0;
      s_axis_ct_tready_reg <= 1'b0;
    end else begin
      state_reg <= state_next;
      s_axis_key_tready_reg <= s_axis_key_tready_next;
      s_axis_ct_tready_reg <= s_axis_ct_tready_next;
    end

    cs_0_reg <= cs_0_next;
    cs_1_reg <= cs_1_next;
    cs_2_reg <= cs_2_next;
    cs_3_reg <= cs_3_next;
    we_0_reg <= we_0_next;
    we_1_reg <= we_1_next;
    we_2_reg <= we_2_next;
    we_3_reg <= we_3_next;
    address_0_reg <= address_0_next;
    address_1_reg <= address_1_next;
    address_2_reg <= address_2_next;
    address_3_reg <= address_3_next;
    write_data_0_reg <= write_data_0_next;
    write_data_1_reg <= write_data_1_next;
    write_data_2_reg <= write_data_2_next;
    write_data_3_reg <= write_data_3_next;

    write_wait_cycle_reg <= write_wait_cycle_next;
    wait_reg <= wait_next;
    last_ct_word_reg <= last_ct_word_next;
    last_decrypt_reg <= last_decrypt_next;
    load_mux_reg <= load_mux_next;
    output_mux_reg <= output_mux_next;

    key_word_reg <= key_word_next;
    iv_word_reg <= iv_word_next;
    ct_word_reg <= ct_word_next;

    // datapath
    if (store_key) begin
      key_reg[127 - 32 * key_word_reg -: 8] <= s_axis_key_tdata[7:0];
      key_reg[119 - 32 * key_word_reg -: 8] <= s_axis_key_tdata[15:8];
      key_reg[111 - 32 * key_word_reg -: 8] <= s_axis_key_tdata[23:16];
      key_reg[103 - 32 * key_word_reg -: 8] <= s_axis_key_tdata[31:24];
    end
    if (store_iv) begin
      iv_reg_0[127 - 32 * iv_word_reg -: 8] <= s_axis_ct_tdata[7:0];
      iv_reg_0[119 - 32 * iv_word_reg -: 8] <= s_axis_ct_tdata[15:8];
      iv_reg_0[111 - 32 * iv_word_reg -: 8] <= s_axis_ct_tdata[23:16];
      iv_reg_0[103 - 32 * iv_word_reg -: 8] <= s_axis_ct_tdata[31:24];
    end
    if (store_ct) begin
      ct_reg[127 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[7:0];
      ct_reg[119 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[15:8];
      ct_reg[111 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[23:16];
      ct_reg[103 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[31:24];
      case (load_mux_reg)
        2'd0: begin
          iv_reg_1[127 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[7:0];
          iv_reg_1[119 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[15:8];
          iv_reg_1[111 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[23:16];
          iv_reg_1[103 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[31:24];
        end
        2'd1: begin
          iv_reg_2[127 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[7:0];
          iv_reg_2[119 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[15:8];
          iv_reg_2[111 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[23:16];
          iv_reg_2[103 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[31:24];
        end
        2'd2: begin
          iv_reg_3[127 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[7:0];
          iv_reg_3[119 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[15:8];
          iv_reg_3[111 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[23:16];
          iv_reg_3[103 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[31:24];
        end
        2'd3: begin
          iv_reg_0[127 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[7:0];
          iv_reg_0[119 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[15:8];
          iv_reg_0[111 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[23:16];
          iv_reg_0[103 - 32 * ct_word_reg -: 8] <= s_axis_ct_tdata[31:24];
        end
      endcase
    end
  end

  // output datapath logic
  reg [31:0] m_axis_pt_tdata_reg = 32'd0;
  reg [3:0]  m_axis_pt_tkeep_reg = 4'd0;
  reg        m_axis_pt_tvalid_reg = 1'b0, m_axis_pt_tvalid_next;
  reg        m_axis_pt_tlast_reg = 1'b0;
  reg        m_axis_pt_tuser_reg = 1'b0;

  reg [31:0] temp_m_axis_pt_tdata_reg = 32'd0;
  reg [3:0]  temp_m_axis_pt_tkeep_reg = 4'd0;
  reg        temp_m_axis_pt_tvalid_reg = 1'b0, temp_m_axis_pt_tvalid_next;
  reg        temp_m_axis_pt_tlast_reg = 1'b0;
  reg        temp_m_axis_pt_tuser_reg = 1'b0;

  // datapath control
  reg store_pt_int_to_output;
  reg store_pt_int_to_temp;
  reg store_pt_axis_temp_to_output;

  assign m_axis_pt_tdata = m_axis_pt_tdata_reg;
  assign m_axis_pt_tkeep = m_axis_pt_tkeep_reg;
  assign m_axis_pt_tvalid = m_axis_pt_tvalid_reg;
  assign m_axis_pt_tlast = m_axis_pt_tlast_reg;
  assign m_axis_pt_tuser = m_axis_pt_tuser_reg;

  always @* begin 
    // transfer sink ready state to source
    m_axis_pt_tvalid_next = m_axis_pt_tvalid_reg;
    temp_m_axis_pt_tvalid_next = temp_m_axis_pt_tvalid_reg;

    store_pt_int_to_output = 1'b0;
    store_pt_int_to_temp = 1'b0;
    store_pt_axis_temp_to_output = 1'b0;
    
    if (m_axis_pt_tready || !m_axis_pt_tvalid_reg) begin
      // output is ready or not valid, transfer data to output
      m_axis_pt_tvalid_next = m_axis_pt_tvalid_int;
      store_pt_int_to_output = 1'b1;
    end else begin
      // output is not ready, store input in temp
      temp_m_axis_pt_tvalid_next = m_axis_pt_tvalid_int;
      store_pt_int_to_temp = 1'b1;
    end
  end

  always @(posedge clk) begin
    m_axis_pt_tvalid_reg <= m_axis_pt_tvalid_next;
    temp_m_axis_pt_tvalid_reg <= temp_m_axis_pt_tvalid_next;

    // datapath
    if (store_pt_int_to_output) begin
      m_axis_pt_tdata_reg <= m_axis_pt_tdata_int;
      m_axis_pt_tkeep_reg <= m_axis_pt_tkeep_int;
      m_axis_pt_tlast_reg <= m_axis_pt_tlast_int;
      m_axis_pt_tuser_reg <= m_axis_pt_tuser_int;
    end else if (store_pt_axis_temp_to_output) begin
      m_axis_pt_tdata_reg <= temp_m_axis_pt_tdata_reg;
      m_axis_pt_tkeep_reg <= temp_m_axis_pt_tkeep_reg;
      m_axis_pt_tlast_reg <= temp_m_axis_pt_tlast_reg;
      m_axis_pt_tuser_reg <= temp_m_axis_pt_tuser_reg;;
    end

    if (store_pt_int_to_temp) begin
      temp_m_axis_pt_tdata_reg <= m_axis_pt_tdata_int;
      temp_m_axis_pt_tkeep_reg <= m_axis_pt_tkeep_int;
      temp_m_axis_pt_tlast_reg <= m_axis_pt_tlast_int;
      temp_m_axis_pt_tuser_reg <= m_axis_pt_tuser_int;
    end

    if (!reset_n) begin
      m_axis_pt_tvalid_reg <= 1'b0;
      temp_m_axis_pt_tvalid_reg <= 1'b0;
    end
  end

endmodule

`resetall

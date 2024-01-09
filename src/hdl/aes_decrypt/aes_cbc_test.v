`default_nettype none

module aes_cbc_test
(
  // Clock and reset
  input wire         clk,
  input wire         reset_n, // active low reset

  // AXI input just to start at the correct time
  // input  wire [31:0] s_axis_ct_tdata,
  // input  wire [3:0]  s_axis_ct_tkeep,
  // input  wire        s_axis_ct_tvalid,
  // output wire        s_axis_ct_tready,
  // input  wire        s_axis_ct_tlast,
  // input  wire        s_axis_ct_tuser,

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
  localparam WAIT_CYCLES_KE    = 7'd100;
  localparam WAIT_CYCLES_DEC   = 7'd100;

  localparam [2:0]
    STATE_START = 3'd0,
    STATE_LOAD_KEY = 3'd1,
    STATE_START_KE = 3'd2,
    STATE_WAIT_KE = 3'd3,
    STATE_LOAD_CIPHERTEXT = 3'd4,
    STATE_START_DECRYPT = 3'd5,
    STATE_WAIT_DECRYPT = 3'd6,
    STATE_READ_OUTPUT = 3'd7;

  reg [2:0] state_reg = STATE_LOAD_KEY, state_next;

  // datapath control signals
  reg cs_reg = 1'b0, cs_next;
  reg we_reg = 1'b0, we_next;
  reg [7:0]  address_reg = 8'h0, address_next;
  reg [31:0] write_data_reg = 32'b0, write_data_next;

  reg [127:0] iv_reg = 128'h022cb30dad1219df1dc9ca9d63a98cf2;
  reg [127:0] key_reg = 128'hd18021a98f94d793578eb362e7bde0c1;
  // reg [127:0] ct_reg_0 = 128'h5994D463A4D8ED0625DF14F5193EF58F;
  // reg [127:0] ct_reg_1 = 128'hE8773207937712E0E3065640C4F067C6;
  // reg [127:0] ct_reg_2 = 128'h75F8097791F9F8B0B4BBB3B7B82B90A5;
  // reg [127:0] ct_reg_3 = 128'h62E76FDA938C3027094ABA81E854E85E;
  reg [127:0] ct_reg_0 = 128'h82EA5E4086C64D4F2F844920BE6363B1; // abcdabcdabcdabcd
  reg [127:0] ct_reg_1 = 128'hE24937AC87AB2D8CC119B7CAF4090FF0; // efghefghefghefgh
  reg [127:0] ct_reg_2 = 128'h7B67821E10D4E6423E8597E4E9B00E7E; // ijklijklijklijkl
  reg [127:0] ct_reg_3 = 128'h8D84853410EC90188EF884649D270FA4; // mnopmnopmnopmnop

  reg [127:0] temp_iv_reg = 128'h022cb30dad1219df1dc9ca9d63a98cf2;
  reg update_iv;

  // reg ke_clear_ready_reg = 1'b0, ke_clear_ready_next;
  // reg decrypt_clear_ready_reg = 1'b0, decrypt_clear_ready_next;
  reg [1:0] write_wait_cycle_reg = 2'b0, write_wait_cycle_next;
  reg [6:0] wait_reg = 7'b0, wait_next;

  reg [1:0] key_word_reg, key_word_next;
  reg [1:0] ct_mux_reg, ct_mux_next;
  reg [1:0] ct_word_reg, ct_word_next;

  // internal datapath
  reg [31:0] m_axis_pt_tdata_int;
  reg [3:0]  m_axis_pt_tkeep_int;
  reg        m_axis_pt_tvalid_int;
  reg        m_axis_pt_tlast_int;
  reg        m_axis_pt_tuser_int;

  // wires
  wire        cs;
  wire        we;
  wire [7:0]  address;
  wire [31:0] write_data;
  wire [31:0] read_data;

  assign cs = cs_reg;
  assign we = we_reg;
  assign address = address_reg;
  assign write_data = write_data_reg;

  // assign s_axis_ct_tready = 1'b1;

  // instantiate aes core
  aes aes_inst(
    .clk(clk),
    .reset_n(reset_n),

    .cs(cs),
    .we(we),

    .address(address),
    .write_data(write_data),
    .read_data(read_data)
  );

  // FSM
  always @* begin
    state_next = STATE_START;

    cs_next = 1'b0;
    we_next = 1'b0;
    address_next = 8'h0;
    write_data_next = 32'h0;

    update_iv = 1'b0;

    write_wait_cycle_next = write_wait_cycle_reg;
    wait_next = wait_reg;

    key_word_next = key_word_reg;
    ct_mux_next = ct_mux_reg;
    ct_word_next = ct_word_reg;

    m_axis_pt_tdata_int = 32'd0;
    m_axis_pt_tkeep_int = 4'd0;
    m_axis_pt_tvalid_int = 1'b0;
    m_axis_pt_tlast_int = 1'b0;
    m_axis_pt_tuser_int = 1'b0;

    case (state_reg)
      STATE_START: begin
        key_word_next = 2'd0;
        state_next = STATE_LOAD_KEY;
      end
      STATE_LOAD_KEY: begin
        cs_next = 1'b1;
        we_next = 1'b1;
        address_next = ADDR_KEY0 + key_word_reg;
        write_data_next = key_reg[127 - 32 * key_word_reg -: 32];
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          key_word_next = key_word_reg + 1'b1;
          write_wait_cycle_next = 2'd0;
        end else begin
          key_word_next = key_word_reg;
          write_wait_cycle_next = write_wait_cycle_reg + 1'd1;
        end
        if (key_word_reg == 2'd3 && write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          wait_next = 7'b0;
          state_next = STATE_START_KE;
        end else begin
          state_next = STATE_LOAD_KEY;
        end
      end
      STATE_START_KE: begin
        cs_next = 1'b1;
        we_next = 1'b1;
        address_next = ADDR_CTRL;
        write_data_next[CTRL_INIT_BIT] = 1'b1;
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          write_wait_cycle_next = 2'd0;
          we_next = 1'b0;
          wait_next = 7'b0;
          state_next = STATE_WAIT_KE;
          address_next = ADDR_STATUS;
        end else begin
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
          state_next = STATE_START_KE;
          address_next = ADDR_CTRL;
        end
      end
      STATE_WAIT_KE: begin
        cs_next = 1'b1;
        address_next = ADDR_STATUS;
        if (wait_reg == WAIT_CYCLES_KE) begin
          if (read_data[STATUS_READY_BIT]) begin
            ct_mux_next = 2'b0;
            ct_word_next = 2'b0;
            write_wait_cycle_next = 2'b0;
            state_next = STATE_LOAD_CIPHERTEXT;
          end else begin
            state_next = STATE_WAIT_KE;
          end
        end else begin
          wait_next = wait_reg + 7'd1;
          state_next = STATE_WAIT_KE;
        end
      end
      STATE_LOAD_CIPHERTEXT: begin
        cs_next = 1'b1;
        we_next = 1'b1;
        address_next = ADDR_BLOCK0 + ct_word_reg;
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          ct_word_next = ct_word_reg + 2'd1;
          write_wait_cycle_next = 2'b0;
        end else begin
          ct_word_next = ct_word_reg;
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
        end
        case (ct_mux_reg)
          2'd0: begin
            write_data_next = ct_reg_0[127 - 32 * ct_word_reg -: 32];
          end
          2'd1: begin
            write_data_next = ct_reg_1[127 - 32 * ct_word_reg -: 32];
          end
          2'd2: begin
            write_data_next = ct_reg_2[127 - 32 * ct_word_reg -: 32];
          end
          2'd3: begin
            write_data_next = ct_reg_3[127 - 32 * ct_word_reg -: 32];
          end
        endcase
        if (ct_word_reg == 2'd3 && write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          state_next = STATE_START_DECRYPT;
        end else begin
          state_next = STATE_LOAD_CIPHERTEXT;
        end
      end
      STATE_START_DECRYPT: begin
        cs_next = 1'b1;
        we_next = 1'b1;
        address_next = ADDR_CTRL;
        write_data_next[CTRL_NEXT_BIT] = 1'b1;
        if (write_wait_cycle_reg == WAIT_CYCLES_WRITE) begin
          write_wait_cycle_next = 2'd0;
          we_next = 1'b0;
          wait_next = 7'b0;
          state_next = STATE_WAIT_DECRYPT;
          address_next = ADDR_STATUS;
        end else begin
          write_wait_cycle_next = write_wait_cycle_reg + 2'd1;
          state_next = STATE_START_DECRYPT;
          address_next = ADDR_CTRL;
        end
      end
      STATE_WAIT_DECRYPT: begin
        cs_next = 1'b1;
        address_next = ADDR_STATUS;
        if (wait_reg == WAIT_CYCLES_DEC) begin
          if (read_data[STATUS_READY_BIT]) begin
            ct_word_next = 2'b0;
            address_next = ADDR_RESULT0;
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
        cs_next = 1'b1;
        address_next = address_reg + 1'd1;
        m_axis_pt_tdata_int[7:0] = read_data[31:24] ^ temp_iv_reg[127 - 32 * ct_word_reg -: 8];
        m_axis_pt_tdata_int[15:8] = read_data[23:16] ^ temp_iv_reg[119 - 32 * ct_word_reg -: 8];
        m_axis_pt_tdata_int[23:16] = read_data[15:8] ^ temp_iv_reg[111 - 32 * ct_word_reg -: 8];
        m_axis_pt_tdata_int[31:24] = read_data[7:0] ^ temp_iv_reg[103 - 32 * ct_word_reg -: 8];
        m_axis_pt_tkeep_int = 4'b1111;
        m_axis_pt_tvalid_int = 1'b1;
        m_axis_pt_tlast_int = 1'b0;
        m_axis_pt_tuser_int = 1'b0;
        if (ct_word_reg == 2'd3) begin
          cs_next = 1'b0;
          if (ct_mux_reg == 2'd3) begin
            m_axis_pt_tlast_int = 1'b1;
            state_next = STATE_START;
          end else begin
            ct_mux_next = ct_mux_reg + 1'd1;
            update_iv = 1'b1;
            ct_word_next = 2'b0;
            state_next = STATE_LOAD_CIPHERTEXT;
          end
        end else begin
          state_next = STATE_READ_OUTPUT;
        end
      end
    endcase
  end

  always @(posedge clk) begin
    // Register update
    if (!reset_n) begin
      state_reg <= STATE_START;
    end else begin
      state_reg <= state_next;
    end

    cs_reg <= cs_next;
    we_reg <= we_next;
    address_reg <= address_next;
    write_data_reg <= write_data_next;

    key_word_reg <= key_word_next;
    ct_mux_reg <= ct_mux_next;
    ct_word_reg <= ct_word_next;

    // ke_clear_ready_reg <= ke_clear_ready_next;
    write_wait_cycle_reg <= write_wait_cycle_next;
    wait_reg <= wait_next;

    // datapath
    if (update_iv) begin
      case (ct_mux_reg)
        2'd0: begin
          temp_iv_reg <= ct_reg_0;
        end
        2'd1: begin
          temp_iv_reg <= ct_reg_1;
        end
        2'd2: begin
          temp_iv_reg <= ct_reg_2;
        end
        2'd3: begin
          temp_iv_reg <= ct_reg_3;
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

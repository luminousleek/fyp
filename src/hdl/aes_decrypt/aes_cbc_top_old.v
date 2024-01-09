// aes-cbc top wrapper
// 2 axi streams in, 1 axi stream out, data width 32 bits
// 1 axi input for key, the other for ciphertext
// axi stream out for plaintext
// uses the aes core by secworks
//
// by isaac lee
//

`default_nettype none

module aes_cbc_top_old
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

  localparam ADDR_CTRL        = 8'h08;
  localparam CTRL_INIT_BIT    = 0;
  localparam CTRL_NEXT_BIT    = 1;

  localparam ADDR_STATUS      = 8'h09;
  localparam STATUS_READY_BIT = 0;
  localparam STATUS_VALID_BIT = 1;

  localparam ADDR_CONFIG      = 8'h0a;
  localparam CTRL_ENCDEC_BIT  = 0;
  localparam CTRL_KEYLEN_BIT  = 1;

  localparam ADDR_KEY0        = 8'h10;
  localparam ADDR_KEY7        = 8'h17;

  localparam ADDR_BLOCK0      = 8'h20;
  localparam ADDR_BLOCK3      = 8'h23;

  localparam ADDR_RESULT0     = 8'h30;
  localparam ADDR_RESULT3     = 8'h33;

  localparam [3:0]
    STATE_IDLE = 4'd0,
    STATE_LOAD_KEY = 4'd1,
    STATE_WAIT_PAYLOAD = 4'd2,
    STATE_READ_IV = 4'd3,
    STATE_READ_CIPHERTEXT = 4'd4,
    STATE_WAIT_READY = 4'd5,
    STATE_LOAD_CIPHERTEXT = 4'd6,
    STATE_READ_OUTPUT = 4'd7;

  reg [3:0] state_reg = STATE_IDLE, state_next;

  // datapath control signals
  reg cs_reg = 1'b0, cs_next;
  reg we_reg = 1'b0, we_next;
  reg [7:0]  address_reg = 8'h0, address_next;
  reg [31:0] write_data_reg = 32'b0, write_data_next;

  reg store_iv_word_0;
  reg store_iv_word_1;
  reg store_iv_word_2;
  reg store_iv_word_3;

  reg store_ct_word_0;
  reg store_ct_word_1;
  reg store_ct_word_2;
  reg store_ct_word_3;

  reg store_result_word_0;
  reg store_result_word_1;
  reg store_result_word_2;
  reg store_result_word_3;

  reg update_iv;

  reg [2:0] key_word_reg = 3'b0, key_word_next;
  reg [2:0] iv_word_reg = 3'b0, iv_word_next;
  reg [2:0] ct_word_reg = 3'b0, ct_word_next;

  reg decrypt_running_reg, decrypt_running_next;
  reg last_ct_word_reg, last_ct_word_next;

  reg s_axis_key_tready_reg, s_axis_key_tready_next;
  reg s_axis_ct_tready_reg, s_axis_ct_tready_next;

  reg [127:0] iv_reg;
  reg [127:0] next_iv_reg;
  reg [127:0] ct_reg;
  reg [127:0] result_reg; // result of aes decryption, before XOR with iv
  reg [127:0] pt_reg;

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

  assign s_axis_key_tready = s_axis_key_tready_reg;
  assign s_axis_ct_tready = s_axis_ct_tready_reg;

  assign cs = cs_reg;
  assign we = we_reg;
  assign address = address_reg;
  assign write_data = write_data_reg;

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
    state_next = STATE_IDLE;

    cs_next = 1'b0;
    we_next = 1'b0;
    address_next = 8'h0;
    write_data_next = 32'h0;

    s_axis_key_tready_next = 1'b0;
    s_axis_ct_tready_next = 1'b0;

    store_iv_word_0 = 1'b0;
    store_iv_word_1 = 1'b0;
    store_iv_word_2 = 1'b0;
    store_iv_word_3 = 1'b0;

    store_ct_word_0 = 1'b0;
    store_ct_word_1 = 1'b0;
    store_ct_word_2 = 1'b0;
    store_ct_word_3 = 1'b0;

    store_result_word_0 = 1'b0;
    store_result_word_1 = 1'b0;
    store_result_word_2 = 1'b0;
    store_result_word_3 = 1'b0;

    update_iv = 1'b0;

    key_word_next = key_word_reg;
    iv_word_next = iv_word_reg;
    ct_word_next = ct_word_reg;

    decrypt_running_next = decrypt_running_reg;
    last_ct_word_next = last_ct_word_reg;

    m_axis_pt_tdata_int = 32'd0;
    m_axis_pt_tkeep_int = 4'd0;
    m_axis_pt_tvalid_int = 1'b0;
    m_axis_pt_tlast_int = 1'b0;
    m_axis_pt_tuser_int = 1'b0;

    case (state_reg)
      STATE_IDLE: begin
        ct_word_next = 3'd0;
        if (s_axis_key_tvalid) begin
          s_axis_key_tready_next = 1'b1;
          key_word_next = 3'd0;
          address_next = ADDR_KEY0 - 1'h1;
          state_next = STATE_LOAD_KEY;
        end else begin
          state_next = STATE_IDLE;
        end
      end
      STATE_LOAD_KEY: begin
        if (s_axis_key_tvalid && s_axis_key_tready) begin
          key_word_next = key_word_reg + 3'd1;
          address_next = address_reg + 8'd1;
          cs_next = 1'b1;
          we_next = 1'b1;
          write_data_next = s_axis_key_tdata;
          state_next = STATE_LOAD_KEY;
          if (key_word_reg == 3'd3) begin
            s_axis_key_tready_next = 1'b0;
          end else begin
            s_axis_key_tready_next = 1'b1;
          end
        end else begin
          if (key_word_reg >= 3'd4) begin
            s_axis_key_tready_next = 1'b0;
            write_data_next[CTRL_INIT_BIT] = 1'b1; // write 1 to init bit to start key expansion
            cs_next = 1'b1;
            we_next = 1'b1;
            address_next = ADDR_CTRL;
            state_next = STATE_WAIT_PAYLOAD;
          end else begin
            s_axis_key_tready_next = 1'b1;
            state_next = STATE_LOAD_KEY;
          end
        end
      end
      STATE_WAIT_PAYLOAD: begin
        if (s_axis_ct_tvalid) begin
          s_axis_ct_tready_next = 1;
          iv_word_next = 3'd0;
          state_next = STATE_READ_IV;
        end else begin
          state_next = STATE_WAIT_PAYLOAD;
        end
      end
      STATE_READ_IV: begin
        if (s_axis_ct_tvalid && s_axis_ct_tready) begin
          s_axis_ct_tready_next = 1'b1;
          iv_word_next = iv_word_reg + 3'd1;
          state_next = STATE_READ_IV;
          case (iv_word_reg)
            3'd0: begin
              store_iv_word_0 = 1'b1;
            end
            3'd1: begin
              store_iv_word_1 = 1'b1;
            end
            3'd2: begin
              store_iv_word_2 = 1'b1;
            end
            3'd3: begin
              store_iv_word_3 = 1'b1;
              ct_word_next = 3'd0;
              state_next = STATE_READ_CIPHERTEXT;
            end
          endcase
        end else begin
          s_axis_ct_tready_next = 1'b1;
          state_next = STATE_READ_IV;
        end
      end
      STATE_READ_CIPHERTEXT: begin
        if (s_axis_ct_tvalid && s_axis_ct_tready) begin
          s_axis_ct_tready_next = 1'b1;
          ct_word_next = ct_word_reg + 3'd1;
          state_next = STATE_READ_CIPHERTEXT;
          case (ct_word_reg)
            3'd0: begin
              store_ct_word_0 = 1'b1;
            end
            3'd1: begin
              store_ct_word_1 = 1'b1;
            end
            3'd2: begin
              store_ct_word_2 = 1'b1;
            end
            3'd3: begin
              store_ct_word_3 = 1'b1;
              state_next = STATE_WAIT_READY;
              address_next = ADDR_STATUS;
              cs_next = 1'b1;
              s_axis_ct_tready_next = 1'b0;
              if (s_axis_ct_tlast) begin
                last_ct_word_next = 1'b1;
              end
            end
          endcase
        end else begin
          state_next = STATE_READ_CIPHERTEXT;
        end
      end
      STATE_WAIT_READY: begin
        cs_next = 1'b1;
        if (read_data[STATUS_READY_BIT]) begin
          if (decrypt_running_reg) begin
            state_next = STATE_READ_OUTPUT;
            address_next = ADDR_RESULT0;
            decrypt_running_next = 1'b0;
          end else begin
            state_next = STATE_LOAD_CIPHERTEXT;
            address_next = ADDR_BLOCK0;
            we_next = 1'b1;
            write_data_next = ct_reg[127:96];
          end
        end else begin
          address_next = ADDR_STATUS;
          state_next = STATE_WAIT_READY;
        end
      end
      STATE_LOAD_CIPHERTEXT: begin
        state_next = STATE_LOAD_CIPHERTEXT;
        address_next = address_reg + 1'b1;
        we_next = 1'b1;
        cs_next = 1'b1;
        case (address_reg)
          8'h20: begin
            write_data_next = ct_reg[95:64];
          end
          8'h21: begin
            write_data_next = ct_reg[63:32];
          end
          8'h22: begin
            write_data_next = ct_reg[31:0];
          end
          8'h23: begin // start decryption
            address_next = ADDR_CTRL;
            write_data_next[CTRL_NEXT_BIT] = 1;
            decrypt_running_next = 1'b1;
            if (last_ct_word_reg) begin
              state_next = STATE_WAIT_READY;
            end else begin
              s_axis_ct_tready_next = 1'b1;
              state_next = STATE_READ_CIPHERTEXT; // read next block while waiting for decryption
            end
          end
        endcase
      end
      STATE_READ_OUTPUT: begin
        state_next = STATE_READ_OUTPUT;
        cs_next = 1'b1;
        address_next = address_reg + 1'b1;
        case (address_reg)
          8'h30: begin
            store_result_word_0 = 1'b1;
          end
          8'h31: begin
            store_result_word_1 = 1'b1;

            m_axis_pt_tdata_int = result_reg[127:96] ^ iv_reg[127:96];
            m_axis_pt_tkeep_int = 4'b1111;
            m_axis_pt_tvalid_int = 1'b1;
            m_axis_pt_tlast_int = 1'b0;
            m_axis_pt_tuser_int = 1'b0;
          end
          8'h32: begin
            store_result_word_2 = 1'b1;

            m_axis_pt_tdata_int = result_reg[95:64] ^ iv_reg[95:64];
            m_axis_pt_tkeep_int = 4'b1111;
            m_axis_pt_tvalid_int = 1'b1;
            m_axis_pt_tlast_int = 1'b0;
            m_axis_pt_tuser_int = 1'b0;
          end
          8'h33: begin
            store_result_word_3 = 1'b1;

            m_axis_pt_tdata_int = result_reg[63:32] ^ iv_reg[63:32];
            m_axis_pt_tkeep_int = 4'b1111;
            m_axis_pt_tvalid_int = 1'b1;
            m_axis_pt_tlast_int = 1'b0;
            m_axis_pt_tuser_int = 1'b0;
          end
          8'h34: begin
            m_axis_pt_tdata_int = result_reg[31:0] ^ iv_reg[31:0];
            m_axis_pt_tkeep_int = 4'b1111;
            m_axis_pt_tvalid_int = 1'b1;
            m_axis_pt_tlast_int = 1'b0;
            m_axis_pt_tuser_int = 1'b0;
            update_iv = 1'b1;

            if (last_ct_word_reg) begin
              m_axis_pt_tlast_int = 1'b1;
              s_axis_ct_tready_next = 1'b1;
              state_next = STATE_WAIT_PAYLOAD;
            end else begin // load next ct into aes
              address_next = ADDR_BLOCK0;
              we_next = 1'b1;
              write_data_next = ct_reg[127:96];
              state_next = STATE_LOAD_CIPHERTEXT;
            end
          end
        endcase
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

    cs_reg <= cs_next;
    we_reg <= we_next;
    address_reg <= address_next;
    write_data_reg <= write_data_next;

    key_word_reg <= key_word_next;
    iv_word_reg <= iv_word_next;
    ct_word_reg <= ct_word_next;

    decrypt_running_reg <= decrypt_running_next;
    last_ct_word_reg <= last_ct_word_next;

    // Datapath
    if (store_iv_word_0) begin
      iv_reg[127:96] <= s_axis_ct_tdata;
    end

    if (store_iv_word_1) begin
      iv_reg[95:64] <= s_axis_ct_tdata;
    end

    if (store_iv_word_2) begin
      iv_reg[63:32] <= s_axis_ct_tdata;
    end

    if (store_iv_word_3) begin
      iv_reg[31:0] <= s_axis_ct_tdata;
    end

    if (store_ct_word_0) begin
      ct_reg[127:96] <= s_axis_ct_tdata;
      next_iv_reg[127:96] <= s_axis_ct_tdata;
    end

    if (store_ct_word_1) begin
      ct_reg[95:64] <= s_axis_ct_tdata;
      next_iv_reg[95:64] <= s_axis_ct_tdata;
    end

    if (store_ct_word_2) begin
      ct_reg[63:32] <= s_axis_ct_tdata;
      next_iv_reg[63:32] <= s_axis_ct_tdata;
    end

    if (store_ct_word_3) begin
      ct_reg[31:0] <= s_axis_ct_tdata;
      next_iv_reg[31:0] <= s_axis_ct_tdata;
    end

    if (store_result_word_0) begin
      result_reg[127:96] <= read_data;
    end

    if (store_result_word_1) begin
      result_reg[95:64] <= read_data;
    end

    if (store_result_word_2) begin
      result_reg[63:32] <= read_data;
    end

    if (store_result_word_3) begin
      result_reg[31:0] <= read_data;
    end

    if (update_iv) begin
      iv_reg <= next_iv_reg;
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

// UART Loopback Test
// Target: Nandland Go Board (iCE40 HX1K, 25 MHz)
//
// Sends 0x55 every second via UART TX.
// TX serial feeds directly back into RX (fabric loopback — no jumper needed).
// LEDs show lower nibble of the last received byte.
//
// Expected result after ~1 second:
//   LED1 ON  LED2 OFF  LED3 ON  LED4 OFF  (0x55 lower nibble = 0101)
//
// The TX pin also drives the physical UART line, so you can monitor
// 0x55 ('U') arriving in a terminal at 115200 8N1.

module SynthTop (
    input  CLK,
    input  RX,    // from host — unused in loopback, kept for PCF binding
    output TX,    // to host — drives 0x55 ('U') every second
    output LED1,
    output LED2,
    output LED3,
    output LED4
);

  localparam CLKS_PER_BIT = 217;        // 25 MHz / 115200 baud
  localparam TEST_BYTE    = 8'h55;      // 'U' — alternating bits, easy to spot
  localparam SEND_PERIOD  = 25_000_000; // 1 second @ 25 MHz

  // -------------------------------------------------------------------------
  // Periodic TX trigger — one-cycle pulse every SEND_PERIOD clocks
  // -------------------------------------------------------------------------
  reg [24:0] r_send_ctr = 0;
  reg        r_tx_dv    = 0;

  always @(posedge CLK) begin
    r_tx_dv <= 1'b0;
    if (r_send_ctr == SEND_PERIOD - 1) begin
      r_send_ctr <= 0;
      r_tx_dv    <= 1'b1;
    end else
      r_send_ctr <= r_send_ctr + 1;
  end

  // -------------------------------------------------------------------------
  // UART TX
  // -------------------------------------------------------------------------
  wire w_tx_serial;

  UART_TX #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
    .i_Rst_L    (1'b1),
    .i_Clock    (CLK),
    .i_TX_DV    (r_tx_dv),
    .i_TX_Byte  (TEST_BYTE),
    .o_TX_Active(),
    .o_TX_Serial(w_tx_serial),
    .o_TX_Done  ()
  );

  assign TX = w_tx_serial;

  // -------------------------------------------------------------------------
  // UART RX — fabric loopback: TX serial wire feeds RX input directly
  // -------------------------------------------------------------------------
  wire       w_rx_dv;
  wire [7:0] w_rx_byte;

  UART_RX #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
    .i_Rst_L    (1'b1),
    .i_Clock    (CLK),
    .i_RX_Serial(w_tx_serial),  // loopback — not the physical RX pin
    .o_RX_DV    (w_rx_dv),
    .o_RX_Byte  (w_rx_byte)
  );

  // -------------------------------------------------------------------------
  // Latch received byte on DV pulse, display lower nibble on LEDs.
  // r_received stays 0x00 until first successful loopback.
  // -------------------------------------------------------------------------
  reg [7:0] r_received = 8'h00;

  always @(posedge CLK) begin
    if (w_rx_dv)
      r_received <= w_rx_byte;
  end

  assign LED1 = r_received[0];  // 1 on success (0x55 bit 0 = 1)
  assign LED2 = r_received[1];  // 0 on success
  assign LED3 = r_received[2];  // 1 on success
  assign LED4 = r_received[3];  // 0 on success

endmodule

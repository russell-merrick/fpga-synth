// UART top-level — instantiates all UART sub-modules
//
// Exposes decoded synth controls (note/octave/gate/high) from the RX side
// and raw TX control inputs for future use (echo, status messages, etc.).
`include "constants.vh"

module uart_top (
    input        i_CLK,

    // Physical UART pins
    input        i_RX_Serial,
    output       o_TX_Serial,

    // TX control (unused for now — wire to 0/1 from synth_top until needed)
    input        i_TX_DV,
    input  [7:0] i_TX_Byte,

    // Decoded note parameters
    output [3:0] o_note,
    output [2:0] o_octave,
    output       o_gate,
    output       o_high,
    output [1:0] o_wave
);

  wire       w_rx_dv;
  wire [7:0] w_rx_byte;

  UART_RX #(.CLKS_PER_BIT(`CLKS_PER_BIT)) u_rx (
    .i_Rst_L    (1'b1),
    .i_Clock    (i_CLK),
    .i_RX_Serial(i_RX_Serial),
    .o_RX_DV    (w_rx_dv),
    .o_RX_Byte  (w_rx_byte)
  );

  UART_TX #(.CLKS_PER_BIT(`CLKS_PER_BIT)) u_tx (
    .i_Rst_L    (1'b1),
    .i_Clock    (i_CLK),
    .i_TX_DV    (i_TX_DV),
    .i_TX_Byte  (i_TX_Byte),
    .o_TX_Active(),
    .o_TX_Serial(o_TX_Serial),
    .o_TX_Done  ()
  );

  uart_cmd u_cmd (
    .i_CLK     (i_CLK),
    .i_RX_DV   (w_rx_dv),
    .i_RX_Byte (w_rx_byte),
    .o_note    (o_note),
    .o_octave  (o_octave),
    .o_gate    (o_gate),
    .o_high    (o_high),
    .o_wave    (o_wave)
  );

endmodule

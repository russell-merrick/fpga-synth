// UART top-level — RX, command decoder, TX help/status menu.
`include "src/constants.vh"

module uart_top (
    input        i_CLK,

    input        i_RX_Serial,
    output       o_TX_Serial,

    output [3:0] o_note,
    output [2:0] o_octave,
    output       o_gate,
    output       o_high,
    output [1:0] o_wave,

    output [3:0] o_v0_note,
    output       o_v0_high,
    output       o_v0_gate,
    output [3:0] o_v1_note,
    output       o_v1_high,
    output       o_v1_gate,

    output [7:0] o_attack,
    output [7:0] o_decay,
    output [7:0] o_sustain,
    output [7:0] o_release
);

  wire       w_rx_dv;
  wire [7:0] w_rx_byte;
  wire       w_print_help;
  wire       w_print_status;
  wire [1:0] w_adsr_sel;
  wire       w_tx_dv;
  wire [7:0] w_tx_byte;
  wire       w_tx_active;

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
    .i_TX_DV    (w_tx_dv),
    .i_TX_Byte  (w_tx_byte),
    .o_TX_Active(w_tx_active),
    .o_TX_Serial(o_TX_Serial),
    .o_TX_Done  ()
  );

  // Go Board (HX1K) skips the help/status printer to fit; IceSugar prints a menu.

  uart_cmd u_cmd (
    .i_CLK          (i_CLK),
    .i_RX_DV        (w_rx_dv),
    .i_RX_Byte      (w_rx_byte),
    .o_note         (o_note),
    .o_octave       (o_octave),
    .o_gate         (o_gate),
    .o_high         (o_high),
    .o_wave         (o_wave),
    .o_v0_note      (o_v0_note),
    .o_v0_high      (o_v0_high),
    .o_v0_gate      (o_v0_gate),
    .o_v1_note      (o_v1_note),
    .o_v1_high      (o_v1_high),
    .o_v1_gate      (o_v1_gate),
    .o_attack       (o_attack),
    .o_decay        (o_decay),
    .o_sustain      (o_sustain),
    .o_release      (o_release),
    .o_adsr_sel     (w_adsr_sel),
    .o_print_help   (w_print_help),
    .o_print_status (w_print_status)
  );

`ifdef SKIP_UART_MENU
  assign w_tx_dv   = 1'b0;
  assign w_tx_byte = 8'h00;
`else
  uart_menu u_menu (
    .i_CLK          (i_CLK),
    .i_print_help   (w_print_help),
    .i_print_status (w_print_status),
    .i_attack       (o_attack),
    .i_decay        (o_decay),
    .i_sustain      (o_sustain),
    .i_release      (o_release),
    .i_adsr_sel     (w_adsr_sel),
    .i_wave         (o_wave),
    .i_octave       (o_octave),
    .i_gate         (o_gate),
    .i_v0_note      (o_v0_note),
    .i_v0_high      (o_v0_high),
    .i_v0_gate      (o_v0_gate),
    .i_v1_note      (o_v1_note),
    .i_v1_high      (o_v1_high),
    .i_v1_gate      (o_v1_gate),
    .o_TX_DV        (w_tx_dv),
    .o_TX_Byte      (w_tx_byte),
    .i_TX_Active    (w_tx_active),
    .o_busy         ()
  );
`endif

endmodule

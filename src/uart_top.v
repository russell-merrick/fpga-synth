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
    output [7:0] o_release,
    output [7:0] o_cutoff,
    output [7:0] o_res,
    output [7:0] o_fenv_amt,
    output [7:0] o_fdecay,
    output [7:0] o_drive,
    output [7:0] o_fm_index,
    output [7:0] o_fm_ratio,
    output [7:0] o_fold,
    output       o_accent,
    output       o_slide,
    output       o_v0_accent,
    output       o_v0_slide,
    output       o_v1_accent,
    output       o_v1_slide,
    output       o_vcf_accent,
    output       o_seq_play,
    output [7:0] o_bpm,
    output [4:0] o_seq_len,
    output       o_seq_we,
    output [3:0] o_seq_waddr,
    output [7:0] o_seq_wdata,
    output       o_note_trig
);

  wire       w_rx_dv;
  wire [7:0] w_rx_byte;
  wire       w_print_help;
  wire       w_print_status;
  wire [3:0] w_param_sel;
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
    .o_param_sel    (w_param_sel),
    .o_cutoff       (o_cutoff),
    .o_res          (o_res),
    .o_fenv_amt     (o_fenv_amt),
    .o_fdecay       (o_fdecay),
    .o_drive        (o_drive),
    .o_fm_index     (o_fm_index),
    .o_fm_ratio     (o_fm_ratio),
    .o_fold         (o_fold),
    .o_accent       (o_accent),
    .o_slide        (o_slide),
    .o_v0_accent    (o_v0_accent),
    .o_v0_slide     (o_v0_slide),
    .o_v1_accent    (o_v1_accent),
    .o_v1_slide     (o_v1_slide),
    .o_vcf_accent   (o_vcf_accent),
    .o_seq_play     (o_seq_play),
    .o_bpm          (o_bpm),
    .o_seq_len      (o_seq_len),
    .o_seq_we       (o_seq_we),
    .o_seq_waddr    (o_seq_waddr),
    .o_seq_wdata    (o_seq_wdata),
    .o_note_trig    (o_note_trig),
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
    .i_param_sel    (w_param_sel),
    .i_cutoff       (o_cutoff),
    .i_res          (o_res),
    .i_fenv_amt     (o_fenv_amt),
    .i_fdecay       (o_fdecay),
    .i_drive        (o_drive),
    .i_fm_index     (o_fm_index),
    .i_fm_ratio     (o_fm_ratio),
    .i_fold         (o_fold),
    .i_accent       (o_accent),
    .i_slide        (o_slide),
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

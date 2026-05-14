// Self-checking testbench for uart_cmd
// Run with: apio test
//
// Drives i_RX_DV/i_RX_Byte directly — no UART bit-timing needed.
// Tests every key mapping, octave clamping, gate toggle, wave select, and unknown-byte handling.
`include "constants.vh"
`timescale 1ns/1ps

module uart_cmd_tb;

  localparam CLK_PERIOD = 40;  // ns, 25 MHz
  localparam TB_NAME    = "uart_cmd Testbench";

  reg       CLK       = 1'b0;
  reg       i_RX_DV   = 1'b0;
  reg [7:0] i_RX_Byte = 8'h00;

  wire [3:0] o_note;
  wire [2:0] o_octave;
  wire       o_gate;
  wire       o_high;
  wire [1:0] o_wave;

  always #(CLK_PERIOD/2) CLK = ~CLK;

  uart_cmd dut (
    .i_CLK     (CLK),
    .i_RX_DV   (i_RX_DV),
    .i_RX_Byte (i_RX_Byte),
    .o_note    (o_note),
    .o_octave  (o_octave),
    .o_gate    (o_gate),
    .o_high    (o_high),
    .o_wave    (o_wave)
  );

  // ── Test infrastructure ─────────────────────────────────────────────────────
  `include "test_utils.vh"

  // Pulse DV on negedge so the DUT sees stable inputs at the following posedge.
  task send_cmd;
    input [7:0] b;
    begin
      @(negedge CLK);
      i_RX_DV   = 1'b1;
      i_RX_Byte = b;
      @(posedge CLK);  // DUT captures here (non-blocking — outputs update end of step)
      @(negedge CLK);
      i_RX_DV   = 1'b0;
      @(posedge CLK);  // outputs stable from here on
    end
  endtask

  // ── Tests ───────────────────────────────────────────────────────────────────
  initial
  begin
    $dumpvars(0, uart_cmd_tb);
    $display("=== %0s ===", TB_NAME);

    @(posedge CLK);  // let initial values settle

    // ── 1. Default state ──────────────────────────────────────────────────────
    pass_fail(o_note   == `DEFAULT_NOTE   &&
              o_octave == `DEFAULT_OCTAVE &&
              o_gate   == 1'b1            &&
              o_high   == 1'b0            &&
              o_wave   == `DEFAULT_WAVE,
              "defaults: note=A oct=4 gate=1 high=0 wave=sine");

    // ── 2. All 13 note keys ───────────────────────────────────────────────────
    send_cmd(8'h61); pass_fail(o_note == 4'd0  && !o_high && o_gate, "a → C  (note  0)");
    send_cmd(8'h77); pass_fail(o_note == 4'd1  && !o_high && o_gate, "w → C# (note  1)");
    send_cmd(8'h73); pass_fail(o_note == 4'd2  && !o_high && o_gate, "s → D  (note  2)");
    send_cmd(8'h65); pass_fail(o_note == 4'd3  && !o_high && o_gate, "e → D# (note  3)");
    send_cmd(8'h64); pass_fail(o_note == 4'd4  && !o_high && o_gate, "d → E  (note  4)");
    send_cmd(8'h66); pass_fail(o_note == 4'd5  && !o_high && o_gate, "f → F  (note  5)");
    send_cmd(8'h74); pass_fail(o_note == 4'd6  && !o_high && o_gate, "t → F# (note  6)");
    send_cmd(8'h67); pass_fail(o_note == 4'd7  && !o_high && o_gate, "g → G  (note  7)");
    send_cmd(8'h79); pass_fail(o_note == 4'd8  && !o_high && o_gate, "y → G# (note  8)");
    send_cmd(8'h68); pass_fail(o_note == 4'd9  && !o_high && o_gate, "h → A  (note  9)");
    send_cmd(8'h75); pass_fail(o_note == 4'd10 && !o_high && o_gate, "u → A# (note 10)");
    send_cmd(8'h6A); pass_fail(o_note == 4'd11 && !o_high && o_gate, "j → B  (note 11)");
    send_cmd(8'h6B); pass_fail(o_note == 4'd0  &&  o_high && o_gate, "k → C  high=1  ");

    // ── 3. Any note key clears high ───────────────────────────────────────────
    send_cmd(8'h73);  // 's'
    pass_fail(o_note == 4'd2 && o_high == 1'b0, "note key after k clears high");

    // ── 4. Gate toggle (space) ────────────────────────────────────────────────
    pass_fail(o_gate == 1'b1, "gate=1 before toggle");
    send_cmd(8'h20); pass_fail(o_gate == 1'b0, "space → gate off");
    send_cmd(8'h20); pass_fail(o_gate == 1'b1, "space → gate on");

    // Note keys force gate on regardless of current state
    send_cmd(8'h20);            // gate off
    send_cmd(8'h61);            // 'a' — should force gate on
    pass_fail(o_gate == 1'b1, "note key forces gate on");

    // ── 5. Octave up ('x'), clamps at 7 ──────────────────────────────────────
    // Reset to known octave first — send 'z' until floor
    repeat(8) send_cmd(8'h7A);
    pass_fail(o_octave == 3'd0, "z x8 → floor at 0");

    send_cmd(8'h78); pass_fail(o_octave == 3'd1, "x → octave 1");
    send_cmd(8'h78); pass_fail(o_octave == 3'd2, "x → octave 2");
    send_cmd(8'h78); pass_fail(o_octave == 3'd3, "x → octave 3");
    send_cmd(8'h78); pass_fail(o_octave == 3'd4, "x → octave 4");
    send_cmd(8'h78); pass_fail(o_octave == 3'd5, "x → octave 5");
    send_cmd(8'h78); pass_fail(o_octave == 3'd6, "x → octave 6");
    send_cmd(8'h78); pass_fail(o_octave == 3'd7, "x → octave 7");
    send_cmd(8'h78); pass_fail(o_octave == 3'd7, "x at 7 → ceiling clamp");

    // ── 6. Octave down ('z'), clamps at 0 ────────────────────────────────────
    send_cmd(8'h7A); pass_fail(o_octave == 3'd6, "z → octave 6");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd5, "z → octave 5");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd4, "z → octave 4");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd3, "z → octave 3");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd2, "z → octave 2");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd1, "z → octave 1");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd0, "z → octave 0");
    send_cmd(8'h7A); pass_fail(o_octave == 3'd0, "z at 0 → floor clamp");

    // ── 7. Wave select (1–4) ─────────────────────────────────────────────────
    send_cmd(8'h31); pass_fail(o_wave == 2'd0, "1 -> sine");
    send_cmd(8'h32); pass_fail(o_wave == 2'd1, "2 -> triangle");
    send_cmd(8'h33); pass_fail(o_wave == 2'd2, "3 -> sawtooth");
    send_cmd(8'h34); pass_fail(o_wave == 2'd3, "4 -> square");
    send_cmd(8'h31); pass_fail(o_wave == 2'd0, "1 -> back to sine");

    // ── 8. Unknown byte leaves all state unchanged ────────────────────────────
    send_cmd(8'h68);   // h → A, note=9
    send_cmd(8'hFF);   // unknown
    pass_fail(o_note == 4'd9 && o_octave == 3'd0 && o_gate == 1'b1,
              "unknown byte: state unchanged");

    // ── Summary ───────────────────────────────────────────────────────────────
    finish_test;
  end

endmodule

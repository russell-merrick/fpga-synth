// Self-checking testbench for uart_cmd
// Run with: apio test
//
// Drives i_RX_DV/i_RX_Byte directly — no UART bit-timing needed.
// Tests every key mapping, octave clamping, gate toggle, wave select, and unknown-byte handling.
`include "src/constants.vh"
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
  wire [3:0] o_v0_note;
  wire       o_v0_high;
  wire       o_v0_gate;
  wire [3:0] o_v1_note;
  wire       o_v1_high;
  wire       o_v1_gate;
  wire [7:0] o_attack;
  wire [7:0] o_decay;
  wire [7:0] o_sustain;
  wire [7:0] o_release;
  wire [3:0] o_param_sel;
  wire [7:0] o_drive;
  wire [7:0] o_fm_index;
  wire [7:0] o_fm_ratio;
  wire [7:0] o_fold;
  wire       o_accent;
  wire       o_slide;
  wire [7:0] o_cutoff;
  wire [7:0] o_res;
  wire [7:0] o_fenv_amt;
  wire [7:0] o_fdecay;
  wire       o_seq_play;
  wire [7:0] o_bpm;
  wire       o_note_trig;
  wire       o_print_help;
  wire       o_print_status;

  always #(CLK_PERIOD/2) CLK = ~CLK;

  uart_cmd dut (
    .i_CLK          (CLK),
    .i_RX_DV        (i_RX_DV),
    .i_RX_Byte      (i_RX_Byte),
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
    .o_param_sel    (o_param_sel),
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
    .o_seq_play     (o_seq_play),
    .o_bpm          (o_bpm),
    .o_note_trig    (o_note_trig),
    .o_print_help   (o_print_help),
    .o_print_status (o_print_status)
  );

  // ── Test infrastructure ─────────────────────────────────────────────────────
  `include "sim/test_utils.vh"

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
              "defaults: note=A oct=4 gate=1 high=0 wave=def");

    // ── 1b. Two-voice allocate from reset (IceSugar / NUM_VOICES>1) ──────────
    if (`NUM_VOICES > 1)
    begin
      send_cmd(8'h61);  // a → C on voice 1
      send_cmd(8'h64);  // d → E on voice 0
      pass_fail(o_v0_gate && o_v1_gate && (o_v0_note != o_v1_note),
                "from reset, a then d -> two voices gated, different notes");
      send_cmd(8'h20);
      pass_fail(!o_v0_gate && !o_v1_gate && !o_gate,
                "space mutes both voices");
      send_cmd(8'h20);
      pass_fail(o_v0_gate && o_v1_gate && o_gate,
                "space again restores both voices");
    end

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

    // ── ADSR / filter select / step ───────────────────────────────────────────
    pass_fail(o_attack == `DEFAULT_ATTACK && o_param_sel == 3'd0 &&
              o_cutoff == `DEFAULT_CUTOFF && o_res == `DEFAULT_RES,
              "defaults: A=80 sel=A C/Q at reset");
    send_cmd(8'h72);  // r
    pass_fail(o_param_sel == 3'd1, "r -> select decay");
    send_cmd(8'h2D);  // -
    pass_fail(o_decay == (`DEFAULT_DECAY - `ADSR_STEP), "- -> decay down");
    send_cmd(8'h3D);  // =
    pass_fail(o_decay == `DEFAULT_DECAY, "= -> decay back");
    send_cmd(8'h72);  // S
    send_cmd(8'h72);  // R
    send_cmd(8'h72);  // C
    pass_fail(o_param_sel == 3'd4, "r x4 from D -> select cutoff");
    send_cmd(8'h2D);
    pass_fail(o_cutoff == (`DEFAULT_CUTOFF - `ADSR_STEP), "- -> cutoff down");
    send_cmd(8'h72);  // Q
    send_cmd(8'h3D);
    pass_fail(o_param_sel == 3'd5 &&
              o_res == (`DEFAULT_RES + `ADSR_STEP),
              "r then = -> res up");
    send_cmd(8'h3F);  // ?
    pass_fail(o_param_sel == 3'd5 && o_res == (`DEFAULT_RES + `ADSR_STEP),
              "? does not change params");
    send_cmd(8'h63);  // c
    pass_fail(o_param_sel == 3'd4, "c -> select cutoff");
    send_cmd(8'h76);  // v
    pass_fail(o_param_sel == 3'd6, "v -> select fenv amt");

    // ── note_trig pulse ───────────────────────────────────────────────────────
    @(negedge CLK);
    i_RX_DV   = 1'b1;
    i_RX_Byte = 8'h61;
    @(posedge CLK);
    @(negedge CLK);
    pass_fail(o_note_trig == 1'b1, "note key pulses o_note_trig");
    i_RX_DV = 1'b0;
    @(posedge CLK);
    @(negedge CLK);
    pass_fail(o_note_trig == 1'b0, "o_note_trig is one cycle");

    send_cmd(8'h2E);
    pass_fail(o_accent == 1'b1, ". toggles accent on");
    send_cmd(8'h2E);
    pass_fail(o_accent == 1'b0, ". toggles accent off");
    send_cmd(8'h6F);
    pass_fail(o_param_sel == 4'd8, "o -> select drive");
    send_cmd(8'h69);
    pass_fail(o_param_sel == 4'd9, "i -> select FM index");
    send_cmd(8'h6E);
    pass_fail(o_param_sel == 4'd10 && o_fm_ratio == `DEFAULT_FM_RATIO,
              "n -> select FM ratio");
    send_cmd(8'h3D);
    pass_fail(o_fm_ratio == (`DEFAULT_FM_RATIO + 8'd1), "= -> ratio up");
    send_cmd(8'h6C);
    pass_fail(o_param_sel == 4'd11, "l -> select fold");
    send_cmd(8'h2F);
    pass_fail(o_slide == 1'b1, "/ toggles slide on");
    @(negedge CLK);
    i_RX_DV   = 1'b1;
    i_RX_Byte = 8'h61;
    @(posedge CLK);
    @(negedge CLK);
    pass_fail(o_note_trig == 1'b0, "slide note does not trig VCF");
    i_RX_DV = 1'b0;
    @(posedge CLK);
    send_cmd(8'h2F);
    pass_fail(o_slide == 1'b0, "/ toggles slide off");

`ifndef SKIP_SEQ
    send_cmd(8'h3A);  // :
    send_cmd(8'h43);  // C
    send_cmd(8'h31);  // 1
    send_cmd(8'h30);  // 0
    send_cmd(8'h30);  // 0
    send_cmd(8'h0A);  // LF
    pass_fail(o_cutoff == 8'd100, ":C100 sets cutoff");
    send_cmd(8'h70);
    pass_fail(o_seq_play == 1'b1, "p starts sequencer");
    send_cmd(8'h70);
    pass_fail(o_seq_play == 1'b0, "p stops sequencer");
    pass_fail(!o_v0_gate && !o_v1_gate && !o_gate, "p-stop mutes voices");
    send_cmd(8'h3A);
    send_cmd(8'h50);  // P
    send_cmd(8'h30);
    send_cmd(8'h30);
    send_cmd(8'h31);
    send_cmd(8'h0A);
    pass_fail(o_seq_play == 1'b1, ":P001 starts sequencer");
    send_cmd(8'h3A);
    send_cmd(8'h50);
    send_cmd(8'h30);
    send_cmd(8'h30);
    send_cmd(8'h30);
    send_cmd(8'h0A);
    pass_fail(o_seq_play == 1'b0, ":P000 stops sequencer");
    pass_fail(!o_v0_gate && !o_v1_gate && !o_gate, ":P000 mutes voices");
`endif

    // ── Summary ───────────────────────────────────────────────────────────────
    finish_test;
  end

endmodule

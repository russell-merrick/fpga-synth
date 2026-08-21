// FPGA Synthesizer — top level
// Nandland Go Board (iCE40 HX1K, 25 MHz)
`include "src/constants.vh"

module SynthTop (
    input  CLK,
    input  RX,
    output TX,
    output LED1, LED2, LED3, LED4,
    output PMOD1,   // MCLK  12.5 MHz
    output PMOD2,   // LRCK  48.828 kHz
    output PMOD3,   // SCLK  3.125 MHz
    output PMOD4    // SDATA
);

  wire [3:0] w_note;
  wire [2:0] w_octave;
  wire       w_gate;
  wire       w_high;
  wire [1:0] w_wave;
  wire [3:0] w_v0_note;
  wire       w_v0_high;
  wire       w_v0_gate;
  wire [3:0] w_v1_note;
  wire       w_v1_high;
  wire       w_v1_gate;
  wire [7:0] w_attack;
  wire [7:0] w_decay;
  wire [7:0] w_sustain;
  wire [7:0] w_release;
  wire [7:0] w_cutoff;
  wire [7:0] w_res;
  wire [7:0] w_fenv_amt;
  wire [7:0] w_fdecay;
  wire [7:0] w_drive;
  wire [7:0] w_fm_index;
  wire [7:0] w_fm_ratio;
  wire [7:0] w_fold;
  wire       w_v0_accent;
  wire       w_v0_slide;
  wire       w_v1_accent;
  wire       w_v1_slide;
  wire       w_vcf_acc;
  wire       w_note_trig;
  wire       w_seq_play;
  wire [7:0] w_bpm;
  wire [4:0] w_seq_len;
  wire       w_seq_we;
  wire [3:0] w_seq_waddr;
  wire [7:0] w_seq_wdata;

  uart_top u_uart (
    .i_CLK        (CLK),
    .i_RX_Serial  (RX),
    .o_TX_Serial  (TX),
    .o_note       (w_note),
    .o_octave     (w_octave),
    .o_gate       (w_gate),
    .o_high       (w_high),
    .o_wave       (w_wave),
    .o_v0_note    (w_v0_note),
    .o_v0_high    (w_v0_high),
    .o_v0_gate    (w_v0_gate),
    .o_v1_note    (w_v1_note),
    .o_v1_high    (w_v1_high),
    .o_v1_gate    (w_v1_gate),
    .o_attack     (w_attack),
    .o_decay      (w_decay),
    .o_sustain    (w_sustain),
    .o_release    (w_release),
    .o_cutoff     (w_cutoff),
    .o_res        (w_res),
    .o_fenv_amt   (w_fenv_amt),
    .o_fdecay     (w_fdecay),
    .o_drive      (w_drive),
    .o_fm_index   (w_fm_index),
    .o_fm_ratio   (w_fm_ratio),
    .o_fold       (w_fold),
    .o_accent     (),
    .o_slide      (),
    .o_v0_accent  (w_v0_accent),
    .o_v0_slide   (w_v0_slide),
    .o_v1_accent  (w_v1_accent),
    .o_v1_slide   (w_v1_slide),
    .o_vcf_accent (w_vcf_acc),
    .o_seq_play   (w_seq_play),
    .o_bpm        (w_bpm),
    .o_seq_len    (w_seq_len),
    .o_seq_we     (w_seq_we),
    .o_seq_waddr  (w_seq_waddr),
    .o_seq_wdata  (w_seq_wdata),
    .o_note_trig  (w_note_trig)
  );

  wire [15:0] w_sample0;
  wire [15:0] w_sample1;
  wire        w_DV;

  wire [3:0] w_sq_note;
  wire       w_sq_high;
  wire       w_sq_gate;
  wire       w_sq_acc;
  wire       w_sq_sld;
  wire       w_sq_trig;
  wire [3:0] w_live_n0;
  wire       w_live_h0;
  wire       w_live_g0;
  wire       w_live_a0;
  wire       w_live_s0;
  wire       w_live_g1;
  wire       w_live_trig;
  wire       w_live_vacc;

`ifdef SKIP_SEQ
  assign w_sq_note  = 4'd0;
  assign w_sq_high  = 1'b0;
  assign w_sq_gate  = 1'b0;
  assign w_sq_acc   = 1'b0;
  assign w_sq_sld   = 1'b0;
  assign w_sq_trig  = 1'b0;
`else
  seq u_seq (
    .i_CLK    (CLK),
    .i_DV     (w_DV),
    .i_play   (w_seq_play),
    .i_bpm    (w_bpm),
    .i_len    (w_seq_len),
    .i_we     (w_seq_we),
    .i_waddr  (w_seq_waddr),
    .i_wdata  (w_seq_wdata),
    .o_note   (w_sq_note),
    .o_high   (w_sq_high),
    .o_gate   (w_sq_gate),
    .o_accent (w_sq_acc),
    .o_slide  (w_sq_sld),
    .o_trig   (w_sq_trig),
    .o_step   ()
  );
`endif

  assign w_live_n0   = w_seq_play ? w_sq_note : w_v0_note;
  assign w_live_h0   = w_seq_play ? w_sq_high : w_v0_high;
  assign w_live_g0   = w_seq_play ? w_sq_gate : w_v0_gate;
  assign w_live_a0   = w_seq_play ? w_sq_acc  : w_v0_accent;
  assign w_live_s0   = w_seq_play ? w_sq_sld  : w_v0_slide;
  assign w_live_g1   = w_seq_play ? 1'b0      : w_v1_gate;
  assign w_live_trig = w_seq_play ? w_sq_trig : w_note_trig;
  assign w_live_vacc = w_seq_play ? w_sq_acc  : w_vcf_acc;

  voice u_voice0 (
    .i_CLK     (CLK),
    .i_note    (w_live_n0),
    .i_octave  (w_octave),
    .i_gate    (w_live_g0),
    .i_high    (w_live_h0),
    .i_wave    (w_wave),
    .i_attack  (w_attack),
    .i_decay   (w_decay),
    .i_sustain (w_sustain),
    .i_release (w_release),
    .i_slide     (w_live_s0),
    .i_accent    (w_live_a0),
    .i_fm_index  (w_fm_index),
    .i_fm_ratio  (w_fm_ratio),
    .i_fold      (w_fold),
    .i_DV        (w_DV),
    .o_sample    (w_sample0)
  );

  generate
    if (`NUM_VOICES == 2)
    begin : g_poly
      voice u_voice1 (
        .i_CLK     (CLK),
        .i_note    (w_v1_note),
        .i_octave  (w_octave),
        .i_gate    (w_live_g1),
        .i_high    (w_v1_high),
        .i_wave    (w_wave),
        .i_attack  (w_attack),
        .i_decay   (w_decay),
        .i_sustain (w_sustain),
        .i_release (w_release),
        .i_slide     (w_v1_slide),
        .i_accent    (w_v1_accent),
        .i_fm_index  (w_fm_index),
        .i_fm_ratio  (w_fm_ratio),
        .i_fold      (w_fold),
        .i_DV        (w_DV),
        .o_sample    (w_sample1)
      );
    end
    else
    begin : g_mono
      assign w_sample1 = 16'd0;
    end
  endgenerate

  wire signed [16:0] w_mix =
    $signed({w_sample0[15], w_sample0}) + $signed({w_sample1[15], w_sample1});
  wire [15:0] w_mixed =
    (w_mix >  17'sd32767)  ? 16'h7FFF :
    (w_mix < -17'sd32768)  ? 16'h8000 :
    w_mix[15:0];

  wire [8:0] w_res_sum =
    {1'b0, w_res} + (w_live_vacc ? {1'b0, `ACCENT_RES} : 9'd0);
  wire [7:0] w_res_eff =
    (w_res_sum > 9'd255) ? 8'd255 : w_res_sum[7:0];
  wire [8:0] w_drv_sum =
    {1'b0, w_drive} + (w_live_vacc ? {1'b0, `ACCENT_DRIVE} : 9'd0);
  wire [7:0] w_drv_eff =
    (w_drv_sum > 9'd255) ? 8'd255 : w_drv_sum[7:0];

  wire [15:0] w_sample;

`ifdef SKIP_FILTER
  assign w_sample = w_mixed;
`else
  wire [15:0] w_filt;

  vcf u_vcf (
    .i_CLK      (CLK),
    .i_DV       (w_DV),
    .i_trig     (w_live_trig),
    .i_sample   (w_mixed),
    .i_cutoff   (w_cutoff),
    .i_res      (w_res_eff),
    .i_fenv_amt (w_fenv_amt),
    .i_fdecay   (w_fdecay),
    .o_sample   (w_filt)
  );

  drive u_drive (
    .i_CLK    (CLK),
    .i_DV     (w_DV),
    .i_sample (w_filt),
    .i_drive  (w_drv_eff),
    .o_sample (w_sample)
  );
`endif

  i2s_tx u_i2s (
    .i_CLK    (CLK),
    .i_sample (w_sample),
    .o_MCLK   (PMOD1),
    .o_LRCK   (PMOD2),
    .o_SCLK   (PMOD3),
    .o_SDATA  (PMOD4),
    .o_DV     (w_DV)
  );

  assign LED1 = w_seq_play ? w_sq_gate : w_gate;
  assign LED2 = w_octave[0];
  assign LED3 = w_octave[1];
  assign LED4 = w_octave[2];

endmodule

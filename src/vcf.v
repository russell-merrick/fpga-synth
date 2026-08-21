// Resonant lowpass (Chamberlin SVF) + decay-only filter envelope.
// Runs a 4-cycle pipeline after each i_DV so the 18x18 muls meet 25 MHz.
// i_trig retriggers the filter env.
`include "src/constants.vh"

module vcf (
    input             i_CLK,
    input             i_DV,
    input             i_trig,
    input      [15:0] i_sample,
    input      [7:0]  i_cutoff,
    input      [7:0]  i_res,
    input      [7:0]  i_fenv_amt,
    input      [7:0]  i_fdecay,
    output     [15:0] o_sample
);

  localparam signed [31:0] CLIP_P = 32'sd131071;
  localparam signed [31:0] CLIP_N = -32'sd131072;

  localparam STEP_IDLE = 2'd0;
  localparam STEP_ADD  = 2'd1;
  localparam STEP_FMUL = 2'd2;
  localparam STEP_BAND = 2'd3;

  // Boot with a pending trig so idle A4 already sweeps.
  reg        r_pend_trig = 1'b1;
  reg [19:0] r_fenv      = 20'd0;
  reg [15:0] r_out       = 16'd0;
  reg [1:0]  r_step      = STEP_IDLE;
  reg signed [31:0] r_low  = 32'sd0;
  reg signed [31:0] r_band = 32'sd0;
  reg signed [31:0] r_in   = 32'sd0;
  reg signed [31:0] r_high = 32'sd0;
  reg signed [31:0] r_fb   = 32'sd0;
  reg signed [31:0] r_qb   = 32'sd0;
  reg signed [31:0] r_fh   = 32'sd0;

  // 8x8 must be widened or Verilog truncates the product to 8 bits.
  wire [15:0] w_env_add = {8'd0, r_fenv[19:12]} * {8'd0, i_fenv_amt};
  wire [9:0]  w_cut_sum =
    {2'b00, i_cutoff} + {2'b00, w_env_add[15:8]};
  wire [7:0] w_cut_eff =
    (w_cut_sum > 10'd255) ? 8'd255 : w_cut_sum[7:0];

  // Q15 coefficient, kept below ~0.5 for Chamberlin stability.
  wire [15:0] w_f = 16'd512 + ({8'd0, w_cut_eff} << 6);

  // Higher res → lower damping.
  wire [16:0] w_q_sub = {9'd0, i_res} * 17'd88;
  wire [15:0] w_q =
    (w_q_sub > 17'd17600) ? 16'h0480 : (16'h4C00 - w_q_sub[15:0]);

  wire signed [17:0] w_f18    = $signed({2'b00, w_f});
  wire signed [17:0] w_q18    = $signed({2'b00, w_q});
  wire signed [17:0] w_band18 = r_band[17:0];
  wire signed [17:0] w_high18 = r_high[17:0];

  // Verilog * is max(W(a),W(b)) wide — extend both sides to 36 for 18x18.
  wire signed [35:0] w_f_ext    = {{18{w_f18[17]}}, w_f18};
  wire signed [35:0] w_q_ext    = {{18{w_q18[17]}}, w_q18};
  wire signed [35:0] w_band_ext = {{18{w_band18[17]}}, w_band18};
  wire signed [35:0] w_high_ext = {{18{w_high18[17]}}, w_high18};

  wire signed [35:0] w_fb = (w_f_ext * w_band_ext) >>> 15;
  wire signed [35:0] w_qb = (w_q_ext * w_band_ext) >>> 15;
  wire signed [35:0] w_fh = (w_f_ext * w_high_ext) >>> 15;

  wire signed [31:0] w_in =
    {{16{i_sample[15]}}, i_sample};
  wire signed [31:0] w_low_n = r_low + r_fb;
  wire signed [31:0] w_high_n = r_in - w_low_n - r_qb;
  wire signed [31:0] w_band_n = r_band + r_fh;

  wire signed [31:0] w_low_clip =
    (w_low_n > CLIP_P) ? CLIP_P :
    (w_low_n < CLIP_N) ? CLIP_N :
    w_low_n;
  wire signed [31:0] w_high_clip =
    (w_high_n > CLIP_P) ? CLIP_P :
    (w_high_n < CLIP_N) ? CLIP_N :
    w_high_n;
  wire signed [31:0] w_band_clip =
    (w_band_n > CLIP_P) ? CLIP_P :
    (w_band_n < CLIP_N) ? CLIP_N :
    w_band_n;

  wire [15:0] w_out16 =
    (r_low >  32'sd32767)  ? 16'h7FFF :
    (r_low < -32'sd32768)  ? 16'h8000 :
    r_low[15:0];

  always @(posedge i_CLK)
  begin
    if (i_trig)
    begin
      r_pend_trig <= 1'b1;
    end

    case (r_step)
      STEP_IDLE:
      begin
        if (i_DV)
        begin
          if (r_pend_trig || i_trig)
          begin
            r_fenv      <= 20'hFFFFF;
            r_pend_trig <= 1'b0;
          end
          else if (r_fenv > {12'd0, i_fdecay})
          begin
            r_fenv <= r_fenv - {12'd0, i_fdecay};
          end
          else
          begin
            r_fenv <= 20'd0;
          end

          r_in   <= w_in;
          r_fb   <= w_fb[31:0];
          r_qb   <= w_qb[31:0];
          r_step <= STEP_ADD;
        end
      end
      STEP_ADD:
      begin
        r_low  <= w_low_clip;
        r_high <= w_high_clip;
        r_step <= STEP_FMUL;
      end
      STEP_FMUL:
      begin
        r_fh   <= w_fh[31:0];
        r_step <= STEP_BAND;
      end
      default:
      begin
        r_band <= w_band_clip;
        r_out  <= w_out16;
        r_step <= STEP_IDLE;
      end
    endcase
  end

  assign o_sample = r_out;

endmodule

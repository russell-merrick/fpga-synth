// Phase accumulator oscillator — one synthesizer voice.
// 2-op FM (sine modulator → carrier wavetable) + 8× oversampled wavefolder,
// then ADSR. Go Board keeps the original 1-sample path (`SKIP_FM`).
`include "src/constants.vh"

module voice (
    input        i_CLK,
    input  [3:0] i_note,
    input  [2:0] i_octave,
    input        i_gate,
    input        i_high,
    input  [1:0] i_wave,    // 0=sine 1=triangle 2=sawtooth 3=square
    input  [7:0] i_attack,
    input  [7:0] i_decay,
    input  [7:0] i_sustain,
    input  [7:0] i_release,
    input        i_slide,
    input        i_accent,
    input  [7:0] i_fm_index,
    input  [7:0] i_fm_ratio,
    input  [7:0] i_fold,
    input        i_DV,
    output [15:0] o_sample
);

  wire [31:0] w_base_inc =
    (i_note == 4'd0)  ? 32'd23_017_594 :
    (i_note == 4'd1)  ? 32'd24_386_283 :
    (i_note == 4'd2)  ? 32'd25_836_353 :
    (i_note == 4'd3)  ? 32'd27_372_642 :
    (i_note == 4'd4)  ? 32'd29_000_342 :
    (i_note == 4'd5)  ? 32'd30_724_730 :
    (i_note == 4'd6)  ? 32'd32_561_722 :
    (i_note == 4'd7)  ? 32'd34_487_328 :
    (i_note == 4'd8)  ? 32'd36_538_119 :
    (i_note == 4'd9)  ? 32'd38_710_760 :
    (i_note == 4'd10) ? 32'd41_012_643 :
    (i_note == 4'd11) ? 32'd43_451_332 :
                        32'd38_710_760;

  wire [2:0] w_oct = i_high && (i_octave < 3'd7) ? i_octave + 3'd1 : i_octave;

  wire [31:0] w_phase_inc =
    (w_oct == 3'd0) ? (w_base_inc >> 4) :
    (w_oct == 3'd1) ? (w_base_inc >> 3) :
    (w_oct == 3'd2) ? (w_base_inc >> 2) :
    (w_oct == 3'd3) ? (w_base_inc >> 1) :
    (w_oct == 3'd4) ? (w_base_inc)      :
    (w_oct == 3'd5) ? (w_base_inc << 1) :
    (w_oct == 3'd6) ? (w_base_inc << 2) :
                      (w_base_inc << 3);

  reg [15:0] r_wave_rom [0:1023];

  initial
  begin
    $readmemh("data/wavetable.hex", r_wave_rom);
  end

  reg [31:0] r_phase  = 32'd0;
  reg [15:0] r_sample = 16'd0;

`ifdef SKIP_FM
`ifdef SKIP_SLIDE

  always @(posedge i_CLK)
  begin
    if (i_DV)
    begin
      r_phase  <= r_phase + w_phase_inc;
      r_sample <= r_wave_rom[{i_wave, r_phase[31:24]}];
    end
  end

`else

  reg [31:0] r_inc = 32'd38_710_760;

  wire [31:0] w_err =
    (w_phase_inc > r_inc) ? (w_phase_inc - r_inc) : (r_inc - w_phase_inc);
  wire [31:0] w_step = w_err >> `SLIDE_SHIFT;
  wire [31:0] w_step1 = (w_step == 32'd0) ? 32'd1 : w_step;

  always @(posedge i_CLK)
  begin
    if (i_DV)
    begin
      if (i_slide)
      begin
        if (w_phase_inc > r_inc)
        begin
          r_inc <= r_inc + w_step1;
        end
        else if (w_phase_inc < r_inc)
        begin
          r_inc <= r_inc - w_step1;
        end
      end
      else
      begin
        r_inc <= w_phase_inc;
      end
      r_phase  <= r_phase + r_inc;
      r_sample <= r_wave_rom[{i_wave, r_phase[31:24]}];
    end
  end

`endif
`else

  // IceSugar: slide + 2-op FM + 8× oversampled folder.
  reg [31:0] r_inc        = 32'd38_710_760;
  reg [31:0] r_mod_phase  = 32'd0;
  reg [31:0] r_ph         = 32'd0;
  reg [31:0] r_mph        = 32'd0;
  reg [3:0]  r_os_cnt     = 4'd0;
  reg signed [19:0] r_acc = 20'sd0;
  reg [15:0] r_mod_s      = 16'd0;
  reg [15:0] r_car_s      = 16'd0;
  reg signed [31:0] r_fm_off = 32'sd0;
  reg signed [15:0] r_folded = 16'sd0;

  wire [31:0] w_err =
    (w_phase_inc > r_inc) ? (w_phase_inc - r_inc) : (r_inc - w_phase_inc);
  wire [31:0] w_step = w_err >> `SLIDE_SHIFT;
  wire [31:0] w_step1 = (w_step == 32'd0) ? 32'd1 : w_step;

  wire [3:0] w_ratio =
    (i_fm_ratio < 8'd1) ? 4'd1 :
    (i_fm_ratio > 8'd8) ? 4'd8 : i_fm_ratio[3:0];
  wire [31:0] w_mod_inc =
    (w_ratio == 4'd1) ? r_inc :
    (w_ratio == 4'd2) ? (r_inc << 1) :
    (w_ratio == 4'd3) ? (r_inc + (r_inc << 1)) :
    (w_ratio == 4'd4) ? (r_inc << 2) :
    (w_ratio == 4'd5) ? (r_inc + (r_inc << 2)) :
    (w_ratio == 4'd6) ? ((r_inc << 2) + (r_inc << 1)) :
    (w_ratio == 4'd7) ? ((r_inc << 3) - r_inc) :
                        (r_inc << 3);

  wire [31:0] w_os_inc     = r_inc >> 3;
  wire [31:0] w_os_mod_inc = w_mod_inc >> 3;

  wire [31:0] w_ph_now  = (r_os_cnt == 4'd0) ? r_phase     : r_ph;
  wire [31:0] w_mph_now = (r_os_cnt == 4'd0) ? r_mod_phase : r_mph;

  wire [15:0] w_mod_rd = r_wave_rom[{2'b00, w_mph_now[31:24]}];
  wire signed [23:0] w_ma = {{8{r_mod_s[15]}}, r_mod_s};
  wire signed [23:0] w_mb = {16'd0, i_fm_index};
  wire signed [23:0] w_mp = w_ma * w_mb;
  wire [31:0] w_car_ph = w_ph_now + r_fm_off;
  wire [15:0] w_car_rd = r_wave_rom[{i_wave, w_car_ph[31:24]}];

  wire [9:0] w_gain = 10'd256 + {1'b0, i_fold, 1'b0};
  wire signed [31:0] w_xg =
    $signed({{16{r_car_s[15]}}, r_car_s}) * $signed({22'd0, w_gain});
  wire signed [31:0] w_xs = w_xg >>> 8;
  wire signed [31:0] w_f1 =
    (w_xs >  32'sd32767)  ? (32'sd65535 - w_xs) :
    (w_xs < -32'sd32768)  ? (-32'sd65536 - w_xs) :
    w_xs;
  wire signed [31:0] w_f2 =
    (w_f1 >  32'sd32767)  ? (32'sd65535 - w_f1) :
    (w_f1 < -32'sd32768)  ? (-32'sd65536 - w_f1) :
    w_f1;
  wire signed [15:0] w_folded =
    (w_f2 >  32'sd32767)  ? 16'sh7FFF :
    (w_f2 < -32'sd32768)  ? 16'sh8000 :
    w_f2[15:0];

  always @(posedge i_CLK)
  begin
    if (i_DV && (r_os_cnt == 4'd0))
    begin
      if (i_slide)
      begin
        if (w_phase_inc > r_inc)
        begin
          r_inc <= r_inc + w_step1;
        end
        else if (w_phase_inc < r_inc)
        begin
          r_inc <= r_inc - w_step1;
        end
      end
      else
      begin
        r_inc <= w_phase_inc;
      end

      r_acc      <= 20'sd0;
      r_ph       <= r_phase + w_os_inc;
      r_mph      <= r_mod_phase + w_os_mod_inc;
      r_os_cnt   <= 4'd1;
      r_mod_s    <= w_mod_rd;
      r_fm_off   <= {{8{w_mp[23]}}, w_mp} <<< 10;
      r_car_s    <= w_car_rd;
      r_folded   <= w_folded;
    end
    else if (r_os_cnt == 4'd12)
    begin
      r_sample    <= r_acc[18:3];
      r_phase     <= r_ph;
      r_mod_phase <= r_mph;
      r_os_cnt    <= 4'd0;
    end
    else if (r_os_cnt != 4'd0)
    begin
      r_mod_s  <= w_mod_rd;
      r_fm_off <= {{8{w_mp[23]}}, w_mp} <<< 10;
      r_car_s  <= w_car_rd;
      r_folded <= w_folded;

      if (r_os_cnt >= 4'd4)
      begin
        r_acc <= r_acc + {{4{r_folded[15]}}, r_folded};
      end

      if (r_os_cnt < 4'd8)
      begin
        r_ph  <= r_ph + w_os_inc;
        r_mph <= r_mph + w_os_mod_inc;
      end

      r_os_cnt <= r_os_cnt + 4'd1;
    end
  end

`endif

  wire [15:0] w_env;

  adsr u_adsr (
    .i_CLK     (i_CLK),
    .i_DV      (i_DV),
    .i_gate    (i_gate),
    .i_attack  (i_attack),
    .i_decay   (i_decay),
    .i_sustain (i_sustain),
    .i_release (i_release),
    .o_env     (w_env)
  );

  // Top 8 bits of envelope → 16×9 multiply instead of 16×16, saving ~350 LCs (HX1K has no DSP blocks).
  // Accent ≈ 1.5× VCA (303 louder + fatter).
  wire [7:0] w_env_hi = w_env[14:7];
  wire [8:0] w_env_sum = {1'b0, w_env_hi} + (i_accent ? {2'b00, w_env_hi[7:1]} : 9'd0);
  wire [7:0] w_env_use = (w_env_sum > 9'd255) ? 8'd255 : w_env_sum[7:0];
  wire signed [23:0] w_product = $signed(r_sample) * $signed({1'b0, w_env_use});
  assign o_sample = w_product[23:8];

endmodule

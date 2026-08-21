// 16-step 16th-note sequencer. Pattern byte:
//   [7] rest  [6] accent  [5] slide  [4] +oct  [3:0] note
`include "src/constants.vh"

module seq (
    input            i_CLK,
    input            i_DV,
    input            i_play,
    input      [7:0] i_bpm,
    input      [4:0] i_len,
    input            i_we,
    input      [3:0] i_waddr,
    input      [7:0] i_wdata,
    output     [3:0] o_note,
    output           o_high,
    output           o_gate,
    output           o_accent,
    output           o_slide,
    output reg       o_trig,
    output     [3:0] o_step
);

  // 16th clock: add bpm*23 to 24-bit phase; overflow ≈ fs*15/bpm.
  localparam [7:0] PH_MUL = 8'd23;

  reg [7:0] r_pat [0:15];
  reg [3:0] r_step = 4'd0;
  reg [23:0] r_ph = 24'd0;
  reg        r_play_d = 1'b0;
  reg        r_gate = 1'b0;
  reg [3:0]  r_note = 4'd0;
  reg        r_high = 1'b0;
  reg        r_acc = 1'b0;
  reg        r_sld = 1'b0;

  initial
  begin
    // A-minor acid line, octave from uart (default 3).
    r_pat[0]  = 8'h09;  // A
    r_pat[1]  = 8'h09;  // A
    r_pat[2]  = 8'h00;  // C
    r_pat[3]  = 8'h09;  // A
    r_pat[4]  = 8'h02;  // D
    r_pat[5]  = 8'h04;  // E
    r_pat[6]  = 8'h22;  // D slide
    r_pat[7]  = 8'h00;  // C
    r_pat[8]  = 8'h09;  // A
    r_pat[9]  = 8'h07;  // G
    r_pat[10] = 8'h09;  // A
    r_pat[11] = 8'h40;  // C accent
    r_pat[12] = 8'h02;  // D
    r_pat[13] = 8'h00;  // C
    r_pat[14] = 8'h09;  // A
    r_pat[15] = 8'h07;  // G
  end

  wire [7:0] w_bpm =
    (i_bpm < 8'd40) ? 8'd40 :
    (i_bpm > 8'd240) ? 8'd240 : i_bpm;
  wire [15:0] w_ph_add = {8'd0, w_bpm} * {8'd0, PH_MUL};

  wire [3:0] w_last =
    (i_len == 5'd0) || (i_len > 5'd16) ? 4'd15 : (i_len[3:0] - 4'd1);
  wire [3:0] w_next = (r_step >= w_last) ? 4'd0 : (r_step + 4'd1);
  wire       w_play_rise = i_play & ~r_play_d;

  wire [24:0] w_sum = {1'b0, r_ph} + {9'd0, w_ph_add};
  wire        w_wrap = i_DV & w_sum[24];
  wire [3:0] w_idx = w_play_rise ? 4'd0 :
                     w_wrap ? w_next : r_step;
  wire [7:0] w_st = r_pat[w_idx];
  wire       w_rest = w_st[7];
  wire       w_sld  = w_st[5] & ~w_rest;

  always @(posedge i_CLK)
  begin
    r_play_d <= i_play;
    o_trig   <= 1'b0;

    if (i_we)
    begin
      r_pat[i_waddr] <= i_wdata;
    end

    if (!i_play)
    begin
      r_ph      <= 24'd0;
      r_step    <= 4'd0;
      r_gate    <= 1'b0;
      r_sld     <= 1'b0;
      r_acc     <= 1'b0;
    end
    else if (w_play_rise)
    begin
      r_step    <= 4'd0;
      r_ph      <= 24'd0;
      r_note    <= w_st[3:0];
      r_high    <= w_st[4];
      r_acc     <= w_st[6] & ~w_rest;
      r_sld     <= w_sld;
      r_gate    <= ~w_rest;
      o_trig    <= ~w_rest & ~w_sld;
    end
    else if (i_DV)
    begin
      r_ph <= w_sum[23:0];
      if (w_sum[24])
      begin
        r_step    <= w_next;
        r_note    <= w_st[3:0];
        r_high    <= w_st[4];
        r_acc     <= w_st[6] & ~w_rest;
        r_sld     <= w_sld;
        r_gate    <= ~w_rest;
        o_trig    <= ~w_rest & ~w_sld;
      end
    end
  end

  assign o_note   = r_note;
  assign o_high   = r_high;
  assign o_gate   = r_gate;
  assign o_accent = r_acc;
  assign o_slide  = r_sld;
  assign o_step   = r_step;

endmodule

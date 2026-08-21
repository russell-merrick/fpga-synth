// Soft-saturating overdrive after the VCF.
// gain = 1 + i_drive/128  (0 → unity, 255 → ~3×) then a knee into clip.
`include "src/constants.vh"

module drive (
    input         i_CLK,
    input         i_DV,
    input  [15:0] i_sample,
    input  [7:0]  i_drive,
    output [15:0] o_sample
);

  // 256 + (drive << 1) → 256..766. Multiply then >>> 8.
  wire [9:0] w_gain = 10'd256 + {1'b0, i_drive, 1'b0};

  wire signed [41:0] w_s_ext = {{26{i_sample[15]}}, i_sample};
  wire signed [41:0] w_g_ext = {32'd0, w_gain};
  wire signed [41:0] w_prod  = w_s_ext * w_g_ext;
  wire signed [41:0] w_y     = w_prod >>> 8;

  // Knee at ±24576; leftover compressed 4:1, then hard sat to 16-bit.
  wire signed [31:0] w_y32 = w_y[31:0];
  wire signed [31:0] w_knee_p =
    (w_y32 >  32'sd24576) ? (32'sd24576 + ((w_y32 - 32'sd24576) >>> 2)) :
    (w_y32 < -32'sd24576) ? (-32'sd24576 + ((w_y32 + 32'sd24576) >>> 2)) :
    w_y32;
  wire [15:0] w_sat =
    (w_knee_p >  32'sd32767)  ? 16'h7FFF :
    (w_knee_p < -32'sd32768)  ? 16'h8000 :
    w_knee_p[15:0];

  reg [15:0] r_out = 16'd0;

  always @(posedge i_CLK)
  begin
    if (i_DV)
    begin
      r_out <= w_sat;
    end
  end

  assign o_sample = r_out;

endmodule

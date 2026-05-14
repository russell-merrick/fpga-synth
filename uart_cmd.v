// UART command decoder — Ableton Computer MIDI Keyboard layout
//
// Receives decoded bytes from UART_RX and maps them to synth control signals.
// No UART timing logic here — just the command table.
//
// Note index: 0=C 1=C# 2=D 3=D# 4=E 5=F 6=F# 7=G 8=G# 9=A 10=A# 11=B
`include "constants.vh"

module uart_cmd (
    input            CLK,
    input            i_RX_DV,     // one-cycle pulse when a byte is ready
    input  [7:0]     i_RX_Byte,   // received byte

    output reg [3:0] o_note,      // 0–11
    output reg [2:0] o_octave,    // 0–7
    output reg       o_gate,      // 1 = playing
    output reg       o_high       // 1 = 'k' key (C one octave above o_octave)
);

  initial begin
    o_note   = `DEFAULT_NOTE;
    o_octave = `DEFAULT_OCTAVE;
    o_gate   = 1'b1;
    o_high   = 1'b0;
  end

  always @(posedge CLK) begin
    if (i_RX_DV) begin
      case (i_RX_Byte)
        8'h61: begin o_note <= 4'd0;  o_high <= 0; o_gate <= 1; end  // a → C
        8'h77: begin o_note <= 4'd1;  o_high <= 0; o_gate <= 1; end  // w → C#
        8'h73: begin o_note <= 4'd2;  o_high <= 0; o_gate <= 1; end  // s → D
        8'h65: begin o_note <= 4'd3;  o_high <= 0; o_gate <= 1; end  // e → D#
        8'h64: begin o_note <= 4'd4;  o_high <= 0; o_gate <= 1; end  // d → E
        8'h66: begin o_note <= 4'd5;  o_high <= 0; o_gate <= 1; end  // f → F
        8'h74: begin o_note <= 4'd6;  o_high <= 0; o_gate <= 1; end  // t → F#
        8'h67: begin o_note <= 4'd7;  o_high <= 0; o_gate <= 1; end  // g → G
        8'h79: begin o_note <= 4'd8;  o_high <= 0; o_gate <= 1; end  // y → G#
        8'h68: begin o_note <= 4'd9;  o_high <= 0; o_gate <= 1; end  // h → A
        8'h75: begin o_note <= 4'd10; o_high <= 0; o_gate <= 1; end  // u → A#
        8'h6A: begin o_note <= 4'd11; o_high <= 0; o_gate <= 1; end  // j → B
        8'h6B: begin o_note <= 4'd0;  o_high <= 1; o_gate <= 1; end  // k → C+1oct
        8'h7A: if (o_octave > 0) o_octave <= o_octave - 1;           // z → down
        8'h78: if (o_octave < 7) o_octave <= o_octave + 1;           // x → up
        8'h20: o_gate <= ~o_gate;                                      // space → toggle
      endcase
    end
  end

endmodule

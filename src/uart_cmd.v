// UART command decoder — Ableton Computer MIDI Keyboard layout
//
// Receives decoded bytes from UART_RX and maps them to synth control signals.
// Two-voice allocator: each note key is assigned round-robin. Space mutes
// both voices (same as the original gate toggle). Wave and octave are shared.
//
// Note index: 0=C 1=C# 2=D 3=D# 4=E 5=F 6=F# 7=G 8=G# 9=A 10=A# 11=B
`include "src/constants.vh"

module uart_cmd (
    input            i_CLK,
    input            i_RX_DV,     // one-cycle pulse when a byte is ready
    input  [7:0]     i_RX_Byte,   // received byte

    output reg [3:0] o_note,      // last note (tests / LED)
    output reg [2:0] o_octave,    // 0–7, shared
    output reg       o_gate,      // 1 = at least one voice not muted
    output reg       o_high,      // last note's +1 octave flag
    output reg [1:0] o_wave,      // 0=sine 1=triangle 2=sawtooth 3=square

    output [3:0]     o_v0_note,
    output           o_v0_high,
    output           o_v0_gate,
    output [3:0]     o_v1_note,
    output           o_v1_high,
    output           o_v1_gate
);

  wire w_note_key =
    (i_RX_Byte == 8'h61) || (i_RX_Byte == 8'h77) || (i_RX_Byte == 8'h73) ||
    (i_RX_Byte == 8'h65) || (i_RX_Byte == 8'h64) || (i_RX_Byte == 8'h66) ||
    (i_RX_Byte == 8'h74) || (i_RX_Byte == 8'h67) || (i_RX_Byte == 8'h79) ||
    (i_RX_Byte == 8'h68) || (i_RX_Byte == 8'h75) || (i_RX_Byte == 8'h6A) ||
    (i_RX_Byte == 8'h6B);

  wire [3:0] w_key_note =
    (i_RX_Byte == 8'h61) ? 4'd0  :
    (i_RX_Byte == 8'h77) ? 4'd1  :
    (i_RX_Byte == 8'h73) ? 4'd2  :
    (i_RX_Byte == 8'h65) ? 4'd3  :
    (i_RX_Byte == 8'h64) ? 4'd4  :
    (i_RX_Byte == 8'h66) ? 4'd5  :
    (i_RX_Byte == 8'h74) ? 4'd6  :
    (i_RX_Byte == 8'h67) ? 4'd7  :
    (i_RX_Byte == 8'h79) ? 4'd8  :
    (i_RX_Byte == 8'h68) ? 4'd9  :
    (i_RX_Byte == 8'h75) ? 4'd10 :
    (i_RX_Byte == 8'h6A) ? 4'd11 :
                           4'd0;   // k → C

  wire w_key_high = (i_RX_Byte == 8'h6B);

  reg [3:0] r_note0  = `DEFAULT_NOTE;
  reg [3:0] r_note1  = 4'd0;
  reg       r_high0  = 1'b0;
  reg       r_high1  = 1'b0;
  reg       r_vgate0 = 1'b1;
  reg       r_vgate1 = 1'b0;
  reg       r_mute   = 1'b0;
  reg       r_next   = 1'b1;   // first key after boot → voice 1 (voice 0 holds default A)

  initial
  begin
    o_note   = `DEFAULT_NOTE;
    o_octave = `DEFAULT_OCTAVE;
    o_gate   = 1'b1;
    o_high   = 1'b0;
    o_wave   = `DEFAULT_WAVE;
  end

  always @(posedge i_CLK)
  begin
    if (i_RX_DV)
    begin
      case (i_RX_Byte)
        8'h61:
        begin
          o_note <= 4'd0;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // a → C
        8'h77:
        begin
          o_note <= 4'd1;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // w → C#
        8'h73:
        begin
          o_note <= 4'd2;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // s → D
        8'h65:
        begin
          o_note <= 4'd3;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // e → D#
        8'h64:
        begin
          o_note <= 4'd4;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // d → E
        8'h66:
        begin
          o_note <= 4'd5;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // f → F
        8'h74:
        begin
          o_note <= 4'd6;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // t → F#
        8'h67:
        begin
          o_note <= 4'd7;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // g → G
        8'h79:
        begin
          o_note <= 4'd8;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // y → G#
        8'h68:
        begin
          o_note <= 4'd9;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // h → A
        8'h75:
        begin
          o_note <= 4'd10;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // u → A#
        8'h6A:
        begin
          o_note <= 4'd11;
          o_high <= 1'b0;
          o_gate <= 1'b1;
        end  // j → B
        8'h6B:
        begin
          o_note <= 4'd0;
          o_high <= 1'b1;
          o_gate <= 1'b1;
        end  // k → C+1oct
        8'h7A:
        begin
          if (o_octave > 3'd0)
          begin
            o_octave <= o_octave - 3'd1;
          end
        end  // z → down
        8'h78:
        begin
          if (o_octave < 3'd7)
          begin
            o_octave <= o_octave + 3'd1;
          end
        end  // x → up
        8'h20:
        begin
          o_gate <= ~o_gate;
          r_mute <= o_gate;
        end  // space → mute both
        8'h31:
        begin
          o_wave <= 2'd0;
        end  // 1 → sine
        8'h32:
        begin
          o_wave <= 2'd1;
        end  // 2 → triangle
        8'h33:
        begin
          o_wave <= 2'd2;
        end  // 3 → sawtooth
        8'h34:
        begin
          o_wave <= 2'd3;
        end  // 4 → square
      endcase

      if (w_note_key)
      begin
        r_mute <= 1'b0;
        if ((`NUM_VOICES == 1) || (r_next == 1'b0))
        begin
          r_note0  <= w_key_note;
          r_high0  <= w_key_high;
          r_vgate0 <= 1'b1;
        end
        else
        begin
          r_note1  <= w_key_note;
          r_high1  <= w_key_high;
          r_vgate1 <= 1'b1;
        end
        if (`NUM_VOICES != 1)
        begin
          r_next <= ~r_next;
        end
      end
    end
  end

  assign o_v0_note = r_note0;
  assign o_v0_high = r_high0;
  assign o_v0_gate = r_vgate0 & ~r_mute;
  assign o_v1_note = r_note1;
  assign o_v1_high = r_high1;
  assign o_v1_gate = r_vgate1 & ~r_mute;

endmodule

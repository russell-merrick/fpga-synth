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
    output           o_v1_gate,

    output [7:0]     o_attack,
    output [7:0]     o_decay,
    output [7:0]     o_sustain,
    output [7:0]     o_release,
    output [3:0]     o_param_sel,    // 0A 1D 2S 3R 4C 5Q 6E 7K 8O 9I 10N 11L
    output [7:0]     o_cutoff,
    output [7:0]     o_res,
    output [7:0]     o_fenv_amt,
    output [7:0]     o_fdecay,
    output [7:0]     o_drive,
    output [7:0]     o_fm_index,
    output [7:0]     o_fm_ratio,
    output [7:0]     o_fold,
    output           o_accent,       // sticky accent mode
    output           o_slide,        // sticky slide mode
    output           o_v0_accent,
    output           o_v0_slide,
    output           o_v1_accent,
    output           o_v1_slide,
    output           o_vcf_accent,   // last non-slide note's accent
    output           o_seq_play,
    output     [7:0] o_bpm,
    output     [4:0] o_seq_len,
    output reg       o_seq_we,
    output reg [3:0] o_seq_waddr,
    output reg [7:0] o_seq_wdata,
    output reg       o_note_trig,
    output reg       o_print_help,
    output reg       o_print_status
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
  reg [7:0] r_attack  = `DEFAULT_ATTACK;
  reg [7:0] r_decay   = `DEFAULT_DECAY;
  reg [7:0] r_sustain = `DEFAULT_SUSTAIN;
  reg [7:0] r_release = `DEFAULT_RELEASE;
  reg [3:0] r_param_sel = 4'd0;
  reg [7:0] r_cutoff    = `DEFAULT_CUTOFF;
  reg [7:0] r_res       = `DEFAULT_RES;
  reg [7:0] r_fenv_amt  = `DEFAULT_FENV;
  reg [7:0] r_fdecay    = `DEFAULT_FDECAY;
  reg [7:0] r_drive     = `DEFAULT_DRIVE;
  reg [7:0] r_fm_index  = `DEFAULT_FM_INDEX;
  reg [7:0] r_fm_ratio  = `DEFAULT_FM_RATIO;
  reg [7:0] r_fold      = `DEFAULT_FOLD;
  reg       r_acc_mode  = 1'b0;
  reg       r_sld_mode  = 1'b0;
  reg       r_acc0      = 1'b0;
  reg       r_acc1      = 1'b0;
  reg       r_sld0      = 1'b0;
  reg       r_sld1      = 1'b0;
  reg       r_last      = 1'b0;   // last voice written (slide stays here)
  reg       r_vcf_acc   = 1'b0;
  reg       r_play      = 1'b0;
  reg [7:0] r_bpm       = `DEFAULT_BPM;
  reg [4:0] r_seq_len   = `DEFAULT_SEQ_LEN;
  reg       r_line      = 1'b0;
  reg [5:0] r_llen      = 6'd0;
  reg [7:0] r_lbuf [0:35];
  reg       r_jload     = 1'b0;
  reg [3:0] r_ji        = 4'd0;

  initial
  begin
    o_note   = `DEFAULT_NOTE;
    o_octave = `DEFAULT_OCTAVE;
    o_gate   = 1'b1;
    o_high   = 1'b0;
    o_wave   = `DEFAULT_WAVE;
    o_print_help   = 1'b0;
    o_print_status = 1'b0;
    o_note_trig    = 1'b0;
    o_seq_we       = 1'b0;
    o_seq_waddr    = 4'd0;
    o_seq_wdata    = 8'd0;
  end

  function [3:0] hexn;
    input [7:0] c;
    begin
      if ((c >= 8'h30) && (c <= 8'h39))
        hexn = c[3:0];
      else if ((c >= 8'h41) && (c <= 8'h46))
        hexn = c - 8'h37;
      else if ((c >= 8'h61) && (c <= 8'h66))
        hexn = c - 8'h57;
      else
        hexn = 4'd0;
    end
  endfunction

  function [7:0] dec_val;
    input [7:0] c0;
    input [7:0] c1;
    input [7:0] c2;
    input [5:0] n;
    reg [7:0] v;
    begin
      v = 8'd0;
      if (n >= 6'd2)
      begin
        v = c0 - 8'h30;
      end
      if (n >= 6'd3)
      begin
        v = (v * 8'd10) + (c1 - 8'h30);
      end
      if (n >= 6'd4)
      begin
        v = (v * 8'd10) + (c2 - 8'h30);
      end
      dec_val = v;
    end
  endfunction

  always @(posedge i_CLK)
  begin
    o_print_help   <= 1'b0;
    o_print_status <= 1'b0;
    o_note_trig    <= 1'b0;
    o_seq_we       <= 1'b0;

`ifndef SKIP_SEQ
    if (r_jload)
    begin
      o_seq_we    <= 1'b1;
      o_seq_waddr <= r_ji;
      o_seq_wdata <= {hexn(r_lbuf[6'd1 + {1'b0, r_ji, 1'b0}]),
                      hexn(r_lbuf[6'd2 + {1'b0, r_ji, 1'b0}])};
      if (r_ji == 4'd15)
      begin
        r_jload <= 1'b0;
      end
      else
      begin
        r_ji <= r_ji + 4'd1;
      end
    end
`endif

    if (i_RX_DV)
    begin
`ifndef SKIP_SEQ
      if (r_line)
      begin
        if ((i_RX_Byte == 8'h0A) || (i_RX_Byte == 8'h0D))
        begin
          r_line <= 1'b0;
          if (r_llen >= 6'd1)
          begin
            o_print_status <= 1'b1;
            case (r_lbuf[0])
              8'h41, 8'h61: r_attack   <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h44, 8'h64: r_decay    <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h53, 8'h73: r_sustain  <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h52, 8'h72: r_release  <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h43, 8'h63: r_cutoff   <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h51, 8'h71: r_res      <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h45, 8'h65: r_fenv_amt <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h4B, 8'h6B: r_fdecay   <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h4F, 8'h6F: r_drive    <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h49, 8'h69: r_fm_index <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h4E, 8'h6E:
              begin
                r_fm_ratio <= (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) < 8'd1)
                            ? 8'd1 :
                              (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) > 8'd8)
                            ? 8'd8 : dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              end
              8'h4C, 8'h6C: r_fold     <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h42, 8'h62: r_bpm      <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              8'h58, 8'h78:
              begin
                o_octave <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              end
              8'h57, 8'h77:
              begin
                o_wave <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
              end
              8'h50, 8'h70:
              begin
                r_play <= (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) != 8'd0);
                if (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) == 8'd0)
                begin
                  r_mute <= 1'b1;
                  o_gate <= 1'b0;
                end
              end
              8'h59, 8'h79:
              begin
                if (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) > 8'd16)
                begin
                  r_seq_len <= 5'd16;
                end
                else if (dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen) < 8'd1)
                begin
                  r_seq_len <= 5'd1;
                end
                else
                begin
                  r_seq_len <= dec_val(r_lbuf[1], r_lbuf[2], r_lbuf[3], r_llen);
                end
              end
              8'h4A, 8'h6A:
              begin
                if (r_llen >= 6'd33)
                begin
                  r_jload <= 1'b1;
                  r_ji    <= 4'd0;
                end
              end
              default:
              begin
              end
            endcase
          end
        end
        else if (r_llen < 6'd36)
        begin
          r_lbuf[r_llen] <= i_RX_Byte;
          r_llen         <= r_llen + 6'd1;
        end
      end
      else if (i_RX_Byte == 8'h3A)
      begin
        r_line <= 1'b1;
        r_llen <= 6'd0;
      end
      else
      begin
`endif
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
        8'h3F:
        begin
          o_print_help <= 1'b1;
        end  // ? → help
        8'h63, 8'h43:
        begin
          r_param_sel    <= 4'd4;
          o_print_status <= 1'b1;
        end  // c → select cutoff
        8'h71, 8'h51:
        begin
          r_param_sel    <= 4'd5;
          o_print_status <= 1'b1;
        end  // q → select resonance
        8'h76, 8'h56:
        begin
          r_param_sel    <= 4'd6;
          o_print_status <= 1'b1;
        end  // v → select filter-env amount
        8'h62, 8'h42:
        begin
          r_param_sel    <= 4'd7;
          o_print_status <= 1'b1;
        end  // b → select filter-env decay
        8'h6F, 8'h4F:
        begin
          r_param_sel    <= 4'd8;
          o_print_status <= 1'b1;
        end  // o → select drive
        8'h69, 8'h49:
        begin
          r_param_sel    <= 4'd9;
          o_print_status <= 1'b1;
        end  // i → select FM index
        8'h6E, 8'h4E:
        begin
          r_param_sel    <= 4'd10;
          o_print_status <= 1'b1;
        end  // n → select FM ratio
        8'h6C, 8'h4C:
        begin
          r_param_sel    <= 4'd11;
          o_print_status <= 1'b1;
        end  // l → select fold
        8'h2E:
        begin
          r_acc_mode     <= ~r_acc_mode;
          o_print_status <= 1'b1;
        end  // . → toggle accent
        8'h2F:
        begin
          r_sld_mode     <= ~r_sld_mode;
          o_print_status <= 1'b1;
        end  // / → toggle slide
        8'h70:
        begin
          r_play <= ~r_play;
          if (r_play)
          begin
            r_mute <= 1'b1;
            o_gate <= 1'b0;
          end
          o_print_status <= 1'b1;
        end  // p → seq play/stop
        8'h5B:
        begin
          r_bpm          <= (r_bpm > 8'd40) ? (r_bpm - 8'd1) : 8'd40;
          o_print_status <= 1'b1;
        end  // [ → BPM down
        8'h5D:
        begin
          r_bpm          <= (r_bpm < 8'd240) ? (r_bpm + 8'd1) : 8'd240;
          o_print_status <= 1'b1;
        end  // ] → BPM up
        8'h72:
        begin
          r_param_sel    <= (r_param_sel == 4'd11) ? 4'd0
                                                  : (r_param_sel + 4'd1);
          o_print_status <= 1'b1;
        end  // r → next param A D S R C Q E K O I N L
        8'h2D:
        begin
          o_print_status <= 1'b1;
          case (r_param_sel)
            4'd0:
            begin
              r_attack <= (r_attack > `ADSR_STEP + 8'd1)
                        ? (r_attack - `ADSR_STEP) : 8'd1;
            end
            4'd1:
            begin
              r_decay <= (r_decay > `ADSR_STEP + 8'd1)
                       ? (r_decay - `ADSR_STEP) : 8'd1;
            end
            4'd2:
            begin
              r_sustain <= (r_sustain > `ADSR_STEP)
                         ? (r_sustain - `ADSR_STEP) : 8'd0;
            end
            4'd3:
            begin
              r_release <= (r_release > `ADSR_STEP + 8'd1)
                         ? (r_release - `ADSR_STEP) : 8'd1;
            end
            4'd4:
            begin
              r_cutoff <= (r_cutoff > `ADSR_STEP)
                        ? (r_cutoff - `ADSR_STEP) : 8'd0;
            end
            4'd5:
            begin
              r_res <= (r_res > `ADSR_STEP)
                     ? (r_res - `ADSR_STEP) : 8'd0;
            end
            4'd6:
            begin
              r_fenv_amt <= (r_fenv_amt > `ADSR_STEP)
                          ? (r_fenv_amt - `ADSR_STEP) : 8'd0;
            end
            4'd7:
            begin
              r_fdecay <= (r_fdecay > `ADSR_STEP + 8'd1)
                        ? (r_fdecay - `ADSR_STEP) : 8'd1;
            end
            4'd8:
            begin
              r_drive <= (r_drive > `ADSR_STEP)
                       ? (r_drive - `ADSR_STEP) : 8'd0;
            end
            4'd9:
            begin
              r_fm_index <= (r_fm_index > `ADSR_STEP)
                          ? (r_fm_index - `ADSR_STEP) : 8'd0;
            end
            4'd10:
            begin
              r_fm_ratio <= (r_fm_ratio > 8'd1)
                          ? (r_fm_ratio - 8'd1) : 8'd1;
            end
            default:
            begin
              r_fold <= (r_fold > `ADSR_STEP)
                      ? (r_fold - `ADSR_STEP) : 8'd0;
            end
          endcase
        end  // - → param down
        8'h3D, 8'h2B:
        begin
          o_print_status <= 1'b1;
          case (r_param_sel)
            4'd0:
            begin
              r_attack <= (r_attack < 8'd255 - `ADSR_STEP)
                        ? (r_attack + `ADSR_STEP) : 8'd255;
            end
            4'd1:
            begin
              r_decay <= (r_decay < 8'd255 - `ADSR_STEP)
                       ? (r_decay + `ADSR_STEP) : 8'd255;
            end
            4'd2:
            begin
              r_sustain <= (r_sustain < 8'd255 - `ADSR_STEP)
                         ? (r_sustain + `ADSR_STEP) : 8'd255;
            end
            4'd3:
            begin
              r_release <= (r_release < 8'd255 - `ADSR_STEP)
                         ? (r_release + `ADSR_STEP) : 8'd255;
            end
            4'd4:
            begin
              r_cutoff <= (r_cutoff < 8'd255 - `ADSR_STEP)
                        ? (r_cutoff + `ADSR_STEP) : 8'd255;
            end
            4'd5:
            begin
              r_res <= (r_res < 8'd255 - `ADSR_STEP)
                     ? (r_res + `ADSR_STEP) : 8'd255;
            end
            4'd6:
            begin
              r_fenv_amt <= (r_fenv_amt < 8'd255 - `ADSR_STEP)
                          ? (r_fenv_amt + `ADSR_STEP) : 8'd255;
            end
            4'd7:
            begin
              r_fdecay <= (r_fdecay < 8'd255 - `ADSR_STEP)
                        ? (r_fdecay + `ADSR_STEP) : 8'd255;
            end
            4'd8:
            begin
              r_drive <= (r_drive < 8'd255 - `ADSR_STEP)
                       ? (r_drive + `ADSR_STEP) : 8'd255;
            end
            4'd9:
            begin
              r_fm_index <= (r_fm_index < 8'd255 - `ADSR_STEP)
                          ? (r_fm_index + `ADSR_STEP) : 8'd255;
            end
            4'd10:
            begin
              r_fm_ratio <= (r_fm_ratio < 8'd8)
                          ? (r_fm_ratio + 8'd1) : 8'd8;
            end
            default:
            begin
              r_fold <= (r_fold < 8'd255 - `ADSR_STEP)
                      ? (r_fold + `ADSR_STEP) : 8'd255;
            end
          endcase
        end  // = or + → param up
      endcase

      if (w_note_key && !r_play)
      begin
        r_mute <= 1'b0;
        if (r_sld_mode)
        begin
          if ((`NUM_VOICES == 1) || (r_last == 1'b0))
          begin
            r_note0  <= w_key_note;
            r_high0  <= w_key_high;
            r_vgate0 <= 1'b1;
            r_sld0   <= 1'b1;
            r_acc0   <= r_acc_mode;
          end
          else
          begin
            r_note1  <= w_key_note;
            r_high1  <= w_key_high;
            r_vgate1 <= 1'b1;
            r_sld1   <= 1'b1;
            r_acc1   <= r_acc_mode;
          end
          o_note_trig <= 1'b0;
        end
        else
        begin
          if ((`NUM_VOICES == 1) || (r_next == 1'b0))
          begin
            r_note0  <= w_key_note;
            r_high0  <= w_key_high;
            r_vgate0 <= 1'b1;
            r_sld0   <= 1'b0;
            r_acc0   <= r_acc_mode;
            r_last   <= 1'b0;
          end
          else
          begin
            r_note1  <= w_key_note;
            r_high1  <= w_key_high;
            r_vgate1 <= 1'b1;
            r_sld1   <= 1'b0;
            r_acc1   <= r_acc_mode;
            r_last   <= 1'b1;
          end
          if (`NUM_VOICES != 1)
          begin
            r_next <= ~r_next;
          end
          o_note_trig <= 1'b1;
          r_vcf_acc   <= r_acc_mode;
        end
        o_print_status <= 1'b1;
      end
      else if ((i_RX_Byte == 8'h7A) || (i_RX_Byte == 8'h78) ||
               (i_RX_Byte == 8'h20) ||
               (i_RX_Byte == 8'h31) || (i_RX_Byte == 8'h32) ||
               (i_RX_Byte == 8'h33) || (i_RX_Byte == 8'h34) ||
               (i_RX_Byte == 8'h70) || (i_RX_Byte == 8'h5B) ||
               (i_RX_Byte == 8'h5D))
      begin
        o_print_status <= 1'b1;
      end
`ifndef SKIP_SEQ
      end
`endif
    end
  end

  assign o_v0_note = r_note0;
  assign o_v0_high = r_high0;
  assign o_v0_gate = r_vgate0 & ~r_mute;
  assign o_v1_note = r_note1;
  assign o_v1_high = r_high1;
  assign o_v1_gate = r_vgate1 & ~r_mute;

  assign o_attack    = r_attack;
  assign o_decay     = r_decay;
  assign o_sustain   = r_sustain;
  assign o_release   = r_release;
  assign o_param_sel  = r_param_sel;
  assign o_cutoff     = r_cutoff;
  assign o_res        = r_res;
  assign o_fenv_amt   = r_fenv_amt;
  assign o_fdecay     = r_fdecay;
  assign o_drive      = r_drive;
  assign o_fm_index   = r_fm_index;
  assign o_fm_ratio   = r_fm_ratio;
  assign o_fold       = r_fold;
  assign o_accent     = r_acc_mode;
  assign o_slide      = r_sld_mode;
  assign o_v0_accent  = r_acc0;
  assign o_v0_slide   = r_sld0;
  assign o_v1_accent  = r_acc1;
  assign o_v1_slide   = r_sld1;
  assign o_vcf_accent = r_vcf_acc;
  assign o_seq_play   = r_play;
  assign o_bpm        = r_bpm;
  assign o_seq_len    = r_seq_len;

endmodule

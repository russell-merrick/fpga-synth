// UART help + status printer.
// Sends a help banner on boot and when i_print_help pulses.
// Sends a one-line status when i_print_status pulses (dropped if busy).
`include "src/constants.vh"

module uart_menu (
    input        i_CLK,
    input        i_print_help,
    input        i_print_status,

    input  [7:0] i_attack,
    input  [7:0] i_decay,
    input  [7:0] i_sustain,
    input  [7:0] i_release,
    input  [3:0] i_param_sel,
    input  [7:0] i_cutoff,
    input  [7:0] i_res,
    input  [7:0] i_fenv_amt,
    input  [7:0] i_fdecay,
    input  [7:0] i_drive,
    input  [7:0] i_fm_index,
    input  [7:0] i_fm_ratio,
    input  [7:0] i_fold,
    input        i_accent,
    input        i_slide,
    input  [1:0] i_wave,
    input  [2:0] i_octave,
    input        i_gate,
    input  [3:0] i_v0_note,
    input        i_v0_high,
    input        i_v0_gate,
    input  [3:0] i_v1_note,
    input        i_v1_high,
    input        i_v1_gate,

    output reg       o_TX_DV,
    output reg [7:0] o_TX_Byte,
    input            i_TX_Active,

    output           o_busy
);

  localparam HELP_LEN   = 8'd212;
  localparam STATUS_LEN = 8'd101;
  localparam [8*HELP_LEN-1:0] HELP_STR = {
    8'h0D, 8'h0A,
    "synth 115200", 8'h0D, 8'h0A,
    "notes a w s d f g h j k", 8'h0D, 8'h0A,
    "z/x oct 1-4 wave spc mute", 8'h0D, 8'h0A,
    ". accent   / slide", 8'h0D, 8'h0A,
    "i FM idx  n ratio  l fold", 8'h0D, 8'h0A,
    "o drive then - down  = up", 8'h0D, 8'h0A,
    "c cut  q res  v env  b fdec", 8'h0D, 8'h0A,
    "r cycles A..O I N L", 8'h0D, 8'h0A,
    "* selected  ?=help", 8'h0D, 8'h0A
  };
  localparam BOOT_WAIT  = 24'd2_000_000;  // ~80 ms at 25 MHz

  localparam IDLE     = 2'd0;
  localparam PULSE    = 2'd1;
  localparam WAIT_ACT = 2'd2;
  localparam WAIT_CLR = 2'd3;

  reg [1:0]  r_state     = IDLE;
  reg        r_is_help   = 1'b1;
  reg [7:0]  r_idx       = 8'd0;
  reg [7:0]  r_len       = 8'd0;
  reg        r_booted    = 1'b0;
  reg [23:0] r_boot_cnt  = 24'd0;
  reg        r_pend_help = 1'b0;
  reg        r_pend_stat = 1'b0;

  // Snapshot of status fields, captured when a status print starts.
  reg [7:0] r_a, r_d, r_s, r_r, r_c, r_q, r_e, r_k, r_o, r_i, r_n, r_l;
  reg [3:0] r_sel;
  reg       r_acc, r_sld;
  reg [1:0] r_wave;
  reg [2:0] r_oct;
  reg       r_g0, r_h0, r_g1, r_h1;
  reg [3:0] r_n0, r_n1;

  function [7:0] dec_digit;
    input [7:0] val;
    input [1:0] which;  // 0=hundreds, 1=tens, 2=ones
    begin
      if (which == 2'd0)
        dec_digit = 8'h30 + (val / 8'd100);
      else if (which == 2'd1)
        dec_digit = 8'h30 + ((val % 8'd100) / 8'd10);
      else
        dec_digit = 8'h30 + (val % 8'd10);
    end
  endfunction

  function [7:0] note_ch0;
    input [3:0] n;
    begin
      case (n)
        4'd0, 4'd1:  note_ch0 = "C";
        4'd2, 4'd3:  note_ch0 = "D";
        4'd4:        note_ch0 = "E";
        4'd5, 4'd6:  note_ch0 = "F";
        4'd7, 4'd8:  note_ch0 = "G";
        4'd9, 4'd10: note_ch0 = "A";
        default:     note_ch0 = "B";
      endcase
    end
  endfunction

  function [7:0] note_ch1;
    input [3:0] n;
    input       gated;
    input       high;
    begin
      if (!gated)
        note_ch1 = "-";
      else if (high)
        note_ch1 = "+";
      else if ((n == 4'd1) || (n == 4'd3) || (n == 4'd6) ||
               (n == 4'd8) || (n == 4'd10))
        note_ch1 = "#";
      else
        note_ch1 = " ";
    end
  endfunction

  function [7:0] help_at;
    input [7:0] i;
    begin
      help_at = HELP_STR[8 * (HELP_LEN - 1 - i) +: 8];
    end
  endfunction

  // Fixed-width status:
  // A=080 D=020 S=200 R=020 C=040 Q=210 E=255 K=064 O=096 *A w=saw o=4 0=A  1=-- !/\r\n
  function [7:0] status_at;
    input [7:0] i;
    begin
      case (i)
        8'd0:  status_at = 8'h0D;
        8'd1:  status_at = 8'h0A;
        8'd2:  status_at = "A";
        8'd3:  status_at = "=";
        8'd4:  status_at = dec_digit(r_a, 2'd0);
        8'd5:  status_at = dec_digit(r_a, 2'd1);
        8'd6:  status_at = dec_digit(r_a, 2'd2);
        8'd7:  status_at = " ";
        8'd8:  status_at = "D";
        8'd9:  status_at = "=";
        8'd10: status_at = dec_digit(r_d, 2'd0);
        8'd11: status_at = dec_digit(r_d, 2'd1);
        8'd12: status_at = dec_digit(r_d, 2'd2);
        8'd13: status_at = " ";
        8'd14: status_at = "S";
        8'd15: status_at = "=";
        8'd16: status_at = dec_digit(r_s, 2'd0);
        8'd17: status_at = dec_digit(r_s, 2'd1);
        8'd18: status_at = dec_digit(r_s, 2'd2);
        8'd19: status_at = " ";
        8'd20: status_at = "R";
        8'd21: status_at = "=";
        8'd22: status_at = dec_digit(r_r, 2'd0);
        8'd23: status_at = dec_digit(r_r, 2'd1);
        8'd24: status_at = dec_digit(r_r, 2'd2);
        8'd25: status_at = " ";
        8'd26: status_at = "C";
        8'd27: status_at = "=";
        8'd28: status_at = dec_digit(r_c, 2'd0);
        8'd29: status_at = dec_digit(r_c, 2'd1);
        8'd30: status_at = dec_digit(r_c, 2'd2);
        8'd31: status_at = " ";
        8'd32: status_at = "Q";
        8'd33: status_at = "=";
        8'd34: status_at = dec_digit(r_q, 2'd0);
        8'd35: status_at = dec_digit(r_q, 2'd1);
        8'd36: status_at = dec_digit(r_q, 2'd2);
        8'd37: status_at = " ";
        8'd38: status_at = "E";
        8'd39: status_at = "=";
        8'd40: status_at = dec_digit(r_e, 2'd0);
        8'd41: status_at = dec_digit(r_e, 2'd1);
        8'd42: status_at = dec_digit(r_e, 2'd2);
        8'd43: status_at = " ";
        8'd44: status_at = "K";
        8'd45: status_at = "=";
        8'd46: status_at = dec_digit(r_k, 2'd0);
        8'd47: status_at = dec_digit(r_k, 2'd1);
        8'd48: status_at = dec_digit(r_k, 2'd2);
        8'd49: status_at = " ";
        8'd50: status_at = "O";
        8'd51: status_at = "=";
        8'd52: status_at = dec_digit(r_o, 2'd0);
        8'd53: status_at = dec_digit(r_o, 2'd1);
        8'd54: status_at = dec_digit(r_o, 2'd2);
        8'd55: status_at = " ";
        8'd56: status_at = "I";
        8'd57: status_at = "=";
        8'd58: status_at = dec_digit(r_i, 2'd0);
        8'd59: status_at = dec_digit(r_i, 2'd1);
        8'd60: status_at = dec_digit(r_i, 2'd2);
        8'd61: status_at = " ";
        8'd62: status_at = "N";
        8'd63: status_at = "=";
        8'd64: status_at = dec_digit(r_n, 2'd0);
        8'd65: status_at = dec_digit(r_n, 2'd1);
        8'd66: status_at = dec_digit(r_n, 2'd2);
        8'd67: status_at = " ";
        8'd68: status_at = "L";
        8'd69: status_at = "=";
        8'd70: status_at = dec_digit(r_l, 2'd0);
        8'd71: status_at = dec_digit(r_l, 2'd1);
        8'd72: status_at = dec_digit(r_l, 2'd2);
        8'd73: status_at = " ";
        8'd74: status_at = "*";
        8'd75: status_at = (r_sel == 4'd0)  ? "A" :
                           (r_sel == 4'd1)  ? "D" :
                           (r_sel == 4'd2)  ? "S" :
                           (r_sel == 4'd3)  ? "R" :
                           (r_sel == 4'd4)  ? "C" :
                           (r_sel == 4'd5)  ? "Q" :
                           (r_sel == 4'd6)  ? "E" :
                           (r_sel == 4'd7)  ? "K" :
                           (r_sel == 4'd8)  ? "O" :
                           (r_sel == 4'd9)  ? "I" :
                           (r_sel == 4'd10) ? "N" : "L";
        8'd76: status_at = " ";
        8'd77: status_at = "w";
        8'd78: status_at = "=";
        8'd79: status_at = (r_wave == 2'd0) ? "s" :
                           (r_wave == 2'd1) ? "t" :
                           (r_wave == 2'd2) ? "s" : "q";
        8'd80: status_at = (r_wave == 2'd0) ? "i" :
                           (r_wave == 2'd1) ? "r" :
                           (r_wave == 2'd2) ? "a" : "s";
        8'd81: status_at = (r_wave == 2'd0) ? "n" :
                           (r_wave == 2'd1) ? "i" :
                           (r_wave == 2'd2) ? "w" : "q";
        8'd82: status_at = " ";
        8'd83: status_at = "o";
        8'd84: status_at = "=";
        8'd85: status_at = 8'h30 + {5'd0, r_oct};
        8'd86: status_at = " ";
        8'd87: status_at = "0";
        8'd88: status_at = "=";
        8'd89: status_at = r_g0 ? note_ch0(r_n0) : "-";
        8'd90: status_at = r_g0 ? note_ch1(r_n0, r_g0, r_h0) : "-";
        8'd91: status_at = " ";
        8'd92: status_at = "1";
        8'd93: status_at = "=";
        8'd94: status_at = r_g1 ? note_ch0(r_n1) : "-";
        8'd95: status_at = r_g1 ? note_ch1(r_n1, r_g1, r_h1) : "-";
        8'd96: status_at = " ";
        8'd97: status_at = r_acc ? "!" : "-";
        8'd98: status_at = r_sld ? "/" : "-";
        8'd99: status_at = 8'h0D;
        8'd100: status_at = 8'h0A;
        default: status_at = 8'h00;
      endcase
    end
  endfunction

  assign o_busy = (r_state != IDLE);

  always @(posedge i_CLK)
  begin
    o_TX_DV <= 1'b0;

    if (i_print_help)
    begin
      r_pend_help <= 1'b1;
    end
    if (i_print_status)
    begin
      r_pend_stat <= 1'b1;
    end

    if (!r_booted)
    begin
      r_boot_cnt <= r_boot_cnt + 24'd1;
      if (r_boot_cnt == BOOT_WAIT)
      begin
        r_booted    <= 1'b1;
        r_pend_help <= 1'b1;
      end
    end

    case (r_state)
      IDLE:
      begin
        if (r_pend_help)
        begin
          r_pend_help <= 1'b0;
          r_is_help   <= 1'b1;
          r_idx       <= 8'd0;
          r_len       <= HELP_LEN;
          r_state     <= PULSE;
        end
        else if (r_pend_stat)
        begin
          r_pend_stat <= 1'b0;
          r_is_help   <= 1'b0;
          r_idx       <= 8'd0;
          r_len       <= STATUS_LEN;
          r_a         <= i_attack;
          r_d         <= i_decay;
          r_s         <= i_sustain;
          r_r         <= i_release;
          r_sel       <= i_param_sel;
          r_c         <= i_cutoff;
          r_q         <= i_res;
          r_e         <= i_fenv_amt;
          r_k         <= i_fdecay;
          r_o         <= i_drive;
          r_i         <= i_fm_index;
          r_n         <= i_fm_ratio;
          r_l         <= i_fold;
          r_acc       <= i_accent;
          r_sld       <= i_slide;
          r_wave      <= i_wave;
          r_oct       <= i_octave;
          r_n0        <= i_v0_note;
          r_h0        <= i_v0_high;
          r_g0        <= i_v0_gate;
          r_n1        <= i_v1_note;
          r_h1        <= i_v1_high;
          r_g1        <= i_v1_gate;
          r_state     <= PULSE;
        end
      end
      PULSE:
      begin
        if (!i_TX_Active)
        begin
          o_TX_DV   <= 1'b1;
          o_TX_Byte <= r_is_help ? help_at(r_idx) : status_at(r_idx);
          r_state   <= WAIT_ACT;
        end
      end
      WAIT_ACT:
      begin
        if (i_TX_Active)
        begin
          r_state <= WAIT_CLR;
        end
      end
      WAIT_CLR:
      begin
        if (!i_TX_Active)
        begin
          if ((r_idx + 8'd1) >= r_len)
          begin
            r_state <= IDLE;
          end
          else
          begin
            r_idx   <= r_idx + 8'd1;
            r_state <= PULSE;
          end
        end
      end
      default:
      begin
        r_state <= IDLE;
      end
    endcase
  end

endmodule

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
    input  [1:0] i_adsr_sel,
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

  localparam HELP_LEN   = 8'd95;
  localparam STATUS_LEN = 8'd50;
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
  reg [7:0] r_a, r_d, r_s, r_r;
  reg [1:0] r_sel, r_wave;
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
      case (i)
        8'd0:  help_at = 8'h0D;
        8'd1:  help_at = 8'h0A;
        8'd2:  help_at = "s";
        8'd3:  help_at = "y";
        8'd4:  help_at = "n";
        8'd5:  help_at = "t";
        8'd6:  help_at = "h";
        8'd7:  help_at = " ";
        8'd8:  help_at = "1";
        8'd9:  help_at = "1";
        8'd10: help_at = "5";
        8'd11: help_at = "2";
        8'd12: help_at = "0";
        8'd13: help_at = "0";
        8'd14: help_at = 8'h0D;
        8'd15: help_at = 8'h0A;
        8'd16: help_at = "n";
        8'd17: help_at = "o";
        8'd18: help_at = "t";
        8'd19: help_at = "e";
        8'd20: help_at = "s";
        8'd21: help_at = " ";
        8'd22: help_at = "a";
        8'd23: help_at = " ";
        8'd24: help_at = "w";
        8'd25: help_at = " ";
        8'd26: help_at = "s";
        8'd27: help_at = " ";
        8'd28: help_at = "d";
        8'd29: help_at = " ";
        8'd30: help_at = "f";
        8'd31: help_at = " ";
        8'd32: help_at = "g";
        8'd33: help_at = " ";
        8'd34: help_at = "h";
        8'd35: help_at = " ";
        8'd36: help_at = "j";
        8'd37: help_at = " ";
        8'd38: help_at = "k";
        8'd39: help_at = 8'h0D;
        8'd40: help_at = 8'h0A;
        8'd41: help_at = "z";
        8'd42: help_at = "/";
        8'd43: help_at = "x";
        8'd44: help_at = " ";
        8'd45: help_at = "o";
        8'd46: help_at = "c";
        8'd47: help_at = "t";
        8'd48: help_at = " ";
        8'd49: help_at = "1";
        8'd50: help_at = "-";
        8'd51: help_at = "4";
        8'd52: help_at = " ";
        8'd53: help_at = "w";
        8'd54: help_at = "a";
        8'd55: help_at = "v";
        8'd56: help_at = "e";
        8'd57: help_at = " ";
        8'd58: help_at = "s";
        8'd59: help_at = "p";
        8'd60: help_at = "c";
        8'd61: help_at = " ";
        8'd62: help_at = "m";
        8'd63: help_at = "u";
        8'd64: help_at = "t";
        8'd65: help_at = "e";
        8'd66: help_at = 8'h0D;
        8'd67: help_at = 8'h0A;
        8'd68: help_at = "r";
        8'd69: help_at = "=";
        8'd70: help_at = "A";
        8'd71: help_at = "D";
        8'd72: help_at = "S";
        8'd73: help_at = "R";
        8'd74: help_at = " ";
        8'd75: help_at = "s";
        8'd76: help_at = "e";
        8'd77: help_at = "l";
        8'd78: help_at = " ";
        8'd79: help_at = "-";
        8'd80: help_at = "/";
        8'd81: help_at = "=";
        8'd82: help_at = " ";
        8'd83: help_at = "v";
        8'd84: help_at = "a";
        8'd85: help_at = "l";
        8'd86: help_at = " ";
        8'd87: help_at = "?";
        8'd88: help_at = "=";
        8'd89: help_at = "h";
        8'd90: help_at = "e";
        8'd91: help_at = "l";
        8'd92: help_at = "p";
        8'd93: help_at = 8'h0D;
        8'd94: help_at = 8'h0A;
        default: help_at = 8'h00;
      endcase
    end
  endfunction

  // Fixed-width status:
  // A=080 D=020 S=200 R=020 *A wav=sin oct=4 V0=A4 V1=--\r\n
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
        8'd26: status_at = "*";
        8'd27: status_at = (r_sel == 2'd0) ? "A" :
                           (r_sel == 2'd1) ? "D" :
                           (r_sel == 2'd2) ? "S" : "R";
        8'd28: status_at = " ";
        8'd29: status_at = "w";
        8'd30: status_at = "=";
        8'd31: status_at = (r_wave == 2'd0) ? "s" :
                           (r_wave == 2'd1) ? "t" :
                           (r_wave == 2'd2) ? "s" : "q";
        8'd32: status_at = (r_wave == 2'd0) ? "i" :
                           (r_wave == 2'd1) ? "r" :
                           (r_wave == 2'd2) ? "a" : "s";
        8'd33: status_at = (r_wave == 2'd0) ? "n" :
                           (r_wave == 2'd1) ? "i" :
                           (r_wave == 2'd2) ? "w" : "q";
        8'd34: status_at = " ";
        8'd35: status_at = "o";
        8'd36: status_at = "=";
        8'd37: status_at = 8'h30 + {5'd0, r_oct};
        8'd38: status_at = " ";
        8'd39: status_at = "0";
        8'd40: status_at = "=";
        8'd41: status_at = r_g0 ? note_ch0(r_n0) : "-";
        8'd42: status_at = r_g0 ? note_ch1(r_n0, r_g0, r_h0) : "-";
        8'd43: status_at = " ";
        8'd44: status_at = "1";
        8'd45: status_at = "=";
        8'd46: status_at = r_g1 ? note_ch0(r_n1) : "-";
        8'd47: status_at = r_g1 ? note_ch1(r_n1, r_g1, r_h1) : "-";
        8'd48: status_at = 8'h0D;
        8'd49: status_at = 8'h0A;
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
          r_sel       <= i_adsr_sel;
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

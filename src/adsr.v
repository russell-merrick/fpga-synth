// ADSR envelope generator.
// Outputs a 16-bit unsigned envelope level (0–32767) driven by i_DV (48.828 kHz).
// Attack/decay/release parameters are rates (increments per tick); higher = faster.
// Sustain parameter is a level: 0–255 maps to 0–32640 (value × 128).
`include "src/constants.vh"

module adsr (
    input        i_CLK,
    input        i_DV,       // 48.828 kHz sample tick
    input        i_gate,     // 1 = note on, 0 = note off
    input  [7:0] i_attack,
    input  [7:0] i_decay,
    input  [7:0] i_sustain,
    input  [7:0] i_release,
    output [15:0] o_env
);

  localparam IDLE    = 3'd0;
  localparam ATTACK  = 3'd1;
  localparam DECAY   = 3'd2;
  localparam SUSTAIN = 3'd3;
  localparam RELEASE = 3'd4;

  wire [15:0] w_sustain_level = {1'b0, i_sustain, 7'b0};  // i_sustain * 128

  reg [2:0]  r_state  = IDLE;
  reg [15:0] r_env    = 16'd0;
  reg        r_gate_d = 1'b0;

  wire w_gate_rise = i_gate  & ~r_gate_d;
  wire w_gate_fall = ~i_gate &  r_gate_d;

  always @(posedge i_CLK)
  begin
    r_gate_d <= i_gate;

    if (w_gate_rise)
    begin
      r_state <= ATTACK;
    end
    else if (w_gate_fall)
    begin
      r_state <= RELEASE;
    end
    else if (i_DV)
    begin
      case (r_state)
        ATTACK:
        begin
          if (r_env >= 16'd32767 - {8'b0, i_attack})
          begin
            r_env   <= 16'd32767;
            r_state <= DECAY;
          end
          else
          begin
            r_env <= r_env + {8'b0, i_attack};
          end
        end
        DECAY:
        begin
          if (r_env <= w_sustain_level + {8'b0, i_decay})
          begin
            r_env   <= w_sustain_level;
            r_state <= SUSTAIN;
          end
          else
          begin
            r_env <= r_env - {8'b0, i_decay};
          end
        end
        SUSTAIN:
        begin
          r_env <= w_sustain_level;
        end
        RELEASE:
        begin
          if (r_env <= {8'b0, i_release})
          begin
            r_env   <= 16'd0;
            r_state <= IDLE;
          end
          else
          begin
            r_env <= r_env - {8'b0, i_release};
          end
        end
        default:
        begin
          r_env <= 16'd0;
        end
      endcase
    end
  end

  assign o_env = r_env;

endmodule

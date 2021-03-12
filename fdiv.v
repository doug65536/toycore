`default_nettype none
`timescale 1ns/1ns

module fdiv(
	input wire clk,
  input wire dispatch,
	input wire [DATAW-1:0] a,
	input wire [DATAW-1:0] b,
	input wire [1:0] op,
  output reg done,
	output reg [DATAW-1:0] q
);

parameter DATAW = 32;
parameter EXPW = 8;
parameter MANW = 23;
parameter HASHIDDEN = 1;

localparam [EXPW-1:0] BIAS = (1 << (EXPW-1))-1;

wire a_sign, a_zeroexp, a_hidden, a_infexp, a_nan;
wire b_sign, b_zeroexp, b_hidden, b_infexp, b_nan;

wire a_zeroman, a_maxman, a_infinity, a_zero;
wire b_zeroman, b_maxman, b_infinity, b_zero;

wire [EXPW-1:0] a_exponent;
wire [EXPW-1:0] b_exponent;

wire [MANW-0:0] a_fullman;
wire [MANW-0:0] b_fullman;

fdecode falu_a_dec(
	.a(a),
	.sign(a_sign), 
	.zeroexp(a_zeroexp), 
	.hidden(a_hidden), 
	.infexp(a_infexp),
	.zeroman(a_zeroman), 
	.maxman(a_maxman), 
	.infinity(a_infinity), 
  .nan(a_nan),
	.zero(a_zero),
	.exponent(a_exponent),
	.fullman(a_fullman)
);

fdecode falu_b_dec(
	.a(b),
	.sign(b_sign), 
	.zeroexp(b_zeroexp), 
	.hidden(b_hidden), 
	.infexp(b_infexp),
	.zeroman(b_zeroman), 
	.maxman(b_maxman), 
	.infinity(b_infinity), 
  .nan(b_nan),
	.zero(b_zero),
	.exponent(b_exponent),
	.fullman(b_fullman)
);

// -nan
localparam [DATAW-1:0] NAN = {
  1'b1,
  {EXPW{1'b1}},
  {1'b1, {(MANW-1){1'b0}}}
};

// -0.0f
localparam [DATAW-1:0] NEG_ZERO = {
  1'b1,
  {EXPW{1'b0}},
  {MANW{1'b0}}
};

// +0.0f
localparam [DATAW-1:0] POS_ZERO = {
  1'b0,
  {EXPW{1'b0}},
  {MANW{1'b0}}
};

// -inf
localparam [DATAW-1:0] POS_INF = {
  1'b0,
  {EXPW{1'b1}},
  {MANW{1'b0}}
};

// +inf
localparam [DATAW-1:0] NEG_INF = {
  1'b1,
  {EXPW{1'b1}},
  {MANW{1'b0}}
};

reg [MANW-0:0] quotient;
reg [EXPW+1:0] result_exp;

reg [7:0] div_cycles_remaining = 'b0;
reg div_s;
reg [MANW*2-0:0] div_n;
reg [MANW*2-0:0] div_d;
reg [MANW*2-0:0] div_q;
reg [MANW*2-0:0] div_r;

reg [MANW*2-0:0] div_next_n;
reg [MANW*2-0:0] div_next_q;
reg [MANW*2-0:0] div_next_r;

reg div_result_bit;
reg [MANW*2+1:0] div_next_r_minus_d;

// Two extra bits, [MANW] detects overflow, [MANW+1] detects underflow
reg [EXPW+1:0] div_e;

reg early_sign;

// Quick guess at result exponent before actual divide
reg [EXPW+1:0] early_exponent;

always @*
begin
  early_sign = a_sign ^ b_sign;
  early_exponent = a_exponent - b_exponent + BIAS;
end

// Perform one iteration of divide algorithm
always @*
begin
  // Rotate high bit of n into low bit of r
  div_next_r = {div_r[DATAW-2:0], div_n[MANW*2]};
  div_next_n = div_n << 1;

  div_next_r_minus_d = {1'b0, div_next_r} - div_d;

  // Result bit is 1 if the calculation above borrowed (wrapped)
  div_result_bit = ~div_next_r_minus_d[MANW*2+1];

  if (div_result_bit) begin
    // Adjust remainder
    div_next_r = div_next_r_minus_d;
  end
  
  // Shift bit into result
  div_next_q = {div_q[DATAW-2:0], div_result_bit};
end

always @(posedge clk)
begin
  done <= 1'b0;

  if (div_cycles_remaining == 1) begin
    if (div_e[EXPW+1]) begin
      // Underflowed to zero
      q <= div_s
        ? NEG_ZERO
        : POS_ZERO;
      done <= 1'b1;
    end else if (div_e[EXPW]) begin
      // Overflowed to infinity
      q <= div_s
        ? NEG_INF
        : POS_INF;
      done <= 1'b1;
    end else if (~div_q[MANW]) begin
      // Hidden bit of div_q is not set, the mantissa 
      // needs to be shifted left by one, and the exponent 
      // needs to be decreased by one, if not already zero
      if (div_e == 0) begin
        // Underflow to zero
        q <= {
          div_s,
          {EXPW{1'b0}},
          div_q[MANW-1:0]
        };
        done <= 1'b1;
      end else begin
        q <= {
          div_s,
          div_e - 1,
          {div_q[MANW-2:1], 1'b0}
        };
        done <= 1'b1;
      end
    end else begin
      // Mantissa is fine
      q <= {
        div_s,
        div_e[EXPW-1:0],
        div_q[MANW-1:0]
      };
      done <= 1'b1;
    end

    div_cycles_remaining <= 0;
  end else if (div_cycles_remaining != 0) begin
    // Step to next iteration
    div_n <= div_next_n;
    div_q <= div_next_q;
    div_r <= div_next_r;
    
    div_cycles_remaining <= div_cycles_remaining - 1'b1;
  end else if (dispatch) begin
    // Handle all the trivial cases real quick
    if (a_nan) begin
      q <= a;
      done <= 1'b1;
    end else if (b_nan) begin
      q <= b;
      done <= 1'b1;
    end else if (b_zero & a_zero) begin
      // zero / zero = -nan
      q = NAN;
      done <= 1'b1;
    end else if (b_zero) begin
      // nonzero / zero = +/- infinity
      q <= early_sign
        ? NEG_INF 
        : POS_INF;
      done <= 1'b1;
    end else if (early_exponent[EXPW+1]) begin
      // Exponent will underflow
      q <= early_sign
        ? NEG_ZERO
        : POS_ZERO;
      done <= 1'b1;
    end else if (early_exponent[EXPW] ||
        &early_exponent[EXPW-1:0]) begin
      // Exponent will overflow
      q <= early_sign
        ? NEG_INF
        : POS_INF;
      done <= 1'b1;
    end else begin
      // Gauntlet complete. Actually start a divide!
      div_n <= {a_fullman, {MANW{1'b0}}};
      div_d <= b_fullman;
      div_q <= 0;
      div_r <= 0;
      div_cycles_remaining <= MANW * 2 + 2;

      div_e <= early_exponent;
      div_s <= early_sign;
    end
  end
end

endmodule

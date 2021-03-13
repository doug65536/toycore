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
wire [5:0] div_cycles_remaining_decremented = 
  div_cycles_remaining - 1'b1;

reg div_sign;
reg [MANW*2-0:0] div_numer;
reg [MANW-0:0] div_denom;
reg [MANW-0:0] div_quotient;
reg [MANW*2-0:0] div_remainder;

reg [MANW*2-0:0] div_next_n;
reg [MANW*2-0:0] div_next_q;
reg [MANW*2-0:0] div_next_r;

reg div_result_bit;
reg [MANW*2+1:0] div_next_r_minus_d;

// Two extra bits, [MANW] detects overflow, [MANW+1] detects underflow
reg [EXPW+1:0] div_exponent;
wire [EXPW-1:0] decremented_exponent = div_exponent - 1'b1;

wire div_round_up =
  div_remainder >= div_denom[MANW-2:1];

wire [MANW+1:0] rounded_quotient = div_quotient + div_round_up;
wire [EXPW-1:0] rounded_exponent = div_exponent + rounded_quotient[MANW+1];
wire rounded_infinity = &rounded_exponent;

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
  // Rotate high bit of numerator into low bit of remainder
  div_next_r = {div_remainder[MANW*2-1:0], div_numer[MANW*2]};
  div_next_n = div_numer << 1;

  div_next_r_minus_d = {1'b0, div_next_r} - div_denom;

  // Result bit is 1 if div_next_r >= div_denom
  div_result_bit = ~div_next_r_minus_d[MANW*2+1];

  if (div_result_bit) begin
    // Adjust remainder
    div_next_r = div_next_r_minus_d;
  end
  
  // Shift bit into result
  div_next_q = {div_quotient[MANW-1:0], div_result_bit};
end

always @(posedge clk)
begin
  done <= 1'b0;

  if (div_cycles_remaining == 1) begin
    // Perform final normalization
    if (~div_quotient[MANW] && div_exponent != 0) begin
      // Hidden bit of div_quotient is not set, the mantissa 
      // needs to be shifted left by one, and the exponent 
      // needs to be decreased by one, if not already zero
      // Shift in one bit to normalize
      q <= {
        div_sign,
        decremented_exponent,
        div_quotient[MANW-2:0], 
        div_round_up
      };

      done <= 1'b1;
    end else if (~rounded_infinity) begin
      // Mantissa is fine
      q <= {
        div_sign,
        rounded_exponent[EXPW-1:0],
        rounded_quotient[MANW-1:0]
      };

      done <= 1'b1;
    end else begin
      q <= div_sign
        ? NEG_INF
        : POS_INF;

      done <= 1'b1;
    end

    div_cycles_remaining <= div_cycles_remaining_decremented;
  end else if (div_cycles_remaining != 0) begin
    // Step to next iteration
    div_numer <= div_next_n;
    div_quotient <= div_next_q;
    div_remainder <= div_next_r;
    
    div_cycles_remaining <= div_cycles_remaining_decremented;
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
    end else if (b_zeroman) begin
      // Super easy divide by power of two
      q <= {
        early_sign,
        early_exponent[EXPW-1:0],
        a_fullman[MANW-1:0]
      };

      done <= 1'b1;
    end else begin
      // Gauntlet complete. Actually start a divide!
      div_numer <= {a_fullman, {MANW{1'b0}}};
      div_denom <= b_fullman;
      div_quotient <= 0;
      div_remainder <= 0;
      div_exponent <= early_exponent;
      div_sign <= early_sign;

      div_cycles_remaining <= MANW * 2 + 2;
    end
  end
end

endmodule

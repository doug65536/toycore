module fdiv(
	input wire clk,
	input wire [DATAW-1:0] a,
	input wire [DATAW-1:0] b,
	input wire [1:0] op,
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
reg [DATAW-1:0] result;
reg [EXPW+1:0] result_exp;
reg result_sign;

always @*
begin
  result_sign = a_sign ^ b_sign;

  if (a_nan) begin
    result <= a;
  end else if (b_nan) begin
    result <= b;
  end else if (b_zero & a_zero) begin
    // zero / zero = -nan
    result = NAN;
  end else if (b_zero) begin
    // nonzero / zero = +/- infinity
    result = (result_sign)
      ? NEG_INF 
      : POS_INF;
  end else begin
    quotient = ({a_fullman, {MANW{1'b0}}} / 
      b_fullman);

    if (|quotient) begin
      result_exp = a_exponent - b_exponent + BIAS;
      
      // Normalize the mantissa
      for (i = 0; i < MANW; i = i + 1) begin
        if (~quotient[MANW]) begin
          quotient = quotient << 1;
          result_exp = result_exp - 'b1;
        end
      end

      if (result_exp[EXPW]) begin
        // It carried, infinite result
        result = result_sign
          ? POS_INF
          : NEG_INF;
      end else if (result_exp[EXPW+1]) begin
        // It borrowed, zero result
        result = result_sign
          ? POS_ZERO
          : NEG_ZERO;
      end else begin
        result = {
          result_sign,
          result_exp[EXPW-1:0],
          quotient[MANW-1:0]
        };
      end
    end else begin
      // quotient is zero!
      result_exp = 0;
      result = 0;
    end
  end
end

localparam PIPELINE_LEN = 4;
reg [DATAW-1:0] pipeline_div[0:PIPELINE_LEN];

integer i;
always @(posedge clk)
begin
  pipeline_div[0] <= result;
  for (i = 0; i < PIPELINE_LEN; i = i + 1) begin
    pipeline_div[i+1] <= pipeline_div[i];
  end
  q <= pipeline_div[PIPELINE_LEN];
end

endmodule

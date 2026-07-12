module REG_MUX #(
    parameter WIDTH = 18,
    parameter RSTTYPE = "SYNC",  // or "ASYNC"
    parameter NO_PIPELINES = 0
) (
    input CLK,
    input RST,
    input CE,
    input [WIDTH-1:0] D,
    output [WIDTH-1:0] Q
);

  reg [WIDTH-1:0] Q_reg;

  generate
    if (RSTTYPE == "ASYNC") begin

      always @(posedge CLK or posedge RST) begin
        if (RST) Q_reg <= 0;
        else if (CE) Q_reg <= D;
      end

    end else begin

      always @(posedge CLK) begin
        if (RST) Q_reg <= 0;
        else if (CE) Q_reg <= D;
      end

    end
  endgenerate

  assign Q = (NO_PIPELINES) ? Q_reg : D;
endmodule

module MUX_2_1 #(
    parameter WIDTH = 18
) (
    input [WIDTH-1:0] in0,
    input [WIDTH-1:0] in1,
    input SEL,
    output reg [WIDTH-1:0] out
);
  always @(*) begin
    if (SEL) begin
      out = in1;
    end else begin
      out = in0;
    end
  end
endmodule

module MUX_4_1 #(
    parameter WIDTH = 18
) (
    input [WIDTH-1:0] in0,
    input [WIDTH-1:0] in1,
    input [WIDTH-1:0] in2,
    input [WIDTH-1:0] in3,
    input [1:0] SEL,
    output reg [WIDTH-1:0] out
);
  always @(*) begin
    case (SEL)
      2'b00:   out = in0;
      2'b01:   out = in1;
      2'b10:   out = in2;
      2'b11:   out = in3;
      default: out = 0;
    endcase
  end
endmodule

module Adder_Subtracter_WithOUT_CI_CO #(
    parameter WIDTH = 18
) (
    input [WIDTH-1:0] A,
    input [WIDTH-1:0] B,
    input SEL,
    output reg [WIDTH-1:0] SUM
);
  always @(*) begin
    if (SEL) begin
      SUM = A - B;  // Subtraction
    end else begin
      SUM = A + B;  // Addition
    end
  end
endmodule

module Adder_Subtracter_With_CI_CO #(
    parameter WIDTH = 48
) (
    input [WIDTH-1:0] A,
    input [WIDTH-1:0] B,
    input CARRYIN,
    input SEL,
    output reg [WIDTH-1:0] SUM,
    output reg CARRYOUT
);
  always @(*) begin
    if (SEL) begin
      {CARRYOUT, SUM} = A - (B + CARRYIN);  // Subtraction
    end else begin
      {CARRYOUT, SUM} = A + B + CARRYIN;  // Addition
    end
  end
endmodule

module Multiplier #(
    parameter WIDTH = 18
) (
    input [WIDTH-1:0] A,
    input [WIDTH-1:0] B,
    output reg [2*WIDTH-1:0] P
);
  always @(*) begin
    P = A * B;  // Multiplication
  end
endmodule

module DSP48A1 #(
    parameter A0REG = 0,
    parameter A1REG = 1,

    parameter B0REG = 0,
    parameter B1REG = 1,

    parameter CREG = 1,
    parameter DREG = 1,
    parameter MREG = 1,
    parameter PREG = 1,

    parameter CARRYINREG  = 1,
    parameter CARRYOUTREG = 1,
    parameter OPMODEREG   = 1,

    parameter CARRYINSEL = "OPMODE5",  // or "OPMODE5"
    parameter B_INPUT = "DIRECT",  // or "BCIN"
    parameter RSTTYPE = "SYNC"  // or "ASYNC"
) (
    input [17:0] A,
    input [17:0] B,
    input [47:0] C,
    input [17:0] D,

    input CARRYIN,
    input CLK,

    input [ 7:0] OPMODE,
    input [17:0] BCIN,

    input RSTA,
    input RSTB,
    input RSTC,
    input RSTCARRYIN,
    input RSTD,
    input RSTM,
    input RSTOPMODE,
    input RSTP,

    input CEA,
    input CEB,
    input CEC,
    input CECARRYIN,
    input CED,
    input CEM,
    input CEOPMODE,
    input CEP,

    input [47:0] PCIN,

    output [47:0] P,
    output [47:0] PCOUT,
    output [17:0] BCOUT,
    output [35:0] M,

    output CARRYOUT,
    output CARRYOUTF
);

  //===================================================
  // Internal parameters for selecting inputs
  //===================================================

  localparam CARRYINSEL_SEL=(CARRYINSEL=="OPMODE5")? 1'b1: 1'b0;
  localparam B_INPUT_SEL = (B_INPUT == "BCIN") ? 1'b1 : 1'b0;

  //===================================================
  // Internal signals
  //===================================================

  wire [17:0] B0_in, A0_out, B0_out, D_out, Pre_Adder_out;
  wire [17:0] Pre_Adder_out_MUX, A1_out, B1_out;
  wire [47:0] C_out, X_out, Z_out, Post_Adder_out;
  wire [35:0] Mult_out, M_out;
  wire [7:0] OPMODE_reg;
  wire CYI_in, CYI_out, CYO_in;

  //===================================================
  // DSP48 Output assignments
  //===================================================

  assign BCOUT = B1_out;
  assign M = M_out;
  assign CARRYOUTF = CARRYOUT;
  assign PCOUT = P;

  //===================================================
  // OPMODE Register Block
  //===================================================

  REG_MUX #(
      .WIDTH(8),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(OPMODEREG)
  ) OPMODE_Block (
      .CLK(CLK),
      .RST(RSTOPMODE),
      .CE (CEOPMODE),
      .D  (OPMODE),
      .Q  (OPMODE_reg)
  );

  //===================================================
  // Input Register blocks (First stage registers)
  //===================================================

  REG_MUX #(
      .WIDTH(18),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(DREG)
  ) D_Block (
      .CLK(CLK),
      .RST(RSTD),
      .CE (CED),
      .D  (D),
      .Q  (D_out)
  );

  MUX_2_1 #(
      .WIDTH(18)
  ) B0_MUX (
      .in0(B),
      .in1(BCIN),
      .SEL(B_INPUT_SEL),
      .out(B0_in)
  );

  REG_MUX #(
      .WIDTH(18),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(B0REG)
  ) B0_Block (
      .CLK(CLK),
      .RST(RSTB),
      .CE (CEB),
      .D  (B0_in),
      .Q  (B0_out)
  );

  REG_MUX #(
      .WIDTH(18),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(A0REG)
  ) A0_Block (
      .CLK(CLK),
      .RST(RSTA),
      .CE (CEA),
      .D  (A),
      .Q  (A0_out)
  );

  REG_MUX #(
      .WIDTH(48),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(CREG)
  ) C_Block (
      .CLK(CLK),
      .RST(RSTC),
      .CE (CEC),
      .D  (C),
      .Q  (C_out)
  );

  //===================================================
  // Pre_Adder_Block
  //===================================================

  Adder_Subtracter_WithOUT_CI_CO #(
      .WIDTH(18)
  ) Pre_Adder_Block (
      .A  (D_out),
      .B  (B0_out),
      .SEL(OPMODE_reg[6]),
      .SUM(Pre_Adder_out)
  );

  MUX_2_1 #(
      .WIDTH(18)
  ) Pre_Adder_MUX (
      .in0(B0_out),
      .in1(Pre_Adder_out),
      .SEL(OPMODE_reg[4]),
      .out(Pre_Adder_out_MUX)
  );

  //===================================================
  // Second stage registers
  //===================================================

  REG_MUX #(
      .WIDTH(18),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(B1REG)
  ) B1_Block (
      .CLK(CLK),
      .RST(RSTB),
      .CE (CEB),
      .D  (Pre_Adder_out_MUX),
      .Q  (B1_out)
  );

  REG_MUX #(
      .WIDTH(18),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(A1REG)
  ) A1_Block (
      .CLK(CLK),
      .RST(RSTA),
      .CE (CEA),
      .D  (A0_out),
      .Q  (A1_out)
  );

  //===================================================
  // Multiplication_Stage
  //===================================================

  Multiplier #(
      .WIDTH(18)
  ) Multiplier_Block (
      .A(A1_out),
      .B(B1_out),
      .P(Mult_out)
  );

  REG_MUX #(
      .WIDTH(36),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(MREG)
  ) M_Block (
      .CLK(CLK),
      .RST(RSTM),
      .CE (CEM),
      .D  (Mult_out),
      .Q  (M_out)
  );

  //===================================================
  // (X MUX & Z MUX) Stage
  //===================================================

  MUX_4_1 #(
      .WIDTH(48)
  ) X_MUX (
      .in0(48'd0),
      .in1({12'd0, M_out}),
      .in2(P),
      .in3({D_out[11:0], A1_out, B1_out}),
      .SEL(OPMODE_reg[1:0]),
      .out(X_out)
  );

  MUX_4_1 #(
      .WIDTH(48)
  ) Z_MUX (
      .in0(48'd0),
      .in1(PCIN),
      .in2(P),
      .in3(C_out),
      .SEL(OPMODE_reg[3:2]),
      .out(Z_out)
  );

  //===================================================
  // Post_Adder_Block
  //===================================================

  Adder_Subtracter_With_CI_CO #(
      .WIDTH(48)
  ) Post_Adder_Block (
      .A(Z_out),
      .B(X_out),
      .CARRYIN(CYI_out),
      .SEL(OPMODE_reg[7]),
      .SUM(Post_Adder_out),
      .CARRYOUT(CYO_in)
  );

  //===================================================
  // (Carry In & Carry Out) Stage
  //===================================================

  MUX_2_1 #(
      .WIDTH(1)
  ) CARRYIN_MUX (
      .in0(CARRYIN),
      .in1(OPMODE_reg[5]),
      .SEL(CARRYINSEL_SEL),
      .out(CYI_in)
  );

  REG_MUX #(
      .WIDTH(1),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(CARRYINREG)
  ) CYI_Block (
      .CLK(CLK),
      .RST(RSTCARRYIN),
      .CE (CECARRYIN),
      .D  (CYI_in),
      .Q  (CYI_out)
  );

  REG_MUX #(
      .WIDTH(1),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(CARRYOUTREG)
  ) CYO_Block (
      .CLK(CLK),
      .RST(RSTCARRYIN),
      .CE (CECARRYIN),
      .D  (CYO_in),
      .Q  (CARRYOUT)
  );

  //===================================================
  // Output Stage
  //===================================================

  REG_MUX #(
      .WIDTH(48),
      .RSTTYPE(RSTTYPE),
      .NO_PIPELINES(PREG)
  ) P_Block (
      .CLK(CLK),
      .RST(RSTP),
      .CE (CEP),
      .D  (Post_Adder_out),
      .Q  (P)
  );
endmodule

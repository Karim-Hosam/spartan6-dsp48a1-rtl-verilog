module DSP48A1_tb ();

  reg [17:0] A, B, D, BCIN;
  reg [47:0] C, PCIN;
  reg CARRYIN, CLK;
  reg [7:0] OPMODE;
  reg RSTA, RSTB, RSTC, RSTCARRYIN, RSTD, RSTM, RSTOPMODE, RSTP;
  reg CEA, CEB, CEC, CECARRYIN, CED, CEM, CEOPMODE, CEP;

  wire [47:0] P, PCOUT;
  wire [17:0] BCOUT;
  wire [35:0] M;
  wire CARRYOUTF, CARRYOUT;

  reg [47:0] P_expected, PCOUT_expected;
  reg [17:0] BCOUT_expected;
  reg [35:0] M_expected;
  reg CARRYOUTF_expected, CARRYOUT_expected;

  DSP48A1 #(
      .A0REG(0), .A1REG(1), .B0REG(0), .B1REG(1), .CREG(1), .DREG(1), .MREG(1), .PREG(1), .CARRYINREG(1),
      .CARRYOUTREG(1), .OPMODEREG(1), .CARRYINSEL("OPMODE5"), .B_INPUT("DIRECT"), .RSTTYPE("SYNC")
  ) DUT (
      .A(A), .B(B), .C(C), .D(D),
      .CARRYIN(CARRYIN), .CLK(CLK),
      .OPMODE(OPMODE), .BCIN  (BCIN),
      .RSTA(RSTA), .RSTB(RSTB), .RSTC(RSTC),
      .RSTCARRYIN(RSTCARRYIN), .RSTD(RSTD),
      .RSTM(RSTM), .RSTOPMODE(RSTOPMODE), .RSTP(RSTP),
      .CEA(CEA), .CEB(CEB), .CEC(CEC),
      .CECARRYIN(CECARRYIN), .CED(CED),
      .CEM(CEM), .CEOPMODE(CEOPMODE), .CEP(CEP), 
      .PCIN(PCIN), .P(P), .PCOUT(PCOUT),
      .BCOUT(BCOUT), .M(M), .CARRYOUTF(CARRYOUTF),
      .CARRYOUT (CARRYOUT)
  );

  initial begin
    CLK = 0;
    forever #5 CLK = ~CLK;  // Clock period of 10 time units
  end

  initial begin

    //========================================================================
    // 2.1. Verify Reset Operation
    //========================================================================

    // Assert all active-high reset signals by setting them to 1
    RSTA = 1; RSTB = 1; RSTC = 1; RSTCARRYIN = 1; RSTD = 1; RSTM = 1; RSTOPMODE = 1; RSTP = 1;

    // Drive remaining inputs with arbitrary (random) values.
    A = $random; B = $random; C = $random; D = $random; BCIN = $random; CARRYIN = $random; 
    OPMODE = $random; CEA = $random; CEB = $random; CEC = $random; CECARRYIN = $random; 
    CED = $random; CEM = $random; CEOPMODE = $random; CEP = $random; PCIN = $random;

    // Wait for the negative edge of the clock.
    repeat (2) @(negedge CLK);

    // Add a condition for self-checking to verify that all outputs are zero.
    if (P !== 0 || PCOUT !== 0 || BCOUT !== 0 || M !== 0 || CARRYOUTF !== 0 || CARRYOUT !== 0) begin
      $display("Reset Verification failed: Outputs are not zero after reset.");
      $stop;
    end else begin
      $display("Reset Verification passed: Outputs are zero after reset.");
    end

    // Deassert all reset signals and assert all clock enable signals
    RSTA = 0; RSTB = 0; RSTC = 0; RSTCARRYIN = 0; RSTD = 0; RSTM = 0; RSTOPMODE = 0; RSTP = 0;
    CEA = 1; CEB = 1; CEC = 1; CECARRYIN = 1; CED = 1; CEM = 1; CEOPMODE = 1; CEP = 1; 

    repeat (2) @(negedge CLK);

    //========================================================================
    // 2.2. Verify DSP Path 1
    //========================================================================

    // Initialize inputs
    OPMODE = 8'b11011101;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;
    BCOUT_expected = 'hf; M_expected = 'h12c; P_expected = 'h32;
    PCOUT_expected = 'h32; CARRYOUT_expected = 0; CARRYOUTF_expected = 0;

    repeat (4) @(negedge CLK);

    // Check outputs
    if (P !== P_expected || PCOUT !== PCOUT_expected || BCOUT !== BCOUT_expected || 
        M !== M_expected || CARRYOUTF !== CARRYOUTF_expected || CARRYOUT !== CARRYOUT_expected) begin
      $display("DSP Path 1 Verification failed: Outputs do not match expected values.");
      $stop;
    end else begin
      $display("DSP Path 1 Verification passed: Outputs match expected values.");
    end

    //========================================================================
    // 2.3. Verify DSP Path 2
    //========================================================================

    // Initialize inputs
    OPMODE = 8'b00010000;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;
    BCOUT_expected = 'h23; M_expected = 'h2bc; P_expected = 0;
    PCOUT_expected = 0; CARRYOUT_expected = 0; CARRYOUTF_expected = 0;

    repeat (4) @(negedge CLK);

    // Check outputs
    if (P !== P_expected || PCOUT !== PCOUT_expected || BCOUT !== BCOUT_expected ||
        M !== M_expected || CARRYOUTF !== CARRYOUTF_expected || CARRYOUT !== CARRYOUT_expected) begin
      $display("DSP Path 2 Verification failed: Outputs do not match expected values.");
      $stop;
    end else begin
      $display("DSP Path 2 Verification passed: Outputs match expected values.");
    end

    //========================================================================
    // 2.4. Verify DSP Path 3
    //========================================================================

    // Initialize inputs
    OPMODE = 8'b00001010;
    A = 20; B = 10; C = 350; D = 25;
    BCIN = $random; PCIN = $random; CARRYIN = $random;
    BCOUT_expected = 'ha; M_expected = 'hc8; P_expected = 0;
    PCOUT_expected = 0; CARRYOUT_expected = 0; CARRYOUTF_expected = 0;

    repeat (4) @(negedge CLK);

    // Check outputs

    if (P !== P_expected || PCOUT !== PCOUT_expected || BCOUT !== BCOUT_expected ||
        M !== M_expected || CARRYOUTF !== CARRYOUTF_expected || CARRYOUT !== CARRYOUT_expected) begin
      $display("DSP Path 3 Verification failed: Outputs do not match expected values.");
      $stop;
    end else begin
      $display("DSP Path 3 Verification passed: Outputs match expected values.");
    end

    //========================================================================
    // 2.5. Verify DSP Path 4
    //========================================================================

    // Initialize inputs
    OPMODE = 8'b10100111;
    A = 5; B = 6; C = 350; D = 25; PCIN = 3000;
    BCIN = $random; CARRYIN = $random;
    BCOUT_expected = 'h6; M_expected = 'h1e; P_expected = 'hfe6fffec0bb1; 
    PCOUT_expected = 'hfe6fffec0bb1; CARRYOUT_expected = 1; CARRYOUTF_expected = 1;

    repeat (4) @(negedge CLK);

    // Check outputs

    if (P !== P_expected || PCOUT !== PCOUT_expected || BCOUT !== BCOUT_expected ||
        M !== M_expected || CARRYOUTF !== CARRYOUTF_expected || CARRYOUT !== CARRYOUT_expected) begin
      $display("DSP Path 3 Verification failed: Outputs do not match expected values.");
      $stop;
    end else begin
      $display("DSP Path 3 Verification passed: Outputs match expected values.");
    end

    $stop;  // Stop the simulation after all tests
  end
endmodule

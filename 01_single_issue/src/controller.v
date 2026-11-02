module controller(input  clk, reset,
                  input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,
                  input        ZeroE,
                  output [1:0] ResultSrcW, ResultSrcE,
                  output MemWriteM,
                  output PCSrcE, ALUSrcE,
                  output RegWriteM, RegWriteW, JumpE,
                  output [1:0] ImmSrcD, 
                  output [2:0] ALUControlE,
                  input        FlushE);
  
  wire [1:0] ALUOp; 
  
  wire       RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
  wire [1:0] ResultSrcD;
  wire [2:0] ALUControlD;
  
  wire       RegWriteE, MemWriteE, BranchE;
  
  wire [1:0] ResultSrcM;
  
  // D -> E: RegWrite(1) + ResultSrc(2) + MemWrite(1) + Jump(1) + Branch(1) + ALUControl(3) + ALUSrc(1) = 10 bits
  floperc #(10) regE(clk, reset, 1'b1, FlushE,
      {RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUControlD, ALUSrcD},
      {RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, ALUControlE, ALUSrcE});

  // E -> M: RegWrite(1) + ResultSrc(2) + MemWrite(1) = 4 bits
  flopr #(4) regM(clk, reset,
      {RegWriteE, ResultSrcE, MemWriteE},
      {RegWriteM, ResultSrcM, MemWriteM});

  // M -> W: RegWrite(1) + ResultSrc(2) = 3 bits
  flopr #(3) regW(clk, reset,
      {RegWriteM, ResultSrcM},
      {RegWriteW, ResultSrcW});
  
  maindec md(
    .op(op), 
    .ResultSrc(ResultSrcD), 
    .MemWrite(MemWriteD), 
    .Branch(BranchD),
    .ALUSrc(ALUSrcD), 
    .RegWrite(RegWriteD), 
    .Jump(JumpD), 
    .ImmSrc(ImmSrcD), 
    .ALUOp(ALUOp)
  ); 

  aludec  ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7b5), 
    .ALUOp(ALUOp), 
    .ALUControl(ALUControlD)
  ); 

  assign PCSrcE = BranchE & ZeroE | JumpE; 
endmodule
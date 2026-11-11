// ============================================================
// Datapath Dual-Issue In-Order (E2)
//  - Un PC; la imem entrega 2 instrucciones por ciclo {PC, PC+4}.
//  - Via 0 = instruccion mas antigua del par, via 1 = mas joven. Ambas vias son
//    simetricas: cada una tiene su ALU, su extensor, su sumador de target y su
//    forwarding de 5 fuentes.
//  - Recursos compartidos:
//      * 1 puerto de memoria de datos  -> mux en M (la Issue Unit garantiza <= 1 lw/sw por par)
//      * 1 recurso de branch           -> mux de PCSrc / PCTarget en E (<= 1 beq/jal por par)
//  - Re-agrupamiento: si solo sale la instruccion antigua, la joven NO se guarda en
//    ningun buffer: se vuelve a leer de la imem con la direccion PCD_0+4, de modo que
//    el registro F/D recibe el par {joven, siguiente}. No se pierde ni se duplica nada.
// ============================================================
module datapath(input  clk, reset,
                // ---- control por via (desde controller c_0 / c_1) ----
                input  [1:0]  ResultSrcW_0, ResultSrcW_1,
                input  [1:0]  ResultSrcM_0, ResultSrcM_1,
                input         MemWriteM_0, MemWriteM_1,
                input         PCSrcE_0, PCSrcE_1,
                input         ALUSrcE_0, ALUSrcE_1,
                input         RegWriteW_0, RegWriteW_1,
                input  [1:0]  ImmSrcD_0, ImmSrcD_1,
                input  [2:0]  ALUControlE_0, ALUControlE_1,
                output        Zero_0, Zero_1,
                // ---- fetch ----
                output [31:0] PCF,              // direccion efectiva de fetch (hacia imem)
                input  [63:0] InstrF,
                output [63:0] InstrD, InstrE, InstrM, InstrW,
                // ---- memoria de datos (1 solo puerto) ----
                output [31:0] ALUResultM, WriteDataM,
                output        MemWrite,
                input  [31:0] ReadDataM,
                // ---- hacia la hazard unit ----
                output [4:0]  RdM_0, RdM_1, RdW_0, RdW_1,
                input  [2:0]  ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
                input         StallF, StallD, FlushD, FlushE_0, FlushE_1, FlushM_1,
                input         Partial);

  localparam WIDTH = 32;

  localparam FD_W = 32 + 32 + 32;                    // Instr, PC, PC+4              = 96
  localparam DE_W = 32 + 32 + 32 + 5 + 32 + 32 + 32; // RD1,RD2,PC,Rd,Imm,PC+4,Instr = 197
  localparam EM_W = 32 + 32 + 5 + 32 + 32;           // ALURes,WriteData,Rd,PC+4,Instr = 133
  localparam MW_W = 32 + 32 + 5 + 32 + 32;           // ALURes,ReadData,Rd,PC+4,Instr  = 133

  // ---------------- Fetch ----------------
  wire [31:0] PCReg;                  // registro PC (direccion del siguiente par "normal")
  wire [31:0] PCNext, PCTargetE, PCTargetE_0, PCTargetE_1;
  wire [31:0] PCPlusF_0, PCPlusF_1;   // FetchAddr+4 (PC de la inst. 1 y link de via 0), FetchAddr+8
  wire        PCSrcE;

  // ---------------- Decode ----------------
  wire [31:0] InstrD_0, InstrD_1;
  wire [31:0] PCD_0, PCD_1, PCPlusD_0, PCPlusD_1;
  wire [31:0] RD1D, RD2D, RD4D, RD5D;   // rf: rd1/rd2 -> via 0, rd4/rd5 -> via 1
  wire [31:0] ImmExtD_0, ImmExtD_1;

  // ---------------- Execute ----------------
  wire [31:0] InstrE_0, InstrE_1;
  wire [31:0] RD1E, RD2E, RD4E, RD5E;
  wire [31:0] PCE_0, PCE_1, PCPlusE_0, PCPlusE_1;
  wire [31:0] ImmExtE_0, ImmExtE_1;
  wire [4:0]  RdE_0, RdE_1;
  wire [31:0] SrcAE_0, SrcAE_1, SrcBE_0, SrcBE_1;
  wire [31:0] WriteDataE_0, WriteDataE_1;
  wire [31:0] ALUResultE_0, ALUResultE_1;

  // ---------------- Memory ----------------
  wire [31:0] InstrM_0, InstrM_1;
  wire [31:0] ALUResultM_0, ALUResultM_1, WriteDataM_0, WriteDataM_1;
  wire [31:0] PCPlusM_0, PCPlusM_1;
  wire [31:0] ResultM_0, ResultM_1;   // lo que una instruccion en M puede reenviar (ALU o PC+4)

  // ---------------- Writeback ----------------
  wire [31:0] InstrW_0, InstrW_1;
  wire [31:0] ALUResultW_0, ALUResultW_1, ReadDataW_0, ReadDataW_1;
  wire [31:0] PCPlusW_0, PCPlusW_1;
  wire [31:0] ResultW_0, ResultW_1;

  // ---------------- Salidas hacia riscvsingle ----------------
  assign InstrD = {InstrD_1, InstrD_0};
  assign InstrE = {InstrE_1, InstrE_0};
  assign InstrM = {InstrM_1, InstrM_0};
  assign InstrW = {InstrW_1, InstrW_0};

  // ============================================================
  // FETCH
  // ============================================================
  // Direccion de fetch: normalmente PCReg; si solo salio la instruccion antigua del par
  // en Decode, se re-lee desde la direccion de la instruccion joven (PCD_0 + 4).
  assign PCF = Partial ? PCPlusD_0 : PCReg;

  floperc #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .en(~StallF),
    .clear(1'b0),
    .d(PCNext),
    .q(PCReg)
  );

  adder pcadd4(.a(PCF), .b(32'd4), .y(PCPlusF_0));
  adder pcadd8(.a(PCF), .b(32'd8), .y(PCPlusF_1));

  // Recurso de branch unico: un solo salto tomado por ciclo (de la via 0 o de la via 1)
  assign PCSrcE    = PCSrcE_0 | PCSrcE_1;
  assign PCTargetE = PCSrcE_1 ? PCTargetE_1 : PCTargetE_0;

  mux2 #(WIDTH) pcmux(
    .d0(PCPlusF_1),     // secuencial: consume dos instrucciones
    .d1(PCTargetE),
    .s(PCSrcE),
    .y(PCNext)
  );

  // ============================================================
  // Registros de pipeline (uno por via)
  // ============================================================
  // Fetch -> Decode
  floperc #(FD_W) regFD_0(clk, reset, ~StallD, FlushD,
    {InstrF[31:0],  PCF,       PCPlusF_0},
    {InstrD_0,      PCD_0,     PCPlusD_0});

  floperc #(FD_W) regFD_1(clk, reset, ~StallD, FlushD,
    {InstrF[63:32], PCPlusF_0, PCPlusF_1},
    {InstrD_1,      PCD_1,     PCPlusD_1});

  // Decode -> Execute (se limpia la via que no se emite, o ambas si hay branch tomado)
  floperc #(DE_W) regDE_0(clk, reset, 1'b1, FlushE_0,
    {RD1D, RD2D, PCD_0, InstrD_0[11:7], ImmExtD_0, PCPlusD_0, InstrD_0},
    {RD1E, RD2E, PCE_0, RdE_0,          ImmExtE_0, PCPlusE_0, InstrE_0});

  floperc #(DE_W) regDE_1(clk, reset, 1'b1, FlushE_1,
    {RD4D, RD5D, PCD_1, InstrD_1[11:7], ImmExtD_1, PCPlusD_1, InstrD_1},
    {RD4E, RD5E, PCE_1, RdE_1,          ImmExtE_1, PCPlusE_1, InstrE_1});

  // Execute -> Memory (la via 1 se anula si la via 0 toma un salto)
  flopr #(EM_W) regEM_0(clk, reset,
    {ALUResultE_0, WriteDataE_0, RdE_0, PCPlusE_0, InstrE_0},
    {ALUResultM_0, WriteDataM_0, RdM_0, PCPlusM_0, InstrM_0});

  floperc #(EM_W) regEM_1(clk, reset, 1'b1, FlushM_1,
    {ALUResultE_1, WriteDataE_1, RdE_1, PCPlusE_1, InstrE_1},
    {ALUResultM_1, WriteDataM_1, RdM_1, PCPlusM_1, InstrM_1});

  // Memory -> Writeback (el dato leido de memoria es unico; cada via lo usa solo si es un lw)
  flopr #(MW_W) regMW_0(clk, reset,
    {ALUResultM_0, ReadDataM, RdM_0, PCPlusM_0, InstrM_0},
    {ALUResultW_0, ReadDataW_0, RdW_0, PCPlusW_0, InstrW_0});

  flopr #(MW_W) regMW_1(clk, reset,
    {ALUResultM_1, ReadDataM, RdM_1, PCPlusM_1, InstrM_1},
    {ALUResultW_1, ReadDataW_1, RdW_1, PCPlusW_1, InstrW_1});

  // ============================================================
  // DECODE
  // ============================================================
  regfile rf(
    .clk(clk),
    .we3(RegWriteW_0), .we6(RegWriteW_1),
    .a1(InstrD_0[19:15]), .a2(InstrD_0[24:20]),   // via 0
    .a4(InstrD_1[19:15]), .a5(InstrD_1[24:20]),   // via 1
    .a3(RdW_0),           .a6(RdW_1),
    .wd3(ResultW_0),      .wd6(ResultW_1),
    .rd1(RD1D), .rd2(RD2D),
    .rd4(RD4D), .rd5(RD5D)
  );

  extend ext0(.instr(InstrD_0[31:7]), .immsrc(ImmSrcD_0), .immext(ImmExtD_0));
  extend ext1(.instr(InstrD_1[31:7]), .immsrc(ImmSrcD_1), .immext(ImmExtD_1));

  // ============================================================
  // EXECUTE
  // ============================================================
  adder pcaddbranch_0(.a(PCE_0), .b(ImmExtE_0), .y(PCTargetE_0));
  adder pcaddbranch_1(.a(PCE_1), .b(ImmExtE_1), .y(PCTargetE_1));

  // Lo que M puede reenviar: resultado de la ALU, o PC+4 si es un jal (el lw no se reenvia
  // desde M: la Issue Unit inserta el stall load-use)
  assign ResultM_0 = (ResultSrcM_0 == 2'b10) ? PCPlusM_0 : ALUResultM_0;
  assign ResultM_1 = (ResultSrcM_1 == 2'b10) ? PCPlusM_1 : ALUResultM_1;

  // Forwarding de 5 fuentes por operando (prioridad: M1 > M0 > W1 > W0 > Register File)
  mux5 #(WIDTH) srcamuxE_0(.d0(RD1E), .d1(ResultM_1), .d2(ResultM_0), .d3(ResultW_1), .d4(ResultW_0), .s(ForwardAE_0), .y(SrcAE_0));
  mux5 #(WIDTH) srcbmuxE_0(.d0(RD2E), .d1(ResultM_1), .d2(ResultM_0), .d3(ResultW_1), .d4(ResultW_0), .s(ForwardBE_0), .y(WriteDataE_0));
  mux5 #(WIDTH) srcamuxE_1(.d0(RD4E), .d1(ResultM_1), .d2(ResultM_0), .d3(ResultW_1), .d4(ResultW_0), .s(ForwardAE_1), .y(SrcAE_1));
  mux5 #(WIDTH) srcbmuxE_1(.d0(RD5E), .d1(ResultM_1), .d2(ResultM_0), .d3(ResultW_1), .d4(ResultW_0), .s(ForwardBE_1), .y(WriteDataE_1));

  mux2 #(WIDTH) srcbmux_0(.d0(WriteDataE_0), .d1(ImmExtE_0), .s(ALUSrcE_0), .y(SrcBE_0));
  mux2 #(WIDTH) srcbmux_1(.d0(WriteDataE_1), .d1(ImmExtE_1), .s(ALUSrcE_1), .y(SrcBE_1));

  alu alu_0(.a(SrcAE_0), .b(SrcBE_0), .alucontrol(ALUControlE_0), .result(ALUResultE_0), .zero(Zero_0));
  alu alu_1(.a(SrcAE_1), .b(SrcBE_1), .alucontrol(ALUControlE_1), .result(ALUResultE_1), .zero(Zero_1));

  // ============================================================
  // MEMORY: un solo puerto compartido
  // ============================================================
  // La via 1 es dueña del puerto solo si lleva un lw/sw; en cualquier otro caso lo usa la via 0
  // (la Issue Unit garantiza que nunca hay dos accesos a memoria en el mismo par).
  wire memLane1 = MemWriteM_1 | (ResultSrcM_1 == 2'b01);

  assign ALUResultM = memLane1 ? ALUResultM_1 : ALUResultM_0;
  assign WriteDataM = memLane1 ? WriteDataM_1 : WriteDataM_0;
  assign MemWrite   = MemWriteM_0 | MemWriteM_1;

  // ============================================================
  // WRITEBACK
  // ============================================================
  mux3 #(WIDTH) resultmux_0(.d0(ALUResultW_0), .d1(ReadDataW_0), .d2(PCPlusW_0), .s(ResultSrcW_0), .y(ResultW_0));
  mux3 #(WIDTH) resultmux_1(.d0(ALUResultW_1), .d1(ReadDataW_1), .d2(PCPlusW_1), .s(ResultSrcW_1), .y(ResultW_1));

endmodule

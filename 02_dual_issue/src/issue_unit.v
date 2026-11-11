// ============================================================
// Issue Unit (etapa Decode) - Dual-Issue In-Order
// ------------------------------------------------------------
// Decide cuantas de las dos instrucciones del par {D0 (antigua), D1 (joven)}
// pueden pasar a Execute en este ciclo:
//   Issue0 = 1, Issue1 = 1 : se emiten las dos
//   Issue0 = 1, Issue1 = 0 : solo la antigua (la joven se re-agrupa con la siguiente)
//   Issue0 = 0, Issue1 = 0 : ninguna (stall del par)
// Nunca se emite solo la joven (orden de programa).
//
// Condiciones que impiden emitir la instruccion joven junto con la antigua:
//   - RAW intra-par: la antigua escribe un registro que la joven lee.
//   - Conflicto estructural de memoria: las dos son lw/sw (un solo puerto).
//   - Conflicto estructural de branch: las dos son beq/jal (un solo recurso de branch).
// Condicion que impide emitir una instruccion (load-use):
//   - La instruccion consume el destino de un lw que esta en Execute (cualquier via).
//     (el dato recien existe al final de MEM; se resuelve con 1 ciclo de espera).
// Todo lo demas (RAW contra M/W, WAW) lo resuelve el forwarding / la prioridad de escritura.
// ============================================================
module issue_unit(input  [31:0] InstrD_0, InstrD_1,   // par en Decode (0 = mas antigua)
                  input  [31:0] InstrE_0, InstrE_1,   // par en Execute
                  output        Issue0, Issue1);

  localparam [6:0] OP_LW   = 7'b0000011,
                   OP_SW   = 7'b0100011,
                   OP_R    = 7'b0110011,
                   OP_B    = 7'b1100011,
                   OP_I    = 7'b0010011,
                   OP_JAL  = 7'b1101111;

  // ---------------- decodificacion ligera de las dos candidatas ----------------
  wire [6:0] op0  = InstrD_0[6:0];
  wire [6:0] op1  = InstrD_1[6:0];
  wire [4:0] rd0  = InstrD_0[11:7];
  wire [4:0] rs10 = InstrD_0[19:15];
  wire [4:0] rs20 = InstrD_0[24:20];
  wire [4:0] rs11 = InstrD_1[19:15];
  wire [4:0] rs21 = InstrD_1[24:20];

  wire isMem0 = (op0 == OP_LW) | (op0 == OP_SW);
  wire isMem1 = (op1 == OP_LW) | (op1 == OP_SW);
  wire isBr0  = (op0 == OP_B)  | (op0 == OP_JAL);
  wire isBr1  = (op1 == OP_B)  | (op1 == OP_JAL);

  // la instruccion escribe un registro (rd != x0)
  wire wr0 = ((op0 == OP_LW) | (op0 == OP_R) | (op0 == OP_I) | (op0 == OP_JAL)) & (rd0 != 5'd0);

  // la instruccion lee realmente rs1 / rs2
  wire use1_0 = (op0 == OP_LW) | (op0 == OP_SW) | (op0 == OP_R) | (op0 == OP_I) | (op0 == OP_B);
  wire use2_0 = (op0 == OP_SW) | (op0 == OP_R)  | (op0 == OP_B);
  wire use1_1 = (op1 == OP_LW) | (op1 == OP_SW) | (op1 == OP_R) | (op1 == OP_I) | (op1 == OP_B);
  wire use2_1 = (op1 == OP_SW) | (op1 == OP_R)  | (op1 == OP_B);

  // ---------------- lw en Execute (cualquiera de las dos vias) ----------------
  wire        ldE0 = (InstrE_0[6:0] == OP_LW) & (InstrE_0[11:7] != 5'd0);
  wire        ldE1 = (InstrE_1[6:0] == OP_LW) & (InstrE_1[11:7] != 5'd0);
  wire [4:0]  rdE0 = InstrE_0[11:7];
  wire [4:0]  rdE1 = InstrE_1[11:7];

  // ---------------- load-use ----------------
  wire lu0 = (use1_0 & (rs10 != 5'd0) & ((ldE0 & (rdE0 == rs10)) | (ldE1 & (rdE1 == rs10)))) |
             (use2_0 & (rs20 != 5'd0) & ((ldE0 & (rdE0 == rs20)) | (ldE1 & (rdE1 == rs20))));

  wire lu1 = (use1_1 & (rs11 != 5'd0) & ((ldE0 & (rdE0 == rs11)) | (ldE1 & (rdE1 == rs11)))) |
             (use2_1 & (rs21 != 5'd0) & ((ldE0 & (rdE0 == rs21)) | (ldE1 & (rdE1 == rs21))));

  // ---------------- dependencias / conflictos dentro del par ----------------
  wire rawIntra = wr0 & ((use1_1 & (rs11 == rd0)) | (use2_1 & (rs21 == rd0)));
  wire structMem = isMem0 & isMem1;
  wire structBr  = isBr0  & isBr1;

  // ---------------- decision ----------------
  assign Issue0 = ~lu0;
  assign Issue1 = Issue0 & ~lu1 & ~rawIntra & ~structMem & ~structBr;
endmodule

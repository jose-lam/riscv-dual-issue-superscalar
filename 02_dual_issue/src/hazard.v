// ============================================================
// Hazard Unit - Dual-Issue
//  1) Forwarding entre vias y etapas (RAW): 4 operandos (A/B de cada via),
//     cada uno con 5 fuentes. Prioridad = productor mas reciente en orden de programa:
//        M via 1  >  M via 0  >  W via 1  >  W via 0  >  Register File
//  2) Control del pipeline a partir de la Issue Unit (stalls, re-agrupamiento)
//     y de la resolucion de branches (flush).
// ============================================================
module hazard(// ---- forwarding ----
              input  [4:0] Rs1E_0, Rs2E_0, Rs1E_1, Rs2E_1,
              input  [4:0] RdM_0, RdM_1, RdW_0, RdW_1,
              input        RegWriteM_0, RegWriteM_1, RegWriteW_0, RegWriteW_1,
              output [2:0] ForwardAE_0, ForwardBE_0, ForwardAE_1, ForwardBE_1,
              // ---- issue / branch ----
              input        Issue0, Issue1,          // decision de la Issue Unit (etapa D)
              input        PCSrcE_0, PCSrcE_1,      // branch/jump tomado en E (por via)
              output       StallF, StallD,
              output       FlushD, FlushE_0, FlushE_1, FlushM_1,
              output       Partial);                // sale solo la antigua: re-fetch de la joven

  // ---------------- forwarding ----------------
  // (todas las entradas se pasan como argumentos para que el assign se re-evalue siempre)
  function [2:0] fwd;
    input [4:0] rs;
    input [4:0] rdm1, rdm0, rdw1, rdw0;
    input       wm1, wm0, ww1, ww0;
    begin
      if (rs == 5'd0)                  fwd = 3'd0;
      else if (wm1 && (rdm1 == rs))    fwd = 3'd1;   // M via 1
      else if (wm0 && (rdm0 == rs))    fwd = 3'd2;   // M via 0
      else if (ww1 && (rdw1 == rs))    fwd = 3'd3;   // W via 1
      else if (ww0 && (rdw0 == rs))    fwd = 3'd4;   // W via 0
      else                             fwd = 3'd0;   // Register File
    end
  endfunction

  assign ForwardAE_0 = fwd(Rs1E_0, RdM_1, RdM_0, RdW_1, RdW_0, RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0);
  assign ForwardBE_0 = fwd(Rs2E_0, RdM_1, RdM_0, RdW_1, RdW_0, RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0);
  assign ForwardAE_1 = fwd(Rs1E_1, RdM_1, RdM_0, RdW_1, RdW_0, RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0);
  assign ForwardBE_1 = fwd(Rs2E_1, RdM_1, RdM_0, RdW_1, RdW_0, RegWriteM_1, RegWriteM_0, RegWriteW_1, RegWriteW_0);

  // ---------------- control de flujo ----------------
  wire PCSrcE = PCSrcE_0 | PCSrcE_1;      // un solo branch por ciclo (la Issue Unit lo garantiza)

  assign Partial  = Issue0 & ~Issue1;

  // stall: no se emite nada -> se congelan PC y F/D (un branch tomado tiene prioridad)
  assign StallF   = ~Issue0 & ~PCSrcE;
  assign StallD   = ~Issue0;              // FlushD tiene prioridad sobre el enable en floperc
  assign FlushD   = PCSrcE;               // se anula el par que esta en Decode/Fetch

  // burbujas en D/E: la via que no se emite, o ambas si hay branch tomado
  assign FlushE_0 = ~Issue0 | PCSrcE;
  assign FlushE_1 = ~Issue1 | PCSrcE;

  // si el branch tomado es de la via 0, la via 1 (mas joven, mismo par) se anula al pasar a M.
  // si el branch es de la via 1, la via 0 (mas antigua) se conserva.
  assign FlushM_1 = PCSrcE_0;
endmodule

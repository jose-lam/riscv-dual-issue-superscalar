// ============================================================
// Branch Target Buffer + predictor dinamico de 2 bits (etapa Fetch)
// ------------------------------------------------------------
//  - Tabla de correspondencia directa de ENTRIES entradas, indexada con PC[IDX+1:2].
//  - Cada entrada: valid | tag (= PC[31:IDX+2], etiqueta COMPLETA) | target | contador 2 bits.
//      contador: 00 SNT, 01 WNT, 10 WT, 11 ST   (predice tomado si ctr[1] = 1)
//  - Dos puertos de lectura combinacionales (las dos instrucciones del par: PCF y PCF+4).
//  - Un puerto de escritura (etapa EX, recurso unico de branch -> un salto resuelto por ciclo):
//      * acierto en el BTB : contador saturado +1 (tomado) / -1 (no tomado); si es tomado
//                            se refresca el destino.
//      * fallo en el BTB   : si el salto fue tomado se asigna la entrada (valid=1, tag,
//                            target, contador = WT). Los saltos no tomados no se guardan
//                            (en el fetch equivalen a "siguiente secuencial").
// ============================================================
module btb #(parameter ENTRIES = 16,
             parameter IDX     = 4)            // log2(ENTRIES)
           (input         clk, reset,
            // ---- lectura (Fetch) ----
            input  [31:0] pcA, pcB,            // PC de la instruccion de la via 0 y de la via 1
            output        hitA, hitB,          // la entrada es valida y la etiqueta coincide
            output        takenA, takenB,      // contador en WT/ST
            output [31:0] targetA, targetB,
            // ---- actualizacion (Execute) ----
            input         upd,                 // hay un beq/jal resuelto en EX
            input  [31:0] updPC,
            input         updTaken,
            input  [31:0] updTarget);

  localparam TAGW = 32 - IDX - 2;

  reg              valid  [0:ENTRIES-1];
  reg [TAGW-1:0]   tag    [0:ENTRIES-1];
  reg [31:0]       target [0:ENTRIES-1];
  reg [1:0]        ctr    [0:ENTRIES-1];

  // ---------------- lectura ----------------
  wire [IDX-1:0] iA = pcA[IDX+1:2];
  wire [IDX-1:0] iB = pcB[IDX+1:2];

  assign hitA    = valid[iA] & (tag[iA] == pcA[31:IDX+2]);
  assign hitB    = valid[iB] & (tag[iB] == pcB[31:IDX+2]);
  assign takenA  = ctr[iA][1];
  assign takenB  = ctr[iB][1];
  assign targetA = target[iA];
  assign targetB = target[iB];

  // ---------------- actualizacion ----------------
  wire [IDX-1:0] iU   = updPC[IDX+1:2];
  wire           hitU = valid[iU] & (tag[iU] == updPC[31:IDX+2]);

  integer k;
  always @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < ENTRIES; k = k + 1) begin
        valid[k]  <= 1'b0;
        tag[k]    <= {TAGW{1'b0}};
        target[k] <= 32'b0;
        ctr[k]    <= 2'b01;
      end
    end else if (upd) begin
      if (hitU) begin
        if (updTaken) begin
          if (ctr[iU] != 2'b11) ctr[iU] <= ctr[iU] + 2'b01;
          target[iU] <= updTarget;
        end else begin
          if (ctr[iU] != 2'b00) ctr[iU] <= ctr[iU] - 2'b01;
        end
      end else if (updTaken) begin
        valid[iU]  <= 1'b1;
        tag[iU]    <= updPC[31:IDX+2];
        target[iU] <= updTarget;
        ctr[iU]    <= 2'b10;   // WT: el siguiente encuentro ya se predice tomado
      end
    end
  end
endmodule

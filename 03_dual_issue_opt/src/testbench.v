// Testbench Dual-Issue + predictor 2 bits con BTB (arquitectura C) con metricas.
//  - Programa:  +prog=<archivo.dat>   (por defecto riscvtest.dat)
//  - Ondas:     +vcd                  (genera build/wave.vcd)
//  - Parametros (iverilog -P):  testbench.ENABLE_BTB=0|1 , testbench.BTB_ENTRIES / BTB_IDX
//      ENABLE_BTB=0 reproduce el Dual-Issue de E2 ciclo a ciclo.
//  - Fin:       cuando la instruccion HALT (jal x0,0 = 0x0000006F) llega a Writeback,
//               o al llegar a MAX_CYCLES (STATUS TIMEOUT).
//  - Criterio de medicion (IGUAL en las tres arquitecturas):
//      cycles        = flancos de reloj con reset=0 hasta (e incluyendo) el ciclo en que HALT esta en W
//      retired       = instrucciones no nulas observadas en W (incluye HALT)
//      cycles_nofin  = ciclos hasta (e incluyendo) el ultimo ciclo en que se retira una instruccion
//                      distinta de HALT  -> excluye el bucle final "fin: jal x0, fin"
//      retired_nofin = retired sin contar HALT
module testbench;
  parameter ENABLE_BTB  = 1;
  parameter BTB_ENTRIES = 16;
  parameter BTB_IDX     = 4;

  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;

  // instantiate device to be tested
  top dut(
    .clk(clk),
    .reset(reset),
    .WriteData(WriteData),
    .DataAdr(DataAdr),
    .MemWrite(MemWrite)
  );

  // los parametros del nucleo se fijan desde aqui (top.v no se modifica)
  defparam dut.rvsingle.ENABLE_BTB  = ENABLE_BTB;
  defparam dut.rvsingle.BTB_ENTRIES = BTB_ENTRIES;
  defparam dut.rvsingle.BTB_IDX     = BTB_IDX;

  // initialize test
  initial begin
    reset = 1; # 22;
    reset = 0;
  end

  // generate clock to sequence tests
  always begin
    clk = 1;
    # 5; clk = 0; # 5;
  end

  // ------------------------------------------------------------
  // Metricas
  // ------------------------------------------------------------
  localparam [31:0] HALT       = 32'h0000006F;
  localparam integer MAX_CYCLES = 100000;

  integer cycles, retired, dual_cycles, stall_cycles, flush_cycles, partial_cycles, last_ret;
  integer br_total, br_taken, br_correct, br_mispred, btb_hits, flush_avoided, flush_new;
  integer i;
  reg     done;
  real    ipc, cpi, acc, hitrate;

  wire [31:0] iw0 = dut.rvsingle.InstrW[31:0];    // via 0 en Writeback
  wire [31:0] iw1 = dut.rvsingle.InstrW[63:32];   // via 1 en Writeback

  // ---- saltos en Execute (un beq/jal como maximo por ciclo: recurso unico de branch) ----
  wire [31:0] ie0 = dut.rvsingle.InstrE[31:0];
  wire [31:0] ie1 = dut.rvsingle.InstrE[63:32];
  wire brE0 = (ie0[6:0] == 7'b1100011) | (ie0[6:0] == 7'b1101111);
  wire brE1 = (ie1[6:0] == 7'b1100011) | (ie1[6:0] == 7'b1101111);
  wire takenE    = brE1 ? dut.rvsingle.PCSrc_1           : dut.rvsingle.PCSrc_0;
  wire predTE    = brE1 ? dut.rvsingle.dp.predTakenE_1   : dut.rvsingle.dp.predTakenE_0;
  wire predHitE  = brE1 ? dut.rvsingle.dp.predHitE_1     : dut.rvsingle.dp.predHitE_0;
  wire mispredE  = dut.rvsingle.Mispredict;

  initial begin
    cycles = 0; retired = 0; dual_cycles = 0; last_ret = 0;
    stall_cycles = 0; flush_cycles = 0; partial_cycles = 0;
    br_total = 0; br_taken = 0; br_correct = 0; br_mispred = 0;
    btb_hits = 0; flush_avoided = 0; flush_new = 0;
    done = 0;
    if ($test$plusargs("vcd")) begin
      $dumpfile("build/wave.vcd");
      $dumpvars(0, testbench);
    end
  end

  task report;
    input integer timed_out;
    begin
      ipc = retired; ipc = ipc / cycles;
      cpi = cycles;  cpi = cpi / retired;
      $display("RESULT_BEGIN");
      if (timed_out) $display("STATUS TIMEOUT"); else $display("STATUS OK");
      for (i = 0; i < 32; i = i + 1)
        $display("x%0d = %h", i, dut.rvsingle.dp.rf.rf[i]);
      for (i = 0; i < 1024; i = i + 1)
        if (dut.dmem.RAM[i] !== 32'b0) $display("mem[%0d] = %h", i, dut.dmem.RAM[i]);
      $display("METRIC cycles = %0d", cycles);
      $display("METRIC retired = %0d", retired);
      $display("METRIC ipc = %f", ipc);
      $display("METRIC cpi = %f", cpi);
      $display("METRIC cycles_nofin = %0d", last_ret);
      $display("METRIC retired_nofin = %0d", retired - 1);
      $display("METRIC dual_retire_cycles = %0d", dual_cycles);
      $display("METRIC stall_cycles = %0d", stall_cycles);
      $display("METRIC flush_cycles = %0d", flush_cycles);
      $display("METRIC partial_issue_cycles = %0d", partial_cycles);
      // ---- metricas propias de la optimizacion ----
      $display("METRIC btb_enabled = %0d", ENABLE_BTB);
      $display("METRIC btb_entries = %0d", BTB_ENTRIES);
      $display("METRIC branches = %0d", br_total);
      $display("METRIC branches_taken = %0d", br_taken);
      $display("METRIC pred_correct = %0d", br_correct);
      $display("METRIC pred_wrong = %0d", br_mispred);
      $display("METRIC btb_hits = %0d", btb_hits);
      $display("METRIC flushes_avoided = %0d", flush_avoided);
      $display("METRIC flushes_new = %0d", flush_new);
      if (br_total > 0) begin
        acc = br_correct; acc = acc / br_total;
        hitrate = btb_hits; hitrate = hitrate / br_total;
        $display("METRIC pred_accuracy = %f", acc);
        $display("METRIC btb_hit_rate = %f", hitrate);
      end
      $display("RESULT_END");
      $finish;
    end
  endtask

  always @(posedge clk) begin
    if (!reset && !done) begin
      cycles = cycles + 1;
      if (iw0 != 32'b0) retired = retired + 1;
      if (iw1 != 32'b0) retired = retired + 1;
      if (((iw0 != 32'b0) && (iw0 != HALT)) || ((iw1 != 32'b0) && (iw1 != HALT))) last_ret = cycles;
      if ((iw0 != 32'b0) && (iw1 != 32'b0)) dual_cycles = dual_cycles + 1;
      if (dut.rvsingle.StallD)  stall_cycles   = stall_cycles + 1;    // par retenido en Decode
      if (dut.rvsingle.FlushD)  flush_cycles   = flush_cycles + 1;    // prediccion erronea
      if (dut.rvsingle.Partial) partial_cycles = partial_cycles + 1;  // emision parcial (sale 1)
      // un salto resuelto en EX (siempre del camino correcto: el camino incorrecto se vacia antes)
      if (brE0 | brE1) begin
        br_total = br_total + 1;
        if (takenE)              br_taken      = br_taken + 1;
        if (mispredE)            br_mispred    = br_mispred + 1;
        else                     br_correct    = br_correct + 1;
        if (predHitE)            btb_hits      = btb_hits + 1;
        if (takenE & ~mispredE)  flush_avoided = flush_avoided + 1;   // en B este salto vaciaba el pipeline
        if (~takenE & predTE)    flush_new     = flush_new + 1;       // se predijo tomado y no lo era
        if ($test$plusargs("trace"))
          $display("BRANCH cyc=%0d via=%0d pc=%h instr=%h hit=%0d pred=%0d real=%0d %s",
                   cycles, brE1, brE1 ? dut.rvsingle.dp.PCE_1 : dut.rvsingle.dp.PCE_0,
                   brE1 ? ie1 : ie0, predHitE, predTE, takenE, mispredE ? "FALLO" : "ok");
      end
      if ((iw0 == HALT) || (iw1 == HALT)) begin
        done = 1;
        report(0);
      end else if (cycles >= MAX_CYCLES) begin
        done = 1;
        report(1);
      end
    end
  end
endmodule

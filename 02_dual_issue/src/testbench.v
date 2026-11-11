// Testbench Dual-Issue con metricas.
//  - Programa:  +prog=<archivo.dat>   (por defecto riscvtest.dat)
//  - Ondas:     +vcd                  (genera build/wave.vcd)
//  - Fin:       cuando la instruccion HALT (jal x0,0 = 0x0000006F) llega a Writeback,
//               o al llegar a MAX_CYCLES (STATUS TIMEOUT).
//  - Criterio de medicion (IGUAL en las tres arquitecturas):
//      cycles  = flancos de reloj con reset=0 hasta (e incluyendo) el ciclo en que HALT esta en W
//      retired = instrucciones no nulas observadas en W (incluye HALT; las burbujas valen 0x00000000)
module testbench;
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

  integer cycles, retired, dual_cycles, stall_cycles, flush_cycles, partial_cycles;
  integer i;
  reg     done;
  real    ipc, cpi;

  wire [31:0] iw0 = dut.rvsingle.InstrW[31:0];    // via 0 en Writeback
  wire [31:0] iw1 = dut.rvsingle.InstrW[63:32];   // via 1 en Writeback

  initial begin
    cycles = 0; retired = 0; dual_cycles = 0;
    stall_cycles = 0; flush_cycles = 0; partial_cycles = 0;
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
      for (i = 0; i < 64; i = i + 1)
        if (dut.dmem.RAM[i] !== 32'b0) $display("mem[%0d] = %h", i, dut.dmem.RAM[i]);
      $display("METRIC cycles = %0d", cycles);
      $display("METRIC retired = %0d", retired);
      $display("METRIC ipc = %f", ipc);
      $display("METRIC cpi = %f", cpi);
      $display("METRIC dual_retire_cycles = %0d", dual_cycles);
      $display("METRIC stall_cycles = %0d", stall_cycles);
      $display("METRIC flush_cycles = %0d", flush_cycles);
      $display("METRIC partial_issue_cycles = %0d", partial_cycles);
      $display("RESULT_END");
      $finish;
    end
  endtask

  always @(posedge clk) begin
    if (!reset && !done) begin
      cycles = cycles + 1;
      if (iw0 != 32'b0) retired = retired + 1;
      if (iw1 != 32'b0) retired = retired + 1;
      if ((iw0 != 32'b0) && (iw1 != 32'b0)) dual_cycles = dual_cycles + 1;
      if (dut.rvsingle.StallD)  stall_cycles   = stall_cycles + 1;    // par retenido en Decode
      if (dut.rvsingle.FlushD)  flush_cycles   = flush_cycles + 1;    // branch tomado
      if (dut.rvsingle.Partial) partial_cycles = partial_cycles + 1;  // emision parcial (sale 1)
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

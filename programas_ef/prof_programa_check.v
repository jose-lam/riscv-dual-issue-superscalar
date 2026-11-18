// ============================================================
// Verificador de cierre de etapas del programa del profesor (A, B, C, D).
// Se compila junto con CUALQUIERA de las tres arquitecturas (modulo raiz aparte; solo usa
// senales comunes: testbench.clk/reset/MemWrite/DataAdr, el Register File y la dmem).
//
// Cada etapa termina con un sw a una direccion conocida (x1 = 1536):
//   A: sw x10, 8(x1)  -> 1544      B: sw x18, 20(x1) -> 1556
//   C: sw x24, 32(x1) -> 1568      D: sw x31, 52(x1) -> 1588
// El sw escribe la memoria en el flanco de subida t. El Register File escribe en el flanco de
// bajada de la etapa W; en Dual-Issue el sw y su companero de par llegan juntos a W. Por eso el
// estado "justo despues del sw" se toma en la mitad del ciclo siguiente (flanco de bajada + 1):
//   - Single-Issue, o Dual con el sw en la via 0: foto de los registros tomada en t (todo lo
//     anterior al sw ya escribio; lo que viene con o detras del sw es MAS joven).
//   - Dual con el sw en la via 1: registros actuales (ya incluyen la escritura de la via 0 del
//     mismo par, que es MAS antigua que el sw).
// En ese instante se compara el estado COMPLETO (x0..x31 y la memoria) con el del enunciado.
// (testbench.iw1 = instruccion de la via 1 en W; el testbench Single-Issue la fija en 0)
// Uso en Vivado: agregar este archivo a las fuentes de simulacion y elaborar con dos
// modulos raiz: testbench y prof_check (xelab ... testbench prof_check).
//
// Senales para la waveform (grupo "check"):
//   chk_etapa   : 0 = ninguna, 1..4 = ultima etapa verificada (A..D)
//   chk_pulse   : 1 durante el ciclo en que se hace la comprobacion
//   chk_A..chk_D: quedan en 1 si la etapa coincide con el estado de referencia
//   chk_fail    : 1 si alguna comprobacion fallo
// ============================================================
module prof_check;
  reg [2:0] chk_etapa = 0;
  reg       chk_pulse = 0, chk_A = 0, chk_B = 0, chk_C = 0, chk_D = 0, chk_fail = 0;
  reg [2:0] pend = 0;            // etapa cuya comprobacion esta pendiente
  integer   cyc = 0, k, errs;
  reg [31:0] er [0:31];          // registros esperados
  reg [31:0] em [0:13];          // M[x1+0 .. x1+52] esperada
  reg [31:0] snap [0:31];        // foto del Register File en el flanco del sw de cierre
  reg [31:0] got  [0:31];        // registros que se comparan
  reg        swLane1;

  task expect_regs;              // registros comunes a todas las etapas (A)
    begin
      for (k = 0; k < 32; k = k + 1) er[k] = 0;
      for (k = 0; k < 14; k = k + 1) em[k] = 0;
      er[1] = 1536; er[2] = 1; er[3] = 8; er[4] = 3; er[5] = 11; er[6] = 5; er[7] = 16;
      er[8] = 2; er[9] = 7; er[10] = 12;
      em[0] = 11; em[1] = 5; em[2] = 12;
    end
  endtask

  task load_expected;
    input [2:0] e;
    begin
      expect_regs;
      if (e >= 2) begin
        er[11] = 11; er[12] = 16; er[13] = 5; er[14] = 12; er[15] = 7; er[16] = 7; er[17] = 16; er[18] = 23;
        em[3] = 7; em[4] = 16; em[5] = 23;
      end
      if (e >= 3) begin
        er[19] = 12; er[20] = 12; er[21] = 24; er[22] = 18; er[24] = 24; er[26] = 6;
        em[6] = 24; em[7] = 18; em[8] = 24;
      end
      if (e >= 4) begin
        er[19] = 6; er[20] = 6; er[25] = 4; er[26] = 4; er[27] = 1560; er[28] = 74; er[29] = 4;
        er[30] = 23; er[31] = 1;
        em[9] = 74; em[10] = 4; em[11] = 0; em[12] = 1; em[13] = 1;
      end
    end
  endtask

  // con +vcd las senales del verificador tambien van a la waveform (despues del $dumpfile)
  initial begin
    #0;
    if ($test$plusargs("vcd")) $dumpvars(0, prof_check);
  end

  // ---- deteccion del sw que cierra una etapa (flanco de subida t) ----
  always @(posedge testbench.clk) begin
    if (!testbench.reset) begin
      cyc = cyc + 1;
      if (chk_pulse) chk_pulse <= 1'b0;
      if (testbench.MemWrite) begin
        case (testbench.DataAdr)
          32'd1544: pend = 1;
          32'd1556: pend = 2;
          32'd1568: pend = 3;
          32'd1588: pend = 4;
          default:  pend = 0;
        endcase
        if (pend != 0)
          for (k = 0; k < 32; k = k + 1) snap[k] = testbench.dut.rvsingle.dp.rf.rf[k];
      end
    end
  end

  // ---- comprobacion a mitad del ciclo siguiente (despues de la escritura del Register File,
  //      antes del siguiente flanco de subida: no compite con el $finish del testbench) ----
  always @(negedge testbench.clk) begin
    #1;
    if (pend != 0) begin
      load_expected(pend);
      errs = 0;
      swLane1 = (testbench.iw1[6:0] == 7'b0100011);   // en W esta el par del sw
      for (k = 0; k < 32; k = k + 1) begin
        got[k] = swLane1 ? testbench.dut.rvsingle.dp.rf.rf[k] : snap[k];
        if (got[k] !== er[k]) begin
          errs = errs + 1;
          $display("CHECK etapa %0d: x%0d = %0d, esperado %0d", pend, k, got[k], er[k]);
        end
      end
      for (k = 0; k < 14; k = k + 1)
        if (testbench.dut.dmem.RAM[384 + k] !== em[k]) begin
          errs = errs + 1;
          $display("CHECK etapa %0d: M[x1+%0d] = %0d, esperado %0d", pend, 4 * k,
                   testbench.dut.dmem.RAM[384 + k], em[k]);
        end
      chk_etapa = pend;
      chk_pulse = 1'b1;
      if (errs != 0) chk_fail = 1'b1;
      else case (pend)
        1: chk_A = 1'b1;
        2: chk_B = 1'b1;
        3: chk_C = 1'b1;
        4: chk_D = 1'b1;
      endcase
      $display("CHECK etapa %s ciclo %0d: %s", (pend == 1) ? "A" : (pend == 2) ? "B" : (pend == 3) ? "C" : "D",
               cyc, (errs == 0) ? "OK" : "FALLO");
      pend = 0;
    end
  end
endmodule

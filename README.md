# RISC-V RV32I Superscalar Dual-Issue (Proyecto 2 — Arquitectura de Computadoras)

```
01_single_issue/    A: Pipeline Single-Issue de 5 etapas (E1)
02_dual_issue/      B: Dual-Issue In-Order (E2): Issue Unit, dos vías, forwarding entre vías
03_dual_issue_opt/  C: Dual-Issue + predictor de 2 bits con BTB en Fetch (EF)
  src/              Verilog (testbench.v es el top de simulación; btb.v solo existe en C)
  tb/               Programas (.dat, formato $readmemh) con la instrucción fuente comentada
programas_ef/       Programas de la EF, válidos para las tres arquitecturas: .asm, .dat, .exp (estado final
                    esperado) y prof_programa_check.v (verificador de las etapas A–D del profesor)
informe/            Informe final (PDF y Word) e informes de E1 (PDF) y E2 (Word)
```

ISA: `lw sw add sub and or slt addi andi ori slti beq jal`.

## Simulación en Vivado
1. Crear un proyecto de simulación y agregar como *Simulation Sources* todos los `.v` de **una** carpeta `src/`
   (A, B o C) y, para el programa del profesor, `programas_ef/prof_programa_check.v`.
2. Copiar el programa a ejecutar como `riscvtest.dat` en el directorio de simulación
   (`<proyecto>.sim/sim_1/behav/xsim/`); `imem` lo carga con `$readmemh`.
3. Simulation Settings → top: `testbench` (y `prof_check` si se agregó el verificador). Ejecutar *Run All*.

Por línea de comandos (carpeta de trabajo vacía, listando los `.v`, sin comodines):
```
copy programas_ef\prof_programa.dat riscvtest.dat
xvlog <cada .v de src\> programas_ef\prof_programa_check.v
xelab testbench prof_check -s sim
xsim sim -runall
```
Sin verificador (cualquier otro programa): no compilar `prof_programa_check.v` y elaborar solo `testbench`.
Con iverilog: `iverilog -g2012 -s testbench -s prof_check -o sim <src\*.v> programas_ef/prof_programa_check.v` y
`vvp sim +prog=programas_ef/prof_programa.dat`.

## Qué imprime el testbench
Termina cuando `halt` (`jal x0,0` = `0x0000006F`) llega a Writeback. Imprime registros, memoria y métricas
(ciclos, retiradas, IPC, CPI, stalls, flushes) con el mismo criterio en A, B y C; `cycles_nofin` y `retired_nofin`
excluyen el bucle final `fin`. `STATUS OK` es fin normal; `STATUS TIMEOUT`, límite de ciclos (los programas sin
`halt`, como `programa1_testdual`, terminan así). C añade las métricas del predictor (aciertos, precisión,
tasa de aciertos del BTB, flushes evitados). Con `+vcd` (xsim: `-testplusarg vcd`) escribe `build/wave.vcd`;
crear antes la carpeta `build`. Con el verificador, la waveform incluye `chk_pulse`, `chk_etapa`, `chk_A`…`chk_D`, `chk_fail`.

## Arquitectura C
- Parámetros de `testbench`: `ENABLE_BTB` (1 activa el predictor; 0 se comporta exactamente como B), `BTB_ENTRIES` (16)
  y `BTB_IDX` (4). En xsim: `xelab testbench prof_check -s sim -generic_top "ENABLE_BTB=0"` (desde `cmd`);
  en iverilog: `-Ptestbench.ENABLE_BTB=0`.
- Respecto a B cambian `datapath.v`, `hazard.v`, `riscvsingle.v` y `testbench.v`; `btb.v` es nuevo.

## Programas
- `programas_ef/prof_programa`: programa del profesor (etapas A–D). El verificador compara x0–x31 y la memoria al
  cierre de cada etapa e imprime `CHECK etapa X ciclo N: OK`.
- `programas_ef/ef1_btb`: validación del BTB (entrenamiento, vía 0 y vía 1, recuperación tras fallo).
- `programas_ef/ef2_benchmark`: programa propio de evaluación (genera, ordena con bubble sort y resume un arreglo).
- `*/tb/programa*`: programas de E1 y E2 (ALU en pareja, forwarding, RAW, load-use, conflicto de memoria, branches,
  doble escritura).

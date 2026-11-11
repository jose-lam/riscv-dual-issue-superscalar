# RISC-V RV32I Superscalar Dual-Issue (Proyecto 2 — Arquitectura de Computadoras)

```
01_single_issue/   Pipeline Single-Issue de 5 etapas (E1)
02_dual_issue/     Dual-Issue In-Order (E2): Issue Unit, dos vías, forwarding entre vías
  src/             Verilog (testbench.v es el top de simulación)
  tb/              Programas (.dat, formato $readmemh) con la instrucción fuente comentada
```

ISA: `lw sw add sub and or slt addi andi ori slti beq jal`.

## Simulación
- `imem` carga `riscvtest.dat` del directorio de simulación: copiar ahí el programa que se quiera ejecutar.
- La simulación termina cuando `halt` (`jal x0,0` = `0x0000006F`) llega a Writeback; el testbench imprime
  registros, memoria y métricas (ciclos, retiradas, IPC, CPI, stalls, flushes) con el mismo criterio en ambas arquitecturas.
  Los programas sin `halt` terminan por límite de ciclos (`STATUS TIMEOUT`).
- `02_dual_issue/tb/programa2..8` cubren los casos de E2: ALU en pareja, forwarding entre vías, RAW y reagrupamiento,
  load-use, conflicto de memoria, branches en ambas posiciones y doble escritura al Register File.

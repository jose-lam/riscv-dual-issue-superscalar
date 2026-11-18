# EF - Programa 1: validacion especifica del predictor de 2 bits + BTB
# ---------------------------------------------------------------------
# Casos que ejercita (ver traza con: run.ps1 -Arch 03 ... y  vvp +trace):
#  - INNER : salto hacia atras tomado 4 de 5 veces. El 1er encuentro falla (BTB vacio),
#            luego WT->ST y acierta; la salida (no tomado) falla 1 vez (ST->WT).
#            Al volver a entrar (siguiente vuelta de OUTER) el contador sigue en WT:
#            acierta sin re-aprender  -> histeresis del contador de 2 bits.
#  - jal SKIP : incondicional hacia adelante; tras el 1er encuentro siempre acierta. Si INNER
#            se predice tomado en la via 0, la instruccion de la via 1 (el jal) se descarta en F/D.
#  - NEVER : beq nunca tomado: no se guarda en el BTB, nunca provoca flush (ni en B ni en C).
#  - OUTER : salto hacia atras externo (3 vueltas).
#  - FLIP  : salto tomado 3 veces y luego no tomado 3 veces: muestra que tras ST hacen falta
#            DOS fallos para cambiar la prediccion (ST->WT->WNT).
#  - nop de relleno: desplazan los saltos para que aparezcan tanto en la via 0 como en la via 1.
# Estado final esperado: x2=15, x6=3, x7=6, x8=6, x9=9  y  mem[0..4] = 15, 3, 6, 6, 9
    addi x1, x0, 3          # vueltas del bucle externo
    addi x2, x0, 0          # acumulador del bucle interno
    addi x5, x0, 1          # constante 1 (para beq ... , x5)
    addi x6, x0, 0          # contador de jal tomados
    addi x7, x0, 0          # contador del camino "nunca tomado"
OUTER:
    addi x3, x0, 5          # vueltas del bucle interno
INNER:
    addi x2, x2, 1
    addi x3, x3, -1
    slt  x4, x0, x3         # x4 = (x3 > 0)
    beq  x4, x5, INNER      # hacia atras: T T T T N
    jal  x0, SKIP           # incondicional
    addi x2, x2, 100        # nunca se ejecuta (camino incorrecto)
SKIP:
    addi x6, x6, 1
    beq  x0, x5, NEVER      # nunca tomado
    addi x7, x7, 2
NEVER:
    addi x1, x1, -1
    slt  x4, x0, x1
    nop
    beq  x4, x5, OUTER      # hacia atras: T T N
# ---- FLIP: tomado mientras x10 < 3, luego no tomado ----
    addi x10, x0, 0
    addi x8, x0, 0
    addi x9, x0, 0
    addi x11, x0, 3
    addi x12, x0, 6
FLIP:
    slt  x4, x10, x11       # x10 < 3 ?
    beq  x4, x5, FT         # T T T N N N
    addi x9, x9, 3          # camino "no tomado"
    jal  x0, FJ
FT:
    addi x8, x8, 2          # camino "tomado"
FJ:
    addi x10, x10, 1
    slt  x4, x10, x12
    beq  x4, x5, FLIP       # hacia atras: 5 T y 1 N
    sw   x2, 0(x0)
    sw   x6, 4(x0)
    sw   x7, 8(x0)
    sw   x8, 12(x0)
    sw   x9, 16(x0)
    halt

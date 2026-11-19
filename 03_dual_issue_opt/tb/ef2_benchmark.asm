# EF - Programa 2 (programa propio de evaluacion): generar, ordenar y resumir un arreglo
# ---------------------------------------------------------------------------------------
# 1) GEN  : a[i] = (5 + 7*(i+1)) mod 13 para i = 0..11 (resta condicional en vez de modulo).
# 2) SORT : bubble sort de 12 elementos (bucles anidados, intercambio dependiente de los datos).
# 3) STAT : suma de los elementos y cuantos son >= 7.
# Ejercita: bucles (saltos hacia atras muy predecibles), saltos dependientes de datos (poco
# predecibles), load-use (lw seguido de slt), conflictos del puerto de memoria (lw/lw, sw/sw),
# RAW encadenados y emision doble de operaciones independientes.
# Datos en la direccion base 256 (mem[64..75]); resultados: mem[80] = suma, mem[81] = conteo.
# Esperado: arreglo ordenado 0 1 2 3 4 6 7 8 9 10 11 12, suma = 73, conteo (>=7) = 6.
    addi x10, x0, 256       # base del arreglo
    addi x11, x0, 12        # N
    addi x12, x0, 0         # i
    addi x13, x0, 5         # valor
    addi x14, x0, 13        # modulo
    addi x5,  x0, 1         # constante 1
GEN:
    addi x13, x13, 7        # valor += 7
    slt  x15, x13, x14      # valor < 13 ?
    beq  x15, x5, GOK
    sub  x13, x13, x14      # valor -= 13
GOK:
    add  x16, x12, x12
    add  x16, x16, x16      # i*4
    add  x16, x16, x10
    sw   x13, 0(x16)
    addi x12, x12, 1
    slt  x15, x12, x11
    beq  x15, x5, GEN
# ---- bubble sort ----
    addi x20, x11, -1       # comparaciones por pasada (N-1, decrece)
OUTER:
    add  x21, x10, x0       # puntero p = base
    addi x22, x0, 0         # j
INNER:
    lw   x24, 0(x21)
    lw   x25, 4(x21)
    slt  x26, x25, x24      # a[j+1] < a[j] ?
    beq  x26, x0, NOSWAP
    sw   x25, 0(x21)
    sw   x24, 4(x21)
NOSWAP:
    addi x21, x21, 4
    addi x22, x22, 1
    slt  x26, x22, x20
    beq  x26, x5, INNER
    addi x20, x20, -1
    slt  x26, x0, x20
    beq  x26, x5, OUTER
# ---- estadisticas ----
    addi x12, x0, 0
    addi x27, x0, 0         # suma
    addi x28, x0, 0         # conteo >= 7
    add  x21, x10, x0
    addi x29, x0, 6
STAT:
    lw   x24, 0(x21)
    add  x27, x27, x24
    slt  x26, x29, x24      # 6 < v  (v >= 7)
    beq  x26, x0, SKIP
    addi x28, x28, 1
SKIP:
    addi x21, x21, 4
    addi x12, x12, 1
    slt  x26, x12, x11
    beq  x26, x5, STAT
    sw   x27, 64(x10)
    sw   x28, 68(x10)
    halt

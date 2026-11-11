// Memoria de instrucciones (32 bits). El programa se elige con +prog=<archivo.dat>
// (si no se indica, se usa "riscvtest.dat"). Las palabras no cargadas valen 0.
module imem(input  [31:0] a,
            output [31:0] rd);

  reg [31:0] RAM[1023:0];
  reg [8*256-1:0] fname;
  integer i;

  initial begin
    for (i = 0; i < 1024; i = i + 1) RAM[i] = 32'b0;
    if (!$value$plusargs("prog=%s", fname)) fname = "riscvtest.dat";
    $readmemh(fname, RAM);
  end

  assign rd = RAM[a[11:2]]; // word aligned
endmodule

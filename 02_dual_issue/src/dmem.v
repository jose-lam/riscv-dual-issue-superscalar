// Memoria de datos de UN solo puerto (lectura combinacional, escritura en flanco de subida).
module dmem(input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);

  reg [31:0] RAM[1023:0];
  integer i;

  initial begin
    for (i = 0; i < 1024; i = i + 1) RAM[i] = 32'b0;
  end

  assign rd = RAM[a[11:2]]; // word aligned

  always @(posedge clk) begin
    if (we) RAM[a[11:2]] <= wd;
  end
endmodule

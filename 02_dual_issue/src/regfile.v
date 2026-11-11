// Register File: 4 lecturas combinacionales (via 0: a1/a2, via 1: a4/a5)
//                2 escrituras en flanco de bajada (via 0: a3, via 1: a6)
// Si ambas vias escriben el mismo registro en el mismo ciclo, gana la via 1
// (instruccion mas joven en orden de programa).
module regfile(input  clk,
               input  we3, we6,
               input  [ 4:0] a1, a2, a3, a4, a5, a6,
               input  [31:0] wd3, wd6,
               output [31:0] rd1, rd2, rd4, rd5);

  reg [31:0] rf[31:0];
  integer i;

  initial begin
    for (i = 0; i < 32; i = i + 1) rf[i] = 32'b0;
  end

  // escrituras en el flanco de bajada: A3/WD3/WE3 (via 0) y A6/WD6/WE6 (via 1)
  wire write0 = we3 && (a3 != 5'd0) && !(we6 && (a6 == a3));  // la via 1 pisa a la via 0
  wire write1 = we6 && (a6 != 5'd0);

  always @(negedge clk) begin
    if (write0) rf[a3] <= wd3;
    if (write1) rf[a6] <= wd6;
  end

  // lecturas combinacionales; el registro 0 vale siempre 0
  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
  assign rd4 = (a4 != 0) ? rf[a4] : 0;
  assign rd5 = (a5 != 0) ? rf[a5] : 0;
endmodule

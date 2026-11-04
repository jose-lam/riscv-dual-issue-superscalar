module imem(input  [31:0] a,
            output [63:0] rd);
  
  reg [31:0] RAM[63:0]; 

  initial begin
      $readmemh("riscvtest3.dat",RAM); 
  end

  assign rd = {RAM[a[31:2] + 1'b1], RAM[a[31:2]]}; // words aligned
endmodule
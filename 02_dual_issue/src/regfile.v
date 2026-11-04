module regfile(input  clk, 
               input  we3, we6, 
               input  [ 4:0] a1, a2, a3, a4, a5, a6, 
               input  [31:0] wd3, wd6, 
               output [31:0] rd1, rd2, rd4, rd5); 

  reg [31:0] rf[31:0]; 
  
  initial rf[0] = 32'b0;

  // write third and sixth port on negedge of clock (A3/WD3/WE3) and (A6/WD6/WE6)
  always @(negedge clk) begin 
    if (we3 && a3 != 0) rf[a3] <= wd3; 
    if (we6 && a6 != 0) rf[a6] <= wd6; 
  end

  // read four ports combinationally (A1/RD1, A2/RD2, A4/RD4, A5/RD5)
  // register 0 hardwired to 0
  assign rd1 = (a1 != 0) ? rf[a1] : 0; 
  assign rd2 = (a2 != 0) ? rf[a2] : 0; 
  assign rd4 = (a4 != 0) ? rf[a4] : 0; 
  assign rd5 = (a5 != 0) ? rf[a5] : 0; 
endmodule
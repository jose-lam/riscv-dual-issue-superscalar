module hazard(output        StallF, StallD, FlushD, FlushE,
              output [1:0]  ForwardAE, ForwardBE,
              input  [4:0]  Rs1D, Rs2D, RdE, Rs1E, Rs2E, RdM, RdW,
              input         PCSrcE, ResultSrc, RegWriteM, RegWriteW);
              
  wire lwStall = ((Rs1D == RdE) | (Rs2D == RdE)) & ResultSrc;
              
  assign ForwardAE = ((Rs1E == RdM) & RegWriteM & Rs1E != 5'b00000) ? (2'b10) : (((Rs1E == RdW) & RegWriteW & Rs1E != 5'b00000) ? (2'b01) : (2'b00));
  assign ForwardBE = ((Rs2E == RdM) & RegWriteM & Rs2E != 5'b00000) ? (2'b10) : (((Rs2E == RdW) & RegWriteW & Rs2E != 5'b00000) ? (2'b01) : (2'b00));
  assign StallF = lwStall;
  assign StallD = lwStall;
  assign FlushD = PCSrcE;
  assign FlushE = lwStall | PCSrcE;
  
  
endmodule

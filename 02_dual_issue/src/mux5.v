// Mux de 5 entradas para el forwarding de las dos vias.
// s = 0 : valor leido del Register File (registro D/E)
// s = 1 : resultado de la etapa M, via 1 (instruccion mas joven)
// s = 2 : resultado de la etapa M, via 0
// s = 3 : resultado de la etapa W, via 1
// s = 4 : resultado de la etapa W, via 0
module mux5 #(parameter WIDTH = 8) (input  [WIDTH-1:0] d0, d1, d2, d3, d4,
                                    input  [2:0]       s,
                                    output [WIDTH-1:0] y);

  assign y = (s == 3'd1) ? d1 :
             (s == 3'd2) ? d2 :
             (s == 3'd3) ? d3 :
             (s == 3'd4) ? d4 : d0;
endmodule

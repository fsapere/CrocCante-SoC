module cordic_z (
    input  wire signed [15:0] Z_i,
    input  wire signed [15:0] Arctan,
    input  wire               Enable,
    output reg  signed [15:0] Cordic_z
);

    always @(*) begin
        
        if (Enable == 1'b0) begin
            Cordic_z = Z_i - Arctan;
        end
        else begin
            Cordic_z = Z_i + Arctan;
        end
        
    end

endmodule
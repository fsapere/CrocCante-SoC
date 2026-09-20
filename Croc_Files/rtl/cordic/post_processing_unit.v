module post_processing_unit (
    input  wire signed [15:0] Cordic_x_in,
    input  wire signed [15:0] Cordic_y_in,
    input  wire               Cos_negate_in,
    input  wire               Sin_negate_in,
    output wire signed [15:0] Cos,
    output wire signed [15:0] Sin
);

    wire signed [15:0] temp_cos;
    wire signed [15:0] temp_sin;

    assign temp_cos = (Cos_negate_in) ? -Cordic_x_in : Cordic_x_in;
    assign temp_sin = (Sin_negate_in) ? -Cordic_y_in : Cordic_y_in;
    
    assign Cos = temp_cos;
    assign Sin = temp_sin;

endmodule
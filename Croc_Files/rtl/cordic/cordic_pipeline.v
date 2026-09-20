module cordic_pipeline (
    input  wire               Clk,
    input  wire               Reset,
    input  wire signed [15:0] Initial_x,
    input  wire signed [15:0] Initial_y,
    input  wire signed [15:0] Initial_z,
    input  wire               Initial_cos_negate,
    input  wire               Initial_sin_negate,
    output wire signed [15:0] Final_cordic_x,
    output wire signed [15:0] Final_cordic_y,
    output wire               Final_cos_negate,
    output wire               Final_sin_negate
);

    parameter STAGES = 16;
    
    wire signed [15:0] x_propagate [0:STAGES];
    wire signed [15:0] y_propagate [0:STAGES];
    wire signed [15:0] z_propagate [0:STAGES];
    wire               cos_negate_propagate [0:STAGES];
    wire               sin_negate_propagate [0:STAGES];
    
    wire signed [15:0] shifted_x [0:STAGES-1];
    wire signed [15:0] shifted_y [0:STAGES-1];
    wire signed [15:0] arctan [0:STAGES-1];
    wire               enable [0:STAGES-1];

    assign x_propagate[0] = Initial_x;
    assign y_propagate[0] = Initial_y;
    assign z_propagate[0] = Initial_z;
    assign cos_negate_propagate[0] = Initial_cos_negate;
    assign sin_negate_propagate[0] = Initial_sin_negate;

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : PIPELINE_STAGE
            
            assign shifted_x[i] = x_propagate[i] >>> i;
            assign shifted_y[i] = y_propagate[i] >>> i;
            assign enable[i] = (z_propagate[i] >= 16'sd0) ? 1'b0 : 1'b1;
            
            rom ROM1 (
                .Address(i[3:0]),
                .Data(arctan[i])
            );
            
            reg signed [15:0] x_reg, y_reg, z_reg;
            wire signed [15:0] x_next, y_next, z_next;

            cordic_x CX (
                .X_i(x_propagate[i]),
                .Shifted_y(shifted_y[i]),
                .Enable(enable[i]),
                .Cordic_x(x_next)
            );
            
            cordic_y CY (
                .Y_i(y_propagate[i]),
                .Shifted_x(shifted_x[i]),
                .Enable(enable[i]),
                .Cordic_y(y_next)
            );
            
            cordic_z CZ (
                .Z_i(z_propagate[i]),
                .Arctan(arctan[i]),
                .Enable(enable[i]),
                .Cordic_z(z_next)
            );

            reg cos_negate_reg;
            reg sin_negate_reg;
            
            always @(posedge Clk or negedge Reset) begin
                if (~Reset) begin
                    x_reg <= 16'sd0;
                    y_reg <= 16'sd0;
                    z_reg <= 16'sd0;
                    cos_negate_reg <= 1'b0;
                    sin_negate_reg <= 1'b0;
                end
                else begin
                    x_reg <= x_next;
                    y_reg <= y_next;
                    z_reg <= z_next;
                    cos_negate_reg <= cos_negate_propagate[i];
                    sin_negate_reg <= sin_negate_propagate[i];
                end
            end
            
            assign x_propagate[i+1] = x_reg;
            assign y_propagate[i+1] = y_reg;
            assign z_propagate[i+1] = z_reg;
            assign cos_negate_propagate[i+1] = cos_negate_reg;
            assign sin_negate_propagate[i+1] = sin_negate_reg;
            
        end
    endgenerate

    assign Final_cordic_x = x_propagate[STAGES];
    assign Final_cordic_y = y_propagate[STAGES];
    assign Final_cos_negate = cos_negate_propagate[STAGES];
    assign Final_sin_negate = sin_negate_propagate[STAGES];

endmodule
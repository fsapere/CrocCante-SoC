module cordic_top (
    input  wire        Clk,
    input  wire        Reset,
    input  wire [16:0] Input_angle,
    output wire signed [15:0] Cos_out,
    output wire signed [15:0] Sin_out
);

    parameter STAGES = 16;
    
    wire [15:0] Reduced_angle;
    wire        cos_negate_pre;
    wire        sin_negate_pre;
    
    wire signed [15:0] cordic_x_out;
    wire signed [15:0] cordic_y_out;
    wire               cos_negate_out;
    wire               sin_negate_out;
    
    reg  signed [15:0] initial_x_reg;
    reg  signed [15:0] initial_y_reg;
    reg  signed [15:0] initial_z_reg;
    reg                initial_cos_negate_reg;
    reg                initial_sin_negate_reg;
    
    localparam signed [15:0] CORDIC_GAIN = 16'sh4DB9;

    pre_processing_unit PIPU (
        .Input_angle(Input_angle),
        .Reduced_angle(Reduced_angle),
        .Cos_negate(cos_negate_pre),
        .Sin_negate(sin_negate_pre)
    );

    always @(posedge Clk or negedge Reset) begin
        if (~Reset) begin
            initial_x_reg <= 16'b0;
            initial_y_reg <= 16'b0;
            initial_z_reg <= 16'b0;
            initial_cos_negate_reg <= 1'b0;
            initial_sin_negate_reg <= 1'b0;
        end
        else begin
            initial_x_reg <= CORDIC_GAIN;
            initial_y_reg <= 16'b0;
            initial_z_reg <= Reduced_angle;
            initial_cos_negate_reg <= cos_negate_pre;
            initial_sin_negate_reg <= sin_negate_pre;
        end
    end

    cordic_pipeline #(
        .STAGES(STAGES)
    ) CP (
        .Clk(Clk),
        .Reset(Reset),
        .Initial_x(initial_x_reg),
        .Initial_y(initial_y_reg),
        .Initial_z(initial_z_reg),
        .Initial_cos_negate(initial_cos_negate_reg),
        .Initial_sin_negate(initial_sin_negate_reg),
        .Final_cordic_x(cordic_x_out),
        .Final_cordic_y(cordic_y_out),
        .Final_cos_negate(cos_negate_out),
        .Final_sin_negate(sin_negate_out)
    );

    post_processing_unit POPU (
        .Cordic_x_in(cordic_x_out),
        .Cordic_y_in(cordic_y_out),
        .Cos_negate_in(cos_negate_out),
        .Sin_negate_in(sin_negate_out),
        .Cos(Cos_out),
        .Sin(Sin_out)
    );

endmodule
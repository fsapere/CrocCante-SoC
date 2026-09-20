module add_sub (
    input  wire               Clk,
    input  wire               Reset,
    input  wire signed [15:0] Input_a,
    input  wire signed [15:0] Input_b,
    input  wire               Enable,
    output reg  signed [15:0] Output_res
);

    reg signed [16:0] temp_res;

    always @(posedge Clk or negedge Reset) begin
        if (~Reset) begin
            Output_res <= 16'b0;
        end
        else begin
            
            if (Enable == 1'b0) begin
                temp_res = Input_a - Input_b;
            end
            else begin
                temp_res = Input_a + Input_b;
            end
            
            if (temp_res > 17'sd32767) begin
                Output_res <= 16'sd32767;
            end
            else if (temp_res < -17'sd32768) begin
                Output_res <= -16'sd32768;
            end
            else begin
                Output_res <= temp_res[15:0];
            end
            
        end
    end

endmodule
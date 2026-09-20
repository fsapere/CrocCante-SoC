module cordic_x (
    input  wire signed [15:0] X_i,
    input  wire signed [15:0] Shifted_y,
    input  wire               Enable,
    output reg  signed [15:0] Cordic_x
);

    reg signed [16:0] temp_x;

    always @(*) begin
        
        if (Enable == 1'b0) begin
            temp_x = X_i - Shifted_y;
        end
        else begin
            temp_x = X_i + Shifted_y;
        end
        
        if (temp_x > 17'sd32767) begin
            Cordic_x = 16'sd32767;
        end
        else if (temp_x < -17'sd32768) begin
            Cordic_x = -16'sd32768;
        end
        else begin
            Cordic_x = temp_x[15:0];
        end
        
    end

endmodule
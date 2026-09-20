module cordic_y (
    input  wire signed [15:0] Y_i,
    input  wire signed [15:0] Shifted_x,
    input  wire               Enable,
    output reg  signed [15:0] Cordic_y
);

    reg signed [16:0] temp_y;

    always @(*) begin
        
        if (Enable == 1'b0) begin
            temp_y = Y_i + Shifted_x;
        end
        else begin
            temp_y = Y_i - Shifted_x;
        end
        
        if (temp_y > 17'sd32767) begin
            Cordic_y = 16'sd32767;
        end
        else if (temp_y < -17'sd32768) begin
            Cordic_y = -16'sd32768;
        end
        else begin
            Cordic_y = temp_y[15:0];
        end
        
    end

endmodule
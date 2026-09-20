module rom (
    input  wire [3:0]  Address,
    output reg  [15:0] Data
);

    always @(*) begin
        case (Address)
            4'd0  : Data = 16'd12867;
            4'd1  : Data = 16'd7596;
            4'd2  : Data = 16'd4013;
            4'd3  : Data = 16'd2037;
            4'd4  : Data = 16'd1022;
            4'd5  : Data = 16'd511;
            4'd6  : Data = 16'd256;
            4'd7  : Data = 16'd128;
            4'd8  : Data = 16'd64;
            4'd9  : Data = 16'd32;
            4'd10 : Data = 16'd16;
            4'd11 : Data = 16'd8;
            4'd12 : Data = 16'd4;
            4'd13 : Data = 16'd2;
            4'd14 : Data = 16'd1;
            4'd15 : Data = 16'd1;
            default : Data = 16'd0;
        endcase
    end

endmodule
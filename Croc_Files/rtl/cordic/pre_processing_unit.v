module pre_processing_unit (
	input  wire [16:0] Input_angle,
	output reg  [15:0] Reduced_angle,
	output reg         Cos_negate,
	output reg         Sin_negate
);

	localparam [16:0] ANGLE_PI_2    = 17'h06488;
	localparam [16:0] ANGLE_PI      = 17'h0C910;
	localparam [16:0] ANGLE_PI_3_2  = 17'h12D98;
	localparam [16:0] ANGLE_TWO_PI  = 17'h19220;

	always @(*) begin
        
		if (Input_angle >= ANGLE_TWO_PI) begin
			Reduced_angle = Input_angle - ANGLE_TWO_PI;
		end
		else begin
			Reduced_angle = Input_angle[15:0];
		end

		if (Input_angle <= ANGLE_PI_2) begin
			Reduced_angle = Input_angle[15:0];
			Cos_negate = 1'b0;
			Sin_negate = 1'b0;
		end
		else if (Input_angle <= ANGLE_PI) begin
			Reduced_angle = ANGLE_PI - Input_angle;
			Cos_negate = 1'b1;
			Sin_negate = 1'b0;
		end
		else if (Input_angle <= ANGLE_PI_3_2) begin
			Reduced_angle = Input_angle - ANGLE_PI;
			Cos_negate = 1'b1;
			Sin_negate = 1'b1;
		end
		else begin
			Reduced_angle = ANGLE_TWO_PI - Input_angle;
			Cos_negate = 1'b0;
			Sin_negate = 1'b1;
		end
	end
endmodule

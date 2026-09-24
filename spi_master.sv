typedef enum logic [1:0] {
	IDLE 		= 2'b00,
	WAIT_START	= 2'b01,
	SHIFT 		= 2'b10,
	WAIT_END 	= 2'b11
}state_e;

module spi_master #(parameter A_WIDTH = 6, 
					parameter RD_D_WIDTH = 24, 
					parameter WR_D_WIDTH = 8, 
					parameter D_WIDTH = 32, 
					parameter CLK_DIV = 2, 
					parameter CPOL = 0,
					parameter SETUP_CYCLES = 1,
					parameter HOLD_CYCLES  = 1)
(
	// Control Signals
	input	wire	clk,					// 80 MHz
	input	wire	rst_n,
	// Design Time Inf Signals
	input	wire	start,
	input 	wire	[A_WIDTH - 1 : 0] addr,
	input	wire	rw,
	input 	wire 	auto_inc,
	input 	wire 	width_flag,						// 0 = 16, 1 = 32
	input 	wire 	[WR_D_WIDTH - 1 : 0] wr_data,
	output 	reg 	[RD_D_WIDTH - 1 : 0] rd_data,
	output  reg		done,
	output  wire    busy,	// Indiactes the TXN is under processed or can go for the nxt TXN
	// Physical Inf
	output	reg		sclk,
	output  reg		csb,
	output 	reg 	din,
	input 	wire 	dout
);
	// ENUM
	state_e state_ps, state_ns;
	// Internal registers
	reg  [D_WIDTH - 1 : 0] shift_reg;
	reg  [A_WIDTH - 1 : 0] edge_count, wait_count;	// Edge_Count for counting the sclk edges, wait_count - counter reg for WAIT_START || WAIT_END
	reg [$clog2(CLK_DIV) - 1 : 0] clk_div_count;	// For dividing the sys_clk to the sclk
	// WIres
	wire sclk_tick;									// for definig the sampling/driving with the help of sclk currently value
	wire [A_WIDTH - 1 : 0] target_wait;				// To assign the SETUP or HOLD wait cycles
	wire [$clog2(D_WIDTH) : 0] target_edge;			// To assign the 16 or 32 edges count
	/*-----------------------------------------------------------------------------*/
	
	assign target_wait = (state_ps == WAIT_START) ? SETUP_CYCLES : HOLD_CYCLES;
	assign target_edge = (width_flag) ? D_WIDTH : D_WIDTH >> 1;
 
	// CLock Division Logic ////////////////////////////////////////////////////////
	always_ff @ (posedge clk, negedge rst_n)
	begin
		if(!rst_n) begin
			clk_div_count <= 'd0;
			sclk 		  <= CPOL;
		end
		else begin 
			if(state_ps == SHIFT) begin
				if(clk_div_count == CLK_DIV - 1) begin
					clk_div_count <= 'd0;
					sclk 		  <= ~sclk;
				end
				else
					clk_div_count <= clk_div_count + 1;
			end
			else begin
				clk_div_count	  <= 'd0;
				sclk  			  <= CPOL;
			end
		end
	end

	assign sclk_tick = (state_ps == SHIFT) && (clk_div_count == CLK_DIV - 1);
	////////////////////////////////////////////////////////////////////////////////

	// WAIT_COUNTER ///////////////////////////////////////////////////////////////
	always_ff @ (posedge clk or negedge rst_n)
	begin
		if(!rst_n)
			wait_count <= 'd0;
		else if(state_ps == WAIT_START || state_ps == WAIT_END) begin
			if(wait_count == target_wait - 1)
				wait_count <= 'd0;
			else
				wait_count <= wait_count + 1;
		end
		else
			wait_count <= 'd0;
	end
	////////////////////////////////////////////////////////////////////////////////

	// SHIFTING ///////////////////////////////////////////////////////////////////
		always_ff @ (posedge clk , negedge rst_n)
		begin
			if(!rst_n) begin
				edge_count	<=	'd0;
				shift_reg 	<=	'd0;
				din 		<=	1'b0;
			end
			else if(state_ps == IDLE && start) begin
				shift_reg	<=	{auto_inc, rw, addr, (rw ? wr_data : 8'd0), 16'd0};
				din 		<=	auto_inc;
			end
			else if (state_ps == SHIFT) begin
				if(sclk_tick && sclk) 						// FALLING EDGE - Driving the DIN a bit to the SLAVE TDC7200
					din 	  <= shift_reg[D_WIDTH - 1];
				else if(sclk_tick && !sclk) begin 			// RISING EDGE - Sampling the bit from SLAVE TDC7200 through DOUT
					shift_reg  <= {shift_reg[D_WIDTH - 2 : 0], dout};
					if(edge_count == target_edge - 1)
						edge_count <= 'd0;
					else
						edge_count <= edge_count + 1;
				end
			end
		end
	////////////////////////////////////////////////////////////////////////////////

	// State Register Logic
	always_ff @(posedge clk or negedge rst_n)
	begin
		if(!rst_n)
			state_ps	<=	IDLE;
		else
			state_ps	<=	state_ns;
	end

	// State Transfer Logic
	always_comb begin
		csb = 1'b1;
		state_ns = state_ps;
		case(state_ps)
			IDLE : state_ns = (start) ? WAIT_START : IDLE;
			WAIT_START : begin
				csb = 1'b0;
				state_ns = (wait_count == target_wait - 1) ? SHIFT : WAIT_START;
			end
			SHIFT : begin
				csb      = 1'b0;
				state_ns = (edge_count == target_edge - 1) ? WAIT_END : SHIFT;
			end
			WAIT_END : begin
				csb = 1'b0;
				if(wait_count == target_wait - 1) begin
					csb = 1'b1;
					state_ns = IDLE;
				end
				else begin
					state_ns = WAIT_END;
				end
			end
			default : state_ns = IDLE;
		endcase
	end

	// Output Logic
	always_ff @ (posedge clk, negedge rst_n)
	begin
		if(!rst_n) begin
			rd_data 	<=	'd0;
			done		<=	1'b0;
		end
		else begin
			if(state_ps == WAIT_END && wait_count == target_wait - 1) begin
				rd_data		<=	shift_reg[RD_D_WIDTH - 1 : 0];
				done		<=	1'b1;
			end
			else
				done		<=	1'b0;
		end
	end

	assign busy = (state_ps != IDLE);

endmodule : spi_master
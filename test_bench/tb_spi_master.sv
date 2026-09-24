`include "E:/Trinath_Kella/modules/spi_master/spi_master.sv"

module tb_spi_master;

	parameter A_WIDTH = 6;
	parameter RD_D_WIDTH = 24; 
	parameter WR_D_WIDTH = 8;
	parameter D_WIDTH = 32;
	parameter CLK_DIV = 2;
	parameter CPOL = 0;
	parameter SETUP_CYCLES = 1;
	parameter HOLD_CYCLES  = 1;

	reg clk, rst_n;
	reg start, rw, auto_inc, width_flag;
	reg  [A_WIDTH - 1 : 0] addr;
	reg  [WR_D_WIDTH - 1 : 0] wr_data;
	wire [RD_D_WIDTH - 1 : 0] rd_data;
	wire done, busy;

	// Physical Interface Pins
	wire sclk, csb, din;
	reg  dout;

	// Expected Result
	reg [(2 * WR_D_WIDTH) - 1 : 0] expected_val;
	reg din_exp;

	reg [A_WIDTH - 2 : 0] cntr;

	spi_master #(.A_WIDTH(A_WIDTH), .RD_D_WIDTH(RD_D_WIDTH),
				 .WR_D_WIDTH(WR_D_WIDTH), .D_WIDTH(D_WIDTH),
				 .CLK_DIV(CLK_DIV), .CPOL(CPOL), .SETUP_CYCLES(SETUP_CYCLES),
				 .HOLD_CYCLES(HOLD_CYCLES))
	dut
	(
		.clk       (clk),
		.rst_n     (rst_n),
		.start     (start),
		.addr      (addr),
		.rw        (rw),
		.auto_inc  (auto_inc),
		.width_flag(width_flag),
		.wr_data   (wr_data),
		.rd_data   (rd_data),
		.done      (done),
		.busy      (busy),
		// Physical Interface Pins
		.sclk      (sclk),
		.csb       (csb),
		.din       (din),
		.dout      (dout)
	);

	// Clock - 80 MHz
	always #6.25 clk = !clk;
	initial clk = 0;

	always @ (posedge sclk) begin
		if (!csb) begin
			if (expected_val[((2 * WR_D_WIDTH) - 1) - cntr] == din)
				$display("[%0t] PASS: bit %0d - expected=%b actual(din)=%b",
				          $time, cntr, expected_val[((2*WR_D_WIDTH)-1)-cntr], din);
			else
				$display("[%0t] FAIL: bit %0d - expected=%b actual(din)=%b",
				          $time, cntr, expected_val[((2*WR_D_WIDTH)-1)-cntr], din);

			cntr <= cntr + 1;
		end
	end

	// Test Bench
	initial begin
	    width_flag = 1'b0;
	    // Driving the addr, rw, auto_inc, wr_data (before start asserts because we can remove the ambiguity of the start reading the older values of these)
		addr = 6'b000000; rw = 1'b1; auto_inc = 1'b0; wr_data = 8'hA5;
		
		expected_val = {auto_inc, rw, addr, wr_data};
		start = 0;
		din_exp = expected_val[15];
		dout = 1'b0;
		rst_n = 1'b0;
		cntr  = 1'b0;
		repeat(2) @(posedge clk);
		rst_n = 1'b1;
		
		// Start Signal Stimulus
		start = 1'b0;
		repeat(5) @(posedge clk);
		start = 1'b1;
		repeat(1) @(posedge clk);
		start = 1'b0;

		wait(done);
		repeat(5) @(posedge clk);

		$finish;
	end

endmodule : tb_spi_master
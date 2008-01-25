`default_nettype none

// ====================================================================
//                         VECTOR-06C FPGA REPLICA
//
// 					Copyright (C) 2007, Viacheslav Slavinsky
//
// This core is distributed under modified BSD license. 
// For complete licensing information see LICENSE.TXT.
// -------------------------------------------------------------------- 
//
// An open implementation of Vector-06C home computer
//
// Author: Viacheslav Slavinsky, http://sensi.org/~svo
// 
// Design File: floppy.v
//
// Floppy drive emulation toplevel
//
// --------------------------------------------------------------------

module floppy(
	clk, ce, reset_n, 
	// sram interface (reserved)
	addr, idata, odata, memwr, 
	// sd card signals
	sd_dat, sd_dat3, sd_cmd, sd_clk, 
	// uart comms
	uart_txd, 
	
	// io ports
	hostio_addr,
	hostio_idata,
	hostio_odata,
	hostio_rd,
	hostio_wr,
	
	// keyboard input for osd menu
	keyboard_keys,
	
	// screen memory
	display_addr,
	display_data,
	display_wren,
	
	// debug 
	green_leds, red_leds, debug, debugidata);
	
parameter IOBASE = 16'hE000;
parameter PORT_MMCA= 0;
parameter PORT_SPDR= 1;
parameter PORT_SPSR= 2;
parameter PORT_JOY = 3;
parameter PORT_TXD = 4;
parameter PORT_RXD = 5;
parameter PORT_CTL = 6;

parameter PORT_TMR1 = 7;
parameter PORT_TMR2 = 8;

parameter PORT_CPU_REQUEST	= 9;
parameter PORT_CPU_STATUS	= 10;
parameter PORT_TRACK		= 11;
parameter PORT_SECTOR		= 12;

parameter PORT_LED = 16;

input			clk;
input			ce;
input			reset_n;
output	[15:0]	addr = cpu_a;
input	[7:0]	idata;
output	[7:0]	odata = cpu_do;
output			memwr;
input			sd_dat;
output	reg		sd_dat3;
output			sd_cmd;
output			sd_clk;
output			uart_txd;

// I/O interface to host system (Vector)
input	[2:0]	hostio_addr;
input	[7:0]	hostio_idata;
output  [7:0]	hostio_odata;
input			hostio_rd;
input			hostio_wr;

// keyboard interface
input	[5:0]	keyboard_keys;	// {reserved,left,right,up,down,enter}

// screen memory
output	[7:0]	display_addr;
output 	[7:0]	display_data;
output			display_wren;


output reg[7:0]	green_leds;
output  [7:0]	red_leds = cpu_di;
output	[7:0]	debug = {ce & bufmem_en, ce, hostio_rd, wd_ram_rd};//wdport_status;
output	[7:0]	debugidata = {timer1q};

wire [15:0] cpu_a;
wire [7:0]	cpu_di;
wire [7:0]	cpu_do;

cpu65xx_en cpu(
		.clk(clk),
		.reset(~reset_n),
		.enable(ce & ~(wd_ram_rd|wd_ram_wr)),
		.nmi_n(1'b1),
		.irq_n(1'b1),
		.di(cpu_di),
		.do(cpu_do),
		.addr(cpu_a),
		.we(memwr)
	);


wire [7:0]  ram_do;
wire [7:0] 	lowmem_do;
wire [7:0]	bufmem_do;
reg  [7:0]	ioports_do;

assign cpu_di = &cpu_a[15:4] ? (cpu_a[0] ? 8'h08:8'h00) // boot addr
							: lowmem_en ? lowmem_do :
							  bufmem_en ? bufmem_do :
							  rammem_en ? ram_do : ioports_do;

wire lowmem_en = |cpu_a[15:9] == 0;
wire bufmem_en = (wd_ram_rd|wd_ram_wr) || (cpu_a >= 16'h200 && cpu_a < 16'h600);
//wire rammem_en = cpu_a >= 16'h0800 && cpu_a < 16'h0800 + 32768;
wire rammem_en = cpu_a >= 16'h0800 && cpu_a < 16'h8000;
wire ioports_en= cpu_a >= IOBASE && cpu_a < IOBASE + 256;
wire osd_en = cpu_a >= IOBASE + 256 && cpu_a < IOBASE + 512;

assign display_addr = cpu_a[7:0];
assign display_data = cpu_do;
assign display_wren = osd_en & memwr;


floppyram flopramnik(
	.address(cpu_a-16'h0800),
	//.inclocken(ce & rammem_en),
	.clock(~clk),
	.data(cpu_do),
	.wren(memwr),
	.q(ram_do)
	);

ram512x8a zeropa(
	.clock(~clk),
	.clken(ce & lowmem_en),
	.address(cpu_a),
	.wren(memwr),
	.data(cpu_do),
	.q(lowmem_do));


wire [9:0]	bufmem_addr = (wd_ram_rd|wd_ram_wr) ? wd_ram_addr : cpu_a - 16'h200;
wire 		bufmem_wren = wd_ram_wr | memwr;
wire [7:0]	bufmem_di = wd_ram_wr ? wd_ram_odata : cpu_do;

ram1024x8a bufpa(
	.clock(~clk),
	.clken(ce & bufmem_en),
	.address(bufmem_addr),
	.wren(bufmem_wren),
	.data(bufmem_di),
	.q(bufmem_do));

/////////////////////
// CPU INPUT PORTS //
/////////////////////
always @(negedge clk) begin
	case (cpu_a)		 
	IOBASE+PORT_CTL:	ioports_do <= {7'b0,uart_busy};	// uart status
	IOBASE+PORT_TMR1:	ioports_do <= timer1q;
	IOBASE+PORT_TMR2:	ioports_do <= timer2q;
	IOBASE+PORT_SPDR:	ioports_do <= spdr_do;
	IOBASE+PORT_SPSR:	ioports_do <= {7'b0,~spdr_dsr};
	IOBASE+PORT_CPU_REQUEST:
						ioports_do <= wdport_cpu_request;
	IOBASE+PORT_TRACK:	ioports_do <= wdport_track;
	IOBASE+PORT_SECTOR:	ioports_do <= wdport_sector;
	
	IOBASE+PORT_JOY:	ioports_do <= keyboard_keys;
	default:			ioports_do <= 8'hFF;
	endcase
end

/////////////////////
// CPU OUTPUT PORTS //
/////////////////////
always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		green_leds <= 0;
		uart_state <= 3;
		uart_send <= 0;
		sd_dat3 <= 1;
	end else begin
		if (ce) begin
			if (memwr && cpu_a == 16'hE010) begin
				green_leds <= cpu_do;
			end
			
			// E004: send data
			if (memwr && cpu_a == IOBASE+PORT_TXD) begin
				uart_data <= cpu_do;
				uart_state <= 0;
			end
			
			// MMCA: SD/MMC card chip select
			if (memwr && cpu_a == IOBASE+PORT_MMCA) begin
				sd_dat3 <= cpu_do[0];
			end
			
			// CPU status return
			if (memwr && cpu_a == IOBASE+PORT_CPU_STATUS) begin
				wdport_cpu_status <= cpu_do;
			end
			
			// uart state machine
			case (uart_state) 
			0:	begin
					if (~uart_busy) begin
						uart_send <= 1;
						uart_state <= 1;
					end
				end
			1:	begin
					if (uart_busy) begin
						uart_send <= 0;
						uart_state <= 2;
					end
				end
			2:	begin
					if (~uart_busy) begin
						uart_data <= uart_data + 1;
						if (uart_data == 65+27) uart_data <= 65;
						uart_state <= 3;
					end
				end
			3:	begin
				end
			endcase		
		end
	end
end


reg uart_send;
reg [7:0] uart_data;
wire uart_busy;
reg [1:0] uart_state = 3;

TXD txda( 
	.clk(clk),
	.ld(uart_send),
	.data(uart_data),
	.TxD(uart_txd),
	.txbusy(uart_busy)
   );

////////////
// TIMERS //
////////////

wire [7:0] timer1q;
wire [7:0] timer2q;

timer100hz timer1(.clk(clk), .di(cpu_do), .wren(ce && cpu_a==(IOBASE+PORT_TMR1) && memwr), .q(timer1q));
timer100hz timer2(.clk(clk), .di(cpu_do), .wren(ce && cpu_a==(IOBASE+PORT_TMR2) && memwr), .q(timer2q));

//////////////////////
// SPI/SD INTERFACE //
//////////////////////

wire [7:0] 	spdr_do;
wire		spdr_dsr;

spi sd0(.clk(clk),
		.ce(1'b1),
		.reset_n(reset_n),
		.mosi(sd_cmd),
		.miso(sd_dat),
		.sck(sd_clk),
		.di(cpu_do), 
		.wr(ce && cpu_a == (IOBASE+PORT_SPDR) && memwr), 
		.do(spdr_do), 
		.dsr(spdr_dsr)
		);


////////////
// WD1793 //
////////////

// here's how 1793's registers are mapped in Vector-06c
// 00011xxx
//      000		$18 	Data
//	    001		$19 	Sector
//		010		$1A		Track
//		011		$1B		Command/Status
//		100		$1C		Control				Write only

wire [7:0]	wdport_track;
wire [7:0]  wdport_sector;
wire [7:0]	wdport_status;
wire [7:0]	wdport_cpu_request;
reg	 [7:0]	wdport_cpu_status;

wire [9:0]	wd_ram_addr;
wire 		wd_ram_rd;
wire		wd_ram_wr;	
wire [7:0]	wd_ram_odata;	// this is to write to ram


wd1793 vg93(
				.clk(clk), 
				.clken(ce), 
				.reset_n(reset_n),
				
				// host i/o ports 
				.rd(hostio_rd), 
				.wr(hostio_wr), 
				.addr(hostio_addr), 
				.idata(hostio_idata), 
				.odata(hostio_odata), 

				// memory buffer interface
				.buff_addr(wd_ram_addr), 
				.buff_rd(wd_ram_rd), 
				.buff_wr(wd_ram_wr), 
				.buff_idata(bufmem_do), 	// data read from ram
				.buff_odata(wd_ram_odata), 	// data to write to ram
				
				// workhorse interface
				.oTRACK(wdport_track),
				.oSECTOR(wdport_sector),
				.oSTATUS(wdport_status),
				.oCPU_REQUEST(wdport_cpu_request),
				.iCPU_STATUS(wdport_cpu_status)
				);
endmodule


module ram512x8_a(clk, ce, addr, wren, di, q);
input clk, ce;
input [8:0] addr;
input 		wren;
input [7:0]	di;
output[7:0]	q;

	altsyncram	altsyncram_component (
				.wren_a (wren),
				.clock0 (clk),
				.address_a(addr),
				.data_a (di),
				.q_a (q),
				.aclr0 (1'b0),
				.aclr1 (1'b0),
				.address_b (1'b1),
				.addressstall_a (1'b0),
				.addressstall_b (1'b0),
				.byteena_a (1'b1),
				.byteena_b (1'b1),
				.clock1 (1'b1),
				.clocken0 (1'b1),
				.clocken1 (1'b1),
				.clocken2 (1'b1),
				.clocken3 (1'b1),
				.data_b (1'b1),
				.eccstatus (),
				.q_b (),
				.rden_a (1'b1),
				.rden_b (1'b1),
				.wren_b (1'b0));
	defparam
		altsyncram_component.clock_enable_input_a = "BYPASS",
		altsyncram_component.clock_enable_output_a = "BYPASS",
		altsyncram_component.intended_device_family = "Cyclone II",
		altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = 512,
		altsyncram_component.operation_mode = "SINGLE_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "TRUE",
		altsyncram_component.widthad_a = 9,
		altsyncram_component.width_a = 8,
		altsyncram_component.width_byteena_a = 1;


endmodule

// lower memory:
// 	0000 zeropage  
// 	0100 stack				___ lowmem1
// 	0200 buffer
// 	0600 <end of lowmem> 	___ lowmem2
module ram512x8(clk, ce, addr, wren, di, q);
input clk, ce;
input [8:0] addr;
input 		wren;
input [7:0]	di;
output[7:0]	q = ram[addr];

reg [7:0] ram[511:0];

always @(posedge clk) begin
	if (ce) begin
		if (wren) begin
			ram[addr] <= di;
		end 
	end
end

endmodule

// Mode definitions
`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module sine_reader(
    input clk,
    input reset,
    input [1:0] mode,
    input [19:0] step_size,
    input generate_next,

    output sample_ready,
    output [15:0] sample
);

    wire [21:0] next_addr;
    wire [21:0] addr;
    wire [15:0] raw_output;
    
    // Address register (updates 1 cycle after generate_next)
    dffre #(22) addr_dff(
        .clk(clk),
        .r(reset),
        .en(generate_next),
        .d(next_addr),
        .q(addr)
    );
    
    assign next_addr = (mode == `REWIND) ? addr - {2'd0, step_size}:
                       (mode == `FAST_FORWARD) ? addr + {2'd0, step_size} + {2'd0, step_size} :
                                                 addr + {2'd0, step_size};
    
    // 2-Cycle Delay for sample_ready
    // Cycle 1: addr updates
    // Cycle 2: ROM outputs valid data
    wire almost_ready;
    dffr #(1) ready_dff1(
        .clk(clk),
        .r(reset),
        .d(generate_next),
        .q(almost_ready)
    );
    dffr #(1) ready_dff2(
        .clk(clk),
        .r(reset),
        .d(almost_ready),
        .q(sample_ready)
    );
    
    wire [9:0] raw_addr = addr[19:10];
    wire [1:0] quadrant = addr[21:20];
    wire [9:0] rom_addr = quadrant[0] ? (1023 - raw_addr) : raw_addr;
    
    // Unconditional 1-Cycle Delay for the Quadrant
    // By removing the enable, quadrant_delayed will always be exactly
    // 1 clock cycle behind quadrant, perfectly syncing with the ROM.
    wire [1:0] quadrant_delayed;
    dff #(2) quadrant_dff(
        .clk(clk),
        .d(quadrant),        
        .q(quadrant_delayed) 
    );
    
    sine_rom sine_rom(
        .clk(clk),
        .addr(rom_addr),
        .dout(raw_output)
    );
    
    // Uses the delayed quadrant to determine the sign of the delayed ROM output
    assign sample = quadrant_delayed[1] ? (16'b0 - raw_output) : raw_output;

endmodule
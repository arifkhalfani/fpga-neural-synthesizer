`define SONG_WIDTH          7
`define NOTE_WIDTH          6
`define DURATION_WIDTH      6
`define HARMONIC_WIDTH      3
`define INSTRUCTION_WIDTH   16
`define NUM_NOTE_PLAYERS    4
`define MAX_NOTE_IN_SONG    7'd127

`define SWIDTH 3
`define PAUSED              3'b000
`define FETCH               3'b001
`define DECODE              3'b010
`define WAIT                3'b011
`define INCREMENT_ADDRESS   3'b100

`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module song_reader_tb();

    reg clk, reset, play;
    reg [1:0] song;
    reg [1:0] mode;
    
    wire beat;
    wire song_done;
    
    reg note_done_0, note_done_1, note_done_2, note_done_3;
    
    wire [5:0] note_0, duration_0;
    wire [2:0] harmonic_0;
    wire new_note_0;
    
    wire [5:0] note_1, duration_1;
    wire [2:0] harmonic_1;
    wire new_note_1;
    
    wire [5:0] note_2, duration_2;
    wire [2:0] harmonic_2;
    wire new_note_2;
    
    wire [5:0] note_3, duration_3;
    wire [2:0] harmonic_3;
    wire new_note_3;

    song_reader sr(
        .clk(clk),
        .reset(reset),
        .play(play),
        .beat(beat),
        .song(song),
        .mode(mode),
        .song_done(song_done),
        
        .note_done_0(note_done_0), .note_0(note_0), .duration_0(duration_0), .harmonic_0(harmonic_0), .new_note_0(new_note_0),
        .note_done_1(note_done_1), .note_1(note_1), .duration_1(duration_1), .harmonic_1(harmonic_1), .new_note_1(new_note_1),
        .note_done_2(note_done_2), .note_2(note_2), .duration_2(duration_2), .harmonic_2(harmonic_2), .new_note_2(new_note_2),
        .note_done_3(note_done_3), .note_3(note_3), .duration_3(duration_3), .harmonic_3(harmonic_3), .new_note_3(new_note_3)
    );
    
    // Beat pulses high for 1 clock cycle every 4 cycles
    beat_generator #(.WIDTH(17), .STOP(4)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .beat(beat)
    );

    reg expected_done;
    reg errors;

    // Clock and reset
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        repeat (4) #5 clk = ~clk;
        reset = 1'b0;
        forever #5 clk = ~clk;
    end

    // Tests
    initial begin
        play = 0;
        song = 0;
        mode = `NORMAL;
        note_done_0 = 1; note_done_1 = 1; note_done_2 = 1; note_done_3 = 1;
        errors = 0;

        // Align to negedge to prevent race conditions
        @(negedge clk);
        reset = 1;
        repeat (4) @(negedge clk); 
        reset = 0;

        $display("1. Single note scheduling");
        play = 1;
        
        // FETCH(0) -> DECODE -> INC -> FETCH(1) -> DECODE
        repeat (5) @(negedge clk); 
        
        expected_done = 1;
        $display ("new_note_0 = %d, expected = %d", new_note_0, expected_done);
        if (new_note_0 !== 1'b1) begin
            errors = 1'b1;
            $display ("Error at test 1");
        end
        $display();

        // Set player 0 to busy so the arbiter routes the next chord to 1, 2, 3
        note_done_0 = 0;

        $display("2. Chord scheduling (Arbiter test)");
        
        // FIX: Step forward 1 cycle to exit Test 1's DECODE state!
        @(negedge clk); 
        
        // Now step the clock forward until the FSM lands on the *next* Wait instruction
        while (!(sr.state == `DECODE && sr.opcode == 1'b1)) begin
            @(negedge clk);
        end
        
        $display ("new_note_1 = %d, expected = %d", new_note_1, expected_done);
        if (new_note_1 !== 1'b1) begin
            errors = 1'b1;
            $display ("Error at test 2 (new_note_1)");
        end

        $display ("new_note_2 = %d, expected = %d", new_note_2, expected_done);
        if (new_note_2 !== 1'b1) begin
            errors = 1'b1;
            $display ("Error at test 2 (new_note_2)");
        end
        $display();
        
        // Make all players busy to test dropped notes
        note_done_1 = 0; note_done_2 = 0; note_done_3 = 0;

        $display("3. Arbiter full / dropped note");
        
        // Step forward 1 cycle to exit the current DECODE state
        @(negedge clk); 
        
        // Step the clock forward until we hit the next Wait instruction
        while (!(sr.state == `DECODE && sr.opcode == 1'b1)) begin
            @(negedge clk);
        end
        
        expected_done = 0;
        $display ("new_note_0 = %d, expected = %d", new_note_0, expected_done);
        if (new_note_0 !== 1'b0) begin
            errors = 1'b1;
            $display ("Error at test 3");
        end
        $display();
        
        $display("4. Rewind Underflow");
        // Reset to go back to address 0
        reset = 1;
        repeat (4) @(negedge clk);
        reset = 0;
        mode = `REWIND;
        
        // Wait exactly 3 cycles to hit the INCREMENT_ADDRESS state
        repeat (3) @(negedge clk); 
        
        expected_done = 1;
        $display ("song_done (underflow) = %d, expected = %d", song_done, expected_done);
        if (song_done !== 1'b1) begin
            errors = 1'b1;
            $display ("Error at test 4");
        end
        $display();

        $display("5. Normal Overflow");
        // The address just wrapped backward to 127. 
        // We must wait 1 clock cycle for the register to actually capture 127!
        @(negedge clk);
        mode = `NORMAL;
        
        // Advance: 127 + 1 = 0 (Overflow)
        // Wait exactly 2 cycles to hit the INCREMENT_ADDRESS state again
        repeat (2) @(negedge clk);
        
        $display ("song_done (overflow) = %d, expected = %d", song_done, expected_done);
        if (song_done !== 1'b1) begin
            errors = 1'b1;
            $display ("Error at test 5");
        end
        $display();

        if (errors == 1'b0) begin
            $display ("No errors! Perfect scheduling.");
        end
        
        $finish;
    end
endmodule


// ------------------------------------------------------------------
// Mock Song ROM 
// Format: {opcode(1), note/duration(6), duration(6), harmonic(3)}
// ------------------------------------------------------------------
module song_rom(
    input clk,
    input [8:0] addr,
    output reg [15:0] dout
);
    // Simulates a 1-cycle latency Block RAM
    always @(posedge clk) begin
        case(addr[6:0])
            7'd0:   dout <= {1'b0, 6'd10, 6'd5, 3'd1}; // note 1
            7'd1:   dout <= {1'b1, 6'd2,  9'd0};       // wait 2
            
            7'd2:   dout <= {1'b0, 6'd20, 6'd5, 3'd2}; // chord 1
            7'd3:   dout <= {1'b0, 6'd21, 6'd5, 3'd2}; // chord 2
            7'd4:   dout <= {1'b0, 6'd22, 6'd5, 3'd2}; // chord 3
            7'd5:   dout <= {1'b1, 6'd3,  9'd0};       // wait 3
            
            7'd6:   dout <= {1'b0, 6'd30, 6'd5, 3'd3}; // dropped note
            7'd7:   dout <= {1'b1, 6'd1,  9'd0};       // wait 1
            
            7'd127: dout <= {1'b0, 6'd10, 6'd5, 3'd1}; // note for overflow test
            default: dout <= 16'b0;
        endcase
    end
endmodule
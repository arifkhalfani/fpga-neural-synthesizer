`define SONG_WIDTH          7
`define NOTE_WIDTH          6
`define DURATION_WIDTH      6
`define HARMONIC_WIDTH      3
`define INSTRUCTION_WIDTH   16
`define NUM_NOTE_PLAYERS    4
`define MAX_NOTE_IN_SONG    7'd127

// ----------------------------------------------
// Define State Assignments
// ----------------------------------------------
`define SWIDTH 3
`define PAUSED              3'b000
`define FETCH               3'b001
`define DECODE              3'b010
`define WAIT                3'b011
`define INCREMENT_ADDRESS   3'b100

// Mode definitions
`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module song_reader(
    input clk,
    input reset,
    input play,
    input beat,
    input [1:0] song,
    input [1:0] mode,
    output wire song_done, 
    
    input note_done_0,  
    output wire [5:0] note_0,       
    output wire [5:0] duration_0,
    output wire [2:0]  harmonic_0,   
    output wire new_note_0,
    
    input note_done_1,   
    output wire [5:0] note_1,       
    output wire [5:0] duration_1,
    output wire [2:0]  harmonic_1,   
    output wire new_note_1,  
    
    input note_done_2, 
    output wire [5:0] note_2,       
    output wire [5:0] duration_2,
    output wire [2:0]  harmonic_2,   
    output wire new_note_2,  
    
    input note_done_3,
    output wire [5:0] note_3,       
    output wire [5:0] duration_3,
    output wire [2:0]  harmonic_3,   
    output wire new_note_3
);

    // Only use this module when mode is not GENERATE, else use generate_reader
    wire play_enable = play & (mode != `GENERATE);

    wire [`SWIDTH-1:0] state;
    reg  [`SWIDTH-1:0] next_state;
    
    dffr #(`SWIDTH) fsm (
        .clk(clk),
        .r(reset),
        .d(next_state),
        .q(state)
    );
    
    wire [`SONG_WIDTH-1:0] curr_note_num, next_note_num;
    wire [`INSTRUCTION_WIDTH-1:0] instruction;
    wire [`SONG_WIDTH + 1:0] rom_addr = {song, curr_note_num};
    
    // For identifying when we reach the end of a song
    wire overflow;
    wire underflow;     // Case for rewind
    
    dffr #(.WIDTH(`SONG_WIDTH)) note_counter (
        .clk(clk),
        .r(reset),
        .d(next_note_num),
        .q(curr_note_num)
    );

    song_rom rom(.clk(clk), .addr(rom_addr), .dout(instruction));
    
    wire opcode = instruction[15];
    wire [5:0] note = instruction[14:9];
    wire [5:0] duration = opcode ? instruction[14:9] : instruction[8:3];
    wire [2:0] harmonic = instruction[2:0];
    
    // In DECODE, assign instructions to note_players
    wire [3:0] note_done = {note_done_3, note_done_2, note_done_1, note_done_0};
    
    reg [3:0] sel_current; // One-hot
    wire [3:0] in_queue;   // note_players that have queued notes, unusable for now
    
    wire [3:0] free_players = note_done & ~in_queue;
    
    always @(*) begin   // Arbiter
        if      (free_players[0]) sel_current = 4'b0001; // Player 0 is free
        else if (free_players[1]) sel_current = 4'b0010; // Player 1 is free
        else if (free_players[2]) sel_current = 4'b0100; // Player 2 is free
        else if (free_players[3]) sel_current = 4'b1000; // Player 3 is free
        else                      sel_current = 4'b0000; // All busy, drop the note.
    end
        
    dffre #(.WIDTH(`NUM_NOTE_PLAYERS)) in_queue_ff (
        .clk(clk),
        .r(reset | (state == `WAIT)), // Reset when chord starts playing
        .en(!opcode & (state == `DECODE) & (sel_current != 0)),
        .d(sel_current | in_queue),
        .q(in_queue)
    );
    
    // Queue the notes to the players
    dffre #(.WIDTH(`NOTE_WIDTH + `DURATION_WIDTH + `HARMONIC_WIDTH)) note_player_0_ff (
        .clk(clk),
        .r(reset),    
        .en(sel_current[0] & !opcode & (state == `DECODE)),
        .d({note, duration, harmonic}),
        .q({note_0, duration_0, harmonic_0})
    );
    dffre #(.WIDTH(`NOTE_WIDTH + `DURATION_WIDTH + `HARMONIC_WIDTH)) note_player_1_ff (
        .clk(clk),
        .r(reset),    
        .en(sel_current[1] & !opcode & (state == `DECODE)),
        .d({note, duration, harmonic}),
        .q({note_1, duration_1, harmonic_1})
    );
    dffre #(.WIDTH(`NOTE_WIDTH + `DURATION_WIDTH + `HARMONIC_WIDTH)) note_player_2_ff (
        .clk(clk),
        .r(reset),    
        .en(sel_current[2] & !opcode & (state == `DECODE)),
        .d({note, duration, harmonic}),
        .q({note_2, duration_2, harmonic_2})
    );
    dffre #(.WIDTH(`NOTE_WIDTH + `DURATION_WIDTH + `HARMONIC_WIDTH)) note_player_3_ff (
        .clk(clk),
        .r(reset),    
        .en(sel_current[3] & !opcode & (state == `DECODE)),
        .d({note, duration, harmonic}),
        .q({note_3, duration_3, harmonic_3})
    );
    
    // Only fire new_note when opcode = 1
    assign {new_note_3, new_note_2, new_note_1, new_note_0} = 
                            (opcode && state == `DECODE) ? in_queue : 4'b0000;
 
    // wait_counter to advance time in state WAIT
    wire [`DURATION_WIDTH-1:0] wait_counter, next_wait_counter;
    
    dffre #(.WIDTH(`DURATION_WIDTH)) wait_counter_ff (
        .clk(clk),
        .r(reset),
        .en((state == `DECODE && opcode) || (beat && state == `WAIT)),
        .d(next_wait_counter),
        .q(wait_counter)
    ); 
    
    // Halve the duration for Fast Forward, but ensure we never load a 0 to prevent underflow
    wire [5:0] fast_duration = (duration > 1) ? {1'b0, duration[5:1]} : duration;
    wire [5:0] actual_duration = (mode == 2'b11) ? fast_duration : duration;

    // Use the actual_duration to load the counter
    assign next_wait_counter = (state == `DECODE) ? actual_duration - 6'b1 : 
                               (beat && wait_counter != 6'b0) ? wait_counter - 6'b1 : 
                               wait_counter;

    always @(*) begin
        case (state)
            `PAUSED : next_state = play_enable ? `FETCH : `PAUSED;
            `FETCH  : next_state = play_enable ? `DECODE : `PAUSED;
            `DECODE : next_state = !play_enable ? `PAUSED :
                                   opcode ? `WAIT : `INCREMENT_ADDRESS;
            `WAIT : next_state = !play_enable ? `PAUSED :
                                 (wait_counter == 6'b0) ? `INCREMENT_ADDRESS : `WAIT;
            `INCREMENT_ADDRESS : next_state = play_enable ? `FETCH : `PAUSED;                                                       
            default : next_state = `PAUSED;
        endcase
    end
                                                           
    assign overflow = (mode != `REWIND) & (state == `INCREMENT_ADDRESS) & (curr_note_num == `MAX_NOTE_IN_SONG);
    assign underflow = (mode == `REWIND) & (state == `INCREMENT_ADDRESS) & (curr_note_num == 7'b0);                                                     
    assign song_done = overflow || underflow;
    
    assign next_note_num = (state != `INCREMENT_ADDRESS) ? curr_note_num     :
                           overflow                      ? 7'b0              :
                           underflow                     ? `MAX_NOTE_IN_SONG :   
                           (mode != `REWIND)             ? curr_note_num + 1 :
                                                           curr_note_num - 1;

endmodule
`define SONG_WIDTH 7
`define NOTE_WIDTH 6
`define DURATION_WIDTH 6
`define HARMONIC_WIDTH 3

// ----------------------------------------------
// Define State Assignments
// ----------------------------------------------
`define SWIDTH 3
`define PAUSED             3'b000
`define WAIT               3'b001
`define INCREMENT_ADDRESS  3'b010
`define RETRIEVE_NOTE      3'b011
`define NEW_NOTE_READY     3'b100


module song_reader(
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input [1:0] mode,
    output wire song_done, 
    
    input note_done_0,  
    output wire [5:0] note_0,       
    output wire [5:0] duration_0,
    output wire [1:0]  harmonic_0,   
    output wire new_note_0,
    
    input note_done_1,   
    output wire [5:0] note_1,       
    output wire [5:0] duration_1,
    output wire [1:0]  harmonic_1,   
    output wire new_note_1,  
    
    input note_done_2, 
    output wire [5:0] note_2,       
    output wire [5:0] duration_2,
    output wire [1:0]  harmonic_2,   
    output wire new_note_2,  
    
    input note_done_3,
    output wire [5:0] note_3,       
    output wire [5:0] duration_3,
    output wire [1:0]  harmonic_3,   
    output wire new_note_3
);
    wire [`SONG_WIDTH-1:0] curr_note_num, next_note_num;
    wire [`NOTE_WIDTH + `DURATION_WIDTH -1:0] note_and_duration;
    wire [`SONG_WIDTH + 1:0] rom_addr = {song, curr_note_num};

    wire [`SWIDTH-1:0] state;
    reg  [`SWIDTH-1:0] next;

    // For identifying when we reach the end of a song
    wire overflow;

    dffr #(`SONG_WIDTH) note_counter (
        .clk(clk),
        .r(reset),
        .d(next_note_num),
        .q(curr_note_num)
    );
    dffr #(`SWIDTH) fsm (
        .clk(clk),
        .r(reset),
        .d(next),
        .q(state)
    );

    song_rom rom(.clk(clk), .addr(rom_addr), .dout(note_and_duration));

    always @(*) begin
        case (state)
            `PAUSED:            next = play ? `RETRIEVE_NOTE : `PAUSED;
            `RETRIEVE_NOTE:     next = play ? `NEW_NOTE_READY : `PAUSED;
            `NEW_NOTE_READY:    next = play ? `WAIT: `PAUSED;
            `WAIT:              next = !play ? `PAUSED
                                             : (note_done ? `INCREMENT_ADDRESS
                                                          : `WAIT);
            `INCREMENT_ADDRESS: next = (play && ~overflow) ? `RETRIEVE_NOTE
                                                           : `PAUSED;
            default:            next = `PAUSED;
        endcase
    end

    assign {overflow, next_note_num} =
        (state == `INCREMENT_ADDRESS) ? {1'b0, curr_note_num} + 1
                                      : {1'b0, curr_note_num};
    assign new_note = (state == `NEW_NOTE_READY);
    assign {note, duration} = note_and_duration;
    assign song_done = overflow;

endmodule
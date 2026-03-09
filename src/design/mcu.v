`define PLAY_WIDTH 1
`define PAUSE 1'b0
`define PLAY 1'b1

`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module mcu(
    input clk,
    input reset,
    input play_button,
    input next_button,
    input mode_button,
    output play,
    output reset_player,
    output [1:0] song,
    output [1:0] mode,
    input song_done
);

    dffre #(.WIDTH(2)) song_reg (
        .clk(clk),
        .r(reset),
        .en(next_button || song_done),
        .d(song + 1'b1),
        .q(song)
    );

    wire play_state;
    reg  next_play_state;

    dffr #(.WIDTH(`PLAY_WIDTH)) playing_reg (
        .clk(clk),
        .r(reset),
        .d(next_play_state),
        .q(play_state)
    );
    
    wire [1:0] mode_state;
    reg  [1:0] next_mode_state;
    
    dffr #(.WIDTH(`MODE_WIDTH)) mode_reg (
        .clk(clk),
        .r(reset),
        .d(next_mode_state),
        .q(mode_state)
    );

    assign play = (play_state == `PLAY);
    assign reset_player = next_button || song_done;
    
    assign mode = mode_state;

    always @* begin
        case (play_state)
            `PAUSE:  next_play_state = play_button ? `PLAY : play_state;
            `PLAY:   next_play_state =
                (play_button || next_button || song_done) ? `PAUSE : play_state;
            default: next_play_state = `PAUSE;
        endcase
        
        case (mode_state)
            `NORMAL:  next_mode_state = mode_button ? `REWIND : mode_state;
            `REWIND:  next_mode_state = mode_button ? `FAST_FORWARD : mode_state;
            `FAST_FORWARD:  next_mode_state = mode_button ? `GENERATE : mode_state;
            `GENERATE:  next_mode_state = mode_button ? `NORMAL : mode_state;
            default: next_mode_state = `NORMAL;
        endcase
    end

endmodule

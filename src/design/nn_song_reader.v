module nn_song_reader (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire beat,        

    // Interface to neural_net
    output reg         nn_start,
    output reg  [95:0] nn_ctxt,
    input  wire [11:0] nn_new_note,
    input  wire        nn_done,

    // Interface to note_player
    output reg         np_play,
    output reg  [5:0]  np_note,
    output reg  [5:0]  np_duration, 
    output wire [1:0]  np_harmonic  
);

    // Force default instrument type
    assign np_harmonic = 2'd0;       

    // Initial Mario Seed
    localparam [95:0] MARIO_SEED = {
        12'b001100_100011,  // note 8: (35,12) [Newest]
        12'b001100_100001,  // note 7: (33,12)
        12'b001100_011110,  // note 6: (30,12)
        12'b001100_011100,  // note 5: (28,12)
        12'b001100_011110,  // note 4: (30,12)
        12'b001100_100001,  // note 3: (33,12)
        12'b001100_011111,  // note 2: (31,12)
        12'b001100_100011   // note 1: (35,12) [Oldest]
    };

    localparam S_IDLE     = 2'd0;
    localparam S_PLAY     = 2'd1;
    localparam S_WAIT_DUR = 2'd2;

    reg [2:0]  state;
    reg [3:0]  play_count;     // Tracks 0-7 for seed notes, 8+ for generated notes
    reg [5:0]  duration_timer;

    // Background generation registers
    reg        nn_is_ready;
    reg [11:0] latched_nn_note;
    
    // Multiplexer to extract the correct historical note during the seed playback phase
    reg [11:0] seed_note;
    always @(*) begin
        case(play_count)
            // Reads from MSB (Oldest) down to LSB (Newest)
            4'd0: seed_note = nn_ctxt[95:84]; 
            4'd1: seed_note = nn_ctxt[83:72];
            4'd2: seed_note = nn_ctxt[71:60];
            4'd3: seed_note = nn_ctxt[59:48];
            4'd4: seed_note = nn_ctxt[47:36];
            4'd5: seed_note = nn_ctxt[35:24];
            4'd6: seed_note = nn_ctxt[23:12];
            4'd7: seed_note = nn_ctxt[11:0];
            default: seed_note = 12'd0;
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            state          <= S_IDLE;
            play_count     <= 4'd0;
            duration_timer <= 6'd0;
            nn_start       <= 1'b0;
            np_play        <= 1'b0;
            nn_ctxt        <= MARIO_SEED;
            nn_is_ready    <= 1'b0;
            np_note        <= 6'd0;
            np_duration    <= 6'd0;  
        end else if (!enable) begin
            // Suspend playback but PRESERVE nn_ctxt
            state          <= S_IDLE;
            np_play        <= 1'b0;
            nn_start       <= 1'b0;
        end else begin
            // Default pulldowns
            np_play  <= 1'b0;
            nn_start <= 1'b0;

            if (beat && duration_timer > 0) begin
                duration_timer <= duration_timer - 1;
            end

            // Asynchronously catch the neural net finishing
            if (nn_done) begin
                latched_nn_note <= nn_new_note;
                nn_is_ready     <= 1'b1;
            end

            case (state)
                S_IDLE: begin
                    play_count  <= 4'd0;
                    nn_is_ready <= 1'b0;
                    state       <= S_PLAY;
                end

                S_PLAY: begin
                    if (play_count < 8) begin
                        // Play one of the 8 historical notes
                        np_play        <= 1'b1;
                        np_note        <= seed_note[5:0];
                        np_duration    <= seed_note[11:6]; 
                        duration_timer <= seed_note[11:6];

                        // If we are playing the 8th note, start the NN in the background
                        if (play_count == 7) begin
                            nn_start    <= 1'b1;
                            nn_is_ready <= 1'b0;
                        end

                        state <= S_WAIT_DUR;
                    end else begin
                        // Play a newly generated note
                        if (nn_is_ready) begin
                            // Shift the 96-bit context left and insert the new note
                            nn_ctxt        <= {nn_ctxt[83:0], latched_nn_note};
                            
                            np_play        <= 1'b1;
                            np_note        <= latched_nn_note[5:0];
                            np_duration    <= latched_nn_note[11:6]; // UPDATED
                            duration_timer <= latched_nn_note[11:6];

                            // Start generating the NEXT note for the next cycle
                            nn_start       <= 1'b1;
                            nn_is_ready    <= 1'b0;

                            state <= S_WAIT_DUR;
                        end
                        // If nn_is_ready is false, FSM waits safely in S_PLAY without pulsing np_play
                    end
                end

                S_WAIT_DUR: begin
                    if (duration_timer == 0) begin
                        if (play_count < 8) begin
                            play_count <= play_count + 1;
                        end
                        state <= S_PLAY;
                    end
                end
            endcase
        end
    end
endmodule
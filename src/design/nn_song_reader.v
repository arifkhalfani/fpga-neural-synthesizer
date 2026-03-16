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

    // A slow, calm C-Major Arpeggio (C4, E4, G4, C5)
    // Note encoding: C4=40, E4=44, G4=47, C5=52. Durations=24.
    localparam [95:0] CALM_SEED = {
        12'b011000_101000,  // [95:84] Note 1 (Oldest): C4 (40)
        12'b011000_101100,  // [83:72] Note 2         : E4 (44)
        12'b011000_101111,  // [71:60] Note 3         : G4 (47)
        12'b011000_110100,  // [59:48] Note 4         : C5 (52)
        12'b011000_101111,  // [47:36] Note 5         : G4 (47)
        12'b011000_101100,  // [35:24] Note 6         : E4 (44)
        12'b011000_101000,  // [23:12] Note 7         : C4 (40)
        12'b011000_100011   // [11:0]  Note 8 (Newest): G3 (35)
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
    
    // Useful for preventing sound popping, check lines ~126
    reg [5:0] safe_dur;
    reg [11:0] safe_note;

    always @(posedge clk) begin
        if (reset) begin
            state          <= S_IDLE;
            play_count     <= 4'd0;
            duration_timer <= 6'd0;
            nn_start       <= 1'b0;
            np_play        <= 1'b0;
            nn_ctxt        <= CALM_SEED;
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
                        
                        // Force note_player to run forever so it never drops to 0
                        np_duration    <= 6'd63;
                        
                        // Internal FSM tracks the real duration
                        duration_timer <= (seed_note[11:6] == 0) ? 6'd1 : seed_note[11:6];

                        // If we are playing the 8th note, start the NN in the background
                        if (play_count == 7) begin
                            nn_start    <= 1'b1;
                            nn_is_ready <= 1'b0;
                        end

                        state <= S_WAIT_DUR;
                    end else begin
                        // Play a newly generated note
                        if (nn_is_ready) begin
                            
                            safe_dur  = (latched_nn_note[11:6] == 0) ? 6'd1 : latched_nn_note[11:6];
                            safe_note = {safe_dur, latched_nn_note[5:0]};
                            
                            // Shift the safe note into the MSB (Newest)
                            nn_ctxt        <= {safe_note, nn_ctxt[95:12]};
                            
                            np_play        <= 1'b1;
                            np_note        <= safe_note[5:0];

                            // Force note_player to run forever so it never drops to 0
                            np_duration    <= 6'd63;
                        
                            // Internal FSM tracks the real duration
                            duration_timer <= safe_dur;

                            // Start generating the NEXT note for the next cycle
                            nn_start       <= 1'b1;
                            nn_is_ready    <= 1'b0;

                            state <= S_WAIT_DUR;
                        end
                        // If nn_is_ready is false, FSM waits safely in S_PLAY without pulsing np_play
                    end
                end

                S_WAIT_DUR: begin
                    // Catch the note one cycle before it ends
                    if ((duration_timer == 1 && beat) || duration_timer == 0) begin
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
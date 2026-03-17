//
//  music_player module
//
//  This music_player module connects up the MCU, song_reader, 4x note_players,
//  beat_generator, and codec_conditioner. It provides an output that indicates
//  a new sample (new_sample_generated) which will be used in lab 5.
//

`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module music_player(
    // Standard system clock and reset
    input clk,
    input reset,

    // Our debounced and one-pulsed button inputs.
    input play_button,
    input next_button,
    input mode_button,

    // The raw new_frame signal from the ac97_if codec.
    input new_frame,

    // This output must go high for one cycle when a new sample is generated.
    output wire new_sample_generated,

    // Our final output sample to the codec. This needs to be synced to
    // new_frame.
    output wire [15:0] sample_out,
    
    // Output flags to tell the wave_display when to hide the waves
    output wire is_playing_0, // For the main mix / NN white wave
    output wire is_playing_1,
    output wire is_playing_2,
    output wire is_playing_3,
    output wire is_playing_4,
    
    // Individual note outputs for wave_display
    output wire [15:0] sample_out_1,
    output wire new_sample_ready_1,
    output wire [15:0] sample_out_2,
    output wire new_sample_ready_2,
    output wire [15:0] sample_out_3,
    output wire new_sample_ready_3,
    output wire [15:0] sample_out_4,
    output wire new_sample_ready_4
    // -------------------------------------------------------
    
);
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    // If you reduce this to 100 your simulation will be 10x faster.
    parameter BEAT_COUNT = 1000;


//
//  ****************************************************************************
//      Master Control Unit
//  ****************************************************************************
//   The reset_player output from the MCU is run only to the song_reader because
//   we don't need to reset any state in the note_player. If we do it may make
//   a pop when it resets the output sample.
//
 
    wire play;
    wire reset_player;
    wire [1:0] current_song;
    wire song_done;
    
    wire [1:0] mode; 
    
    mcu mcu(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .mode_button(mode_button),
        .play(play),
        .reset_player(reset_player),
        .song(current_song),
        .mode(mode),
        .song_done(song_done)
    );

//
//  ****************************************************************************
//      Song Reader
//  ****************************************************************************
//
    wire [5:0] note_0, note_1, note_2, note_3;
    wire [5:0] duration_0, duration_1, duration_2, duration_3;
    wire [2:0] harmonic_0, harmonic_1, harmonic_2, harmonic_3;
    wire new_note_0, new_note_1, new_note_2, new_note_3;
    wire note_done_0, note_done_1, note_done_2, note_done_3;
    
    wire beat;

    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play),
        .beat(beat),
        .song(current_song),
        .mode(mode),
        .song_done(song_done),
        
        .note_done_0(note_done_0), .note_0(note_0), .duration_0(duration_0), .harmonic_0(harmonic_0), .new_note_0(new_note_0),
        .note_done_1(note_done_1), .note_1(note_1), .duration_1(duration_1), .harmonic_1(harmonic_1), .new_note_1(new_note_1),
        .note_done_2(note_done_2), .note_2(note_2), .duration_2(duration_2), .harmonic_2(harmonic_2), .new_note_2(new_note_2),
        .note_done_3(note_done_3), .note_3(note_3), .duration_3(duration_3), .harmonic_3(harmonic_3), .new_note_3(new_note_3)
    );

//   
//  ****************************************************************************
//      Neural Network & Generative Song Reader
//  ****************************************************************************
//
    wire        nn_start;
    wire [95:0] nn_ctxt;
    wire [11:0] nn_new_note;
    wire        nn_done;
    
    wire        nn_np_play;
    wire [5:0]  nn_np_note;
    wire [5:0]  nn_np_dur;
    wire [1:0]  nn_np_harmonic;
    wire        nn_note_done;

    neural_net nn_inst (
        .clk(clk),
        .reset(reset),
        .start(nn_start),
        .ctxt(nn_ctxt),
        .new_note(nn_new_note),
        .nn_done(nn_done)
    );

    // Only enable the NN reader when in GENERATE mode AND the MCU says 'play'
    wire nn_enable = (mode == `GENERATE) && play;

    nn_song_reader nn_reader (
        .clk(clk),
        .reset(reset),
        .enable(nn_enable),
        .beat(beat),
        .nn_start(nn_start),
        .nn_ctxt(nn_ctxt),
        .nn_new_note(nn_new_note),
        .nn_done(nn_done),
        .np_play(nn_np_play),
        .np_note(nn_np_note),
        .np_duration(nn_np_dur),
        .np_harmonic(nn_np_harmonic)
    );

//   
//  ****************************************************************************
//      Note Players
//  ****************************************************************************
//  
    wire generate_next_sample, generate_next_sample0;
    wire [15:0] note_sample, note_sample0;
    wire note_sample_ready, note_sample_ready0;

    wire signed [15:0] sample_out_0_internal, sample_out_1_internal, sample_out_2_internal, sample_out_3_internal;
    wire ready_0, ready_1, ready_2, ready_3;
    
    // Internal playing flags
    wire is_playing_0_internal, is_playing_1_internal, is_playing_2_internal, is_playing_3_internal;

    note_player note_player_0(
        .clk(clk), .reset(reset | reset_player), .mode(mode), .play_enable(play),
        .note_to_load(note_0), .duration_to_load(duration_0), .harmonic_to_load(harmonic_0), .load_new_note(new_note_0),
        .done_with_note(note_done_0), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_0_internal), .new_sample_ready(ready_0),
        .is_playing(is_playing_0_internal)
    );

    note_player note_player_1(
        .clk(clk), .reset(reset | reset_player), .mode(mode), .play_enable(play),
        .note_to_load(note_1), .duration_to_load(duration_1), .harmonic_to_load(harmonic_1), .load_new_note(new_note_1),
        .done_with_note(note_done_1), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_1_internal), .new_sample_ready(ready_1),
        .is_playing(is_playing_1_internal)
    );

    note_player note_player_2(
        .clk(clk), .reset(reset | reset_player), .mode(mode), .play_enable(play),
        .note_to_load(note_2), .duration_to_load(duration_2), .harmonic_to_load(harmonic_2), .load_new_note(new_note_2),
        .done_with_note(note_done_2), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_2_internal), .new_sample_ready(ready_2),
        .is_playing(is_playing_2_internal)
    );

    note_player note_player_3(
        .clk(clk), .reset(reset | reset_player), .mode(mode), .play_enable(play),
        .note_to_load(note_3), .duration_to_load(duration_3), .harmonic_to_load(harmonic_3), .load_new_note(new_note_3),
        .done_with_note(note_done_3), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_3_internal), .new_sample_ready(ready_3),
        .is_playing(is_playing_3_internal)
    );

    // 5th Note Player dedicated to Neural Network output
    wire signed [15:0] nn_sample_out_internal;
    wire nn_ready;
    wire nn_is_playing_internal;

    note_player nn_note_player_inst(
        .clk(clk), .reset(reset), .mode(`NORMAL), .play_enable(nn_enable),
        .note_to_load(nn_np_note), .duration_to_load(nn_np_dur), .harmonic_to_load(nn_np_harmonic), .load_new_note(nn_np_play),
        .done_with_note(nn_note_done), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(nn_sample_out_internal), .new_sample_ready(nn_ready),
        .is_playing(nn_is_playing_internal)
    );

    // Audio Mixer: Add the 4 channels into an 18-bit wire to prevent overflow, 
    // then arithmetic shift right by 2 to divide by 4.
    wire signed [17:0] mixed_sample = $signed(sample_out_1) + $signed(sample_out_2) + $signed(sample_out_3) + $signed(sample_out_4);
    
    // MULTIPLEXER: Select Neural Network audio if in GENERATE mode, otherwise standard 4-channel mix
    assign note_sample0       = (mode == `GENERATE) ? nn_sample_out_internal : (mixed_sample >>> 2);
    assign note_sample_ready0 = (mode == `GENERATE) ? nn_ready               : (ready_0 | ready_1 | ready_2 | ready_3);

    // Flag Multiplexer: Determine if the white wave should be visible
    wire is_playing_mix    = is_playing_0_internal | is_playing_1_internal | is_playing_2_internal | is_playing_3_internal;
    wire is_playing_0_comb = (mode == `GENERATE) ? nn_is_playing_internal : is_playing_mix;

    // These pipeline registers were added to decrease the length of the critical path!
    dffr pipeline_ff_gen_next_sample (.clk(clk), .r(reset), .d(generate_next_sample0), .q(generate_next_sample));
    dffr #(.WIDTH(16)) pipeline_ff_note_sample (.clk(clk), .r(reset), .d(note_sample0), .q(note_sample));
    dffr pipeline_ff_new_sample_ready (.clk(clk), .r(reset), .d(note_sample_ready0), .q(note_sample_ready));
    dffr pipe_play_0 (.clk(clk), .r(reset), .d(is_playing_0_comb), .q(is_playing_0));

    // Pipeline flops for the individual notes to match critical path logic
    dffr #(.WIDTH(16)) pipeline_ff_note_1 (.clk(clk), .r(reset), .d(sample_out_0_internal), .q(sample_out_1));
    dffr pipeline_ff_ready_1 (.clk(clk), .r(reset), .d(ready_0), .q(new_sample_ready_1));
    dffr pipe_play_1 (.clk(clk), .r(reset), .d(is_playing_0_internal), .q(is_playing_1));

    dffr #(.WIDTH(16)) pipeline_ff_note_2 (.clk(clk), .r(reset), .d(sample_out_1_internal), .q(sample_out_2));
    dffr pipeline_ff_ready_2 (.clk(clk), .r(reset), .d(ready_1), .q(new_sample_ready_2));
    dffr pipe_play_2 (.clk(clk), .r(reset), .d(is_playing_1_internal), .q(is_playing_2));

    dffr #(.WIDTH(16)) pipeline_ff_note_3 (.clk(clk), .r(reset), .d(sample_out_2_internal), .q(sample_out_3));
    dffr pipeline_ff_ready_3 (.clk(clk), .r(reset), .d(ready_2), .q(new_sample_ready_3));
    dffr pipe_play_3 (.clk(clk), .r(reset), .d(is_playing_2_internal), .q(is_playing_3));

    dffr #(.WIDTH(16)) pipeline_ff_note_4 (.clk(clk), .r(reset), .d(sample_out_3_internal), .q(sample_out_4));
    dffr pipeline_ff_ready_4 (.clk(clk), .r(reset), .d(ready_3), .q(new_sample_ready_4));
    dffr pipe_play_4 (.clk(clk), .r(reset), .d(is_playing_3_internal), .q(is_playing_4));
    
        
//   
//  ****************************************************************************
//      Beat Generator
//  ****************************************************************************
//  By default this will divide the generate_next_sample signal (48kHz from the
//  codec's new_frame input) down by 1000, to 48Hz. If you change the BEAT_COUNT
//  parameter when instantiating this you can change it for simulation.
//  
    beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(generate_next_sample),
        .beat(beat)
    );

//  
//  ****************************************************************************
//      Codec Conditioner
//  ****************************************************************************
//  
    wire new_sample_generated0;
    wire [15:0] sample_out0; 
    
    wire ready_p1, ready_p2;
    dffr pipe_r1 (.clk(clk), .r(reset), .d(generate_next_sample0), .q(ready_p1));
    dffr pipe_r2 (.clk(clk), .r(reset), .d(ready_p1), .q(ready_p2));

    // Send the correct signals straight to the outputs regardless of mode
    assign new_sample_generated = ready_p2;
    assign sample_out           = sample_out0;
    
    assign new_sample_generated0 = generate_next_sample;
    codec_conditioner codec_conditioner(
        .clk(clk),
        .reset(reset),
        .new_sample_in(note_sample),
        .latch_new_sample_in(note_sample_ready),
        .generate_next_sample(generate_next_sample0),
        .new_frame(new_frame),
        .valid_sample(sample_out0)
    );

endmodule
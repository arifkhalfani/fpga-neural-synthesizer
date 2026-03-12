//
//  music_player module
//
//  This music_player module connects up the MCU, song_reader, 4x note_players,
//  beat_generator, and codec_conditioner. It provides an output that indicates
//  a new sample (new_sample_generated) which will be used in lab 5.
//

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
    output wire [15:0] sample_out
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
//      Note Players (x4 for Polyphony)
//  ****************************************************************************
//  
    wire generate_next_sample, generate_next_sample0;
    wire [15:0] note_sample, note_sample0;
    wire note_sample_ready, note_sample_ready0;

    wire signed [15:0] sample_out_0, sample_out_1, sample_out_2, sample_out_3;
    wire ready_0, ready_1, ready_2, ready_3;

    note_player note_player_0(
        .clk(clk), .reset(reset), .mode(mode), .play_enable(play),
        .note_to_load(note_0), .duration_to_load(duration_0), .harmonic_to_load(harmonic_0), .load_new_note(new_note_0),
        .done_with_note(note_done_0), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_0), .new_sample_ready(ready_0)
    );

    note_player note_player_1(
        .clk(clk), .reset(reset), .mode(mode), .play_enable(play),
        .note_to_load(note_1), .duration_to_load(duration_1), .harmonic_to_load(harmonic_1), .load_new_note(new_note_1),
        .done_with_note(note_done_1), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_1), .new_sample_ready(ready_1)
    );

    note_player note_player_2(
        .clk(clk), .reset(reset), .mode(mode), .play_enable(play),
        .note_to_load(note_2), .duration_to_load(duration_2), .harmonic_to_load(harmonic_2), .load_new_note(new_note_2),
        .done_with_note(note_done_2), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_2), .new_sample_ready(ready_2)
    );

    note_player note_player_3(
        .clk(clk), .reset(reset), .mode(mode), .play_enable(play),
        .note_to_load(note_3), .duration_to_load(duration_3), .harmonic_to_load(harmonic_3), .load_new_note(new_note_3),
        .done_with_note(note_done_3), .beat(beat), .generate_next_sample(generate_next_sample),
        .sample_out(sample_out_3), .new_sample_ready(ready_3)
    );

    // Audio Mixer: Add the 4 channels into an 18-bit wire to prevent overflow, 
    // then arithmetic shift right by 2 to divide by 4.
    wire signed [17:0] mixed_sample = sample_out_0 + sample_out_1 + sample_out_2 + sample_out_3;
    assign note_sample0 = mixed_sample >>> 2;

    // All note players run perfectly synchronously, so we only need to monitor one ready signal.
    assign note_sample_ready0 = ready_0;

    // These pipeline registers were added to decrease the length of the critical path!
    dffr pipeline_ff_gen_next_sample (.clk(clk), .r(reset), .d(generate_next_sample0), .q(generate_next_sample));
    dffr #(.WIDTH(16)) pipeline_ff_note_sample (.clk(clk), .r(reset), .d(note_sample0), .q(note_sample));
    dffr pipeline_ff_new_sample_ready (.clk(clk), .r(reset), .d(note_sample_ready0), .q(note_sample_ready));
      
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

    dffr pipeline_ff_nsg (.clk(clk), .r(reset), .d(new_sample_generated0), .q(new_sample_generated));
    dffr #(.WIDTH(16)) pipeline_ff_sample_out (.clk(clk), .r(reset), .d(sample_out0), .q(sample_out));

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
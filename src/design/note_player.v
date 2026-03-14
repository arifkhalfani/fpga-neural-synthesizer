`define MODE_WIDTH 2
`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module note_player(
    input clk,
    input reset,
    input [1:0] mode,
    input play_enable,              // When high we play, when low we don't.
    input [5:0] note_to_load,       // The note to play
    input [5:0] duration_to_load,   // The duration of the note to play
    input [2:0] harmonic_to_load,   // Type of harmonic to play
    input load_new_note,            // Tells us when we have a new note to load
    output done_with_note,          // When we are done with the note this stays high.
    input beat,                     // This is our 1/48th second beat
    input generate_next_sample,     // Tells us when the codec wants a new sample
    output [15:0] sample_out,       // Our sample output (NOW DRIVEN BY FLOP)
    output new_sample_ready         // Tells the codec when we've got a sample (NOW DRIVEN BY FLOP)
);

    wire [19:0] step_size;
    wire [5:0] freq_rom_in;
    wire [2:0] current_harmonic;

    // Register to store the base note
    dffre #(.WIDTH(6)) freq_reg (
        .clk(clk),
        .r(reset),
        .en(load_new_note),
        .d(note_to_load),
        .q(freq_rom_in)
    );

    // Register to store the requested instrument profile
    dffre #(.WIDTH(3)) harmonic_reg (
        .clk(clk),
        .r(reset),
        .en(load_new_note),
        .d(harmonic_to_load),
        .q(current_harmonic)
    );

    frequency_rom freq_rom(
        .clk(clk),
        .addr(freq_rom_in),
        .dout(step_size)
    );

    // Calculate step sizes for 1f, 2f, 3f, and 4f
    wire [19:0] step_size_1 = step_size;
    wire [19:0] step_size_2 = step_size << 1;                   // x2
    wire [19:0] step_size_3 = step_size + (step_size << 1);     // x3
    wire [19:0] step_size_4 = step_size << 2;                   // x4

    // 4 Sine Readers
    wire signed [15:0] s1, s2, s3, s4;
    wire ready_1, ready_2, ready_3, ready_4; 
    
    sine_reader sr1(.clk(clk), .reset(reset), .mode(mode), .step_size(step_size_1), .generate_next(play_enable && generate_next_sample), .sample_ready(ready_1), .sample(s1));
    sine_reader sr2(.clk(clk), .reset(reset), .mode(mode), .step_size(step_size_2), .generate_next(play_enable && generate_next_sample), .sample_ready(ready_2), .sample(s2));
    sine_reader sr3(.clk(clk), .reset(reset), .mode(mode), .step_size(step_size_3), .generate_next(play_enable && generate_next_sample), .sample_ready(ready_3), .sample(s3));
    sine_reader sr4(.clk(clk), .reset(reset), .mode(mode), .step_size(step_size_4), .generate_next(play_enable && generate_next_sample), .sample_ready(ready_4), .sample(s4));

    // Weight mux (fixed point scale: 2^14 = 16384 = 1.0)
    reg signed [16:0] w1, w2, w3, w4; 
    
    // Normalized weight mux: The sum of w1+w2+w3+w4 <= 16384
    always @(*) begin
        case(current_harmonic)
            3'd1: begin w1=11000; w2=3500;  w3=1884;  w4=0;    end // Flute (sine-like)
            3'd2: begin w1=10000; w2=0;     w3=6384;  w4=0;    end // Clarinet (odd harmonics)
            3'd3: begin w1=8000;  w2=4000;  w3=2500;  w4=1884; end // Brass (sawtooth)
            3'd4: begin w1=10000; w2=5000;  w3=1384;  w4=0;    end // Tonewheel Organ
            3'd5: begin w1=4000;  w2=8000;  w3=4384;  w4=0;    end // Oboe (dominant 2nd/3rd)
            3'd6: begin w1=14000; w2=0;     w3=0;     w4=2384; end // Vibraphone
            3'd7: begin w1=4096;  w2=4096;  w3=4096;  w4=4096; end // Harpsichord (pulse)
            default: begin w1=16384; w2=0; w3=0; w4=0; end         // Pure sine
        endcase
    end

    // Multiply (combinational)
    wire signed [31:0] mix1_comb = s1 * w1;
    wire signed [31:0] mix2_comb = s2 * w2;
    wire signed [31:0] mix3_comb = s3 * w3;
    wire signed [31:0] mix4_comb = s4 * w4;

    // Pipeline the multipliers before the adder tree
    wire signed [31:0] mix1, mix2, mix3, mix4;
    dffr #(.WIDTH(32)) pipe_mix1 (.clk(clk), .r(reset), .d(mix1_comb), .q(mix1));
    dffr #(.WIDTH(32)) pipe_mix2 (.clk(clk), .r(reset), .d(mix2_comb), .q(mix2));
    dffr #(.WIDTH(32)) pipe_mix3 (.clk(clk), .r(reset), .d(mix3_comb), .q(mix3));
    dffr #(.WIDTH(32)) pipe_mix4 (.clk(clk), .r(reset), .d(mix4_comb), .q(mix4));

    // Pipeline the ready signal so it stays in sync with the new 1-cycle delay
    wire ready_delayed;
    dffr pipe_ready (.clk(clk), .r(reset), .d(ready_1), .q(ready_delayed));

    // Add the pipelined values together
    wire signed [31:0] mix_sum = mix1 + mix2 + mix3 + mix4;
    
    // Shift right by 14 to normalize back to 16-bit audio ranges, 
    // but force the output to zero if the note is done or we are in GENERATE.
    wire signed [15:0] internal_sample_out = (done_with_note || mode == `GENERATE) ? 16'b0 : (mix_sum >>> 14);
    
    // Flop the final calculated sample
    dffr #(.WIDTH(16)) pipeline_sample (
        .clk(clk),
        .r(reset),
        .d(internal_sample_out),
        .q(sample_out)
    );
    
    // Flop the ready signal to keep it in sync with the delayed sample
    dffr pipeline_ready_final (
        .clk(clk),
        .r(reset),
        .d(ready_delayed),
        .q(new_sample_ready)
    );

    // Standard count / duration logic
    wire [5:0] count, next_count;
    dffre #(.WIDTH(6)) counter_ff (
        .clk(clk),
        .r(reset),
        .en((beat || load_new_note) && play_enable),
        .d(next_count),
        .q(count)
    );
    assign next_count = (reset || load_new_note) ? duration_to_load - 1 :
                        (done_with_note)         ? 6'b0 : 
                        (mode == `FAST_FORWARD)  ? count - 2 : 
                        count - 1;

    assign done_with_note = (count == 6'b0) || ((mode == `FAST_FORWARD) && (count == 6'd1));

endmodule
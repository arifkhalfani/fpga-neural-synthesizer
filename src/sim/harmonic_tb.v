`timescale 1ns / 1ps

`define NORMAL 2'b00
`define REWIND 2'b01
`define FAST_FORWARD 2'b11
`define GENERATE 2'b10

module harmonic_tb();
    reg clk;
    reg reset;
    reg [1:0] mode;                 
    reg play_enable;                
    reg [5:0] note_to_load;         
    reg [5:0] duration_to_load;     
    reg [2:0] harmonic_to_load;     
    reg load_new_note;              
    reg beat;                       
    reg generate_next_sample;       

    wire done_with_note;            
    wire [15:0] sample_out;        
    wire new_sample_ready;         

    note_player dut (
        .clk(clk),
        .reset(reset),
        .mode(mode),
        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .harmonic_to_load(harmonic_to_load),
        .load_new_note(load_new_note),
        .done_with_note(done_with_note),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out),
        .new_sample_ready(new_sample_ready)
    );

    // 100MHz Clock generation
    always #5 clk = ~clk;

    // 48kHz Audio Sample Pulse Generator
    // 100MHz / 48kHz = ~2083 clock cycles
    reg [11:0] sample_counter;
    always @(posedge clk) begin
        if (reset) begin
            sample_counter <= 0;
            generate_next_sample <= 0;
        end else begin
            if (sample_counter == 12'd2082) begin
                sample_counter <= 0;
                generate_next_sample <= 1;
            end else begin
                sample_counter <= sample_counter + 1;
                generate_next_sample <= 0;
            end
        end
    end


    initial begin
        clk = 0;
        reset = 1;
        mode = `NORMAL;
        play_enable = 0;
        note_to_load = 6'd36;       // 4C
        duration_to_load = 6'd63;   // Max duration
        harmonic_to_load = 3'd0;    // Pure Sine
        load_new_note = 0;
        
        // By leaving beat at 0, next_count never decrements below 
        // (duration - 1), so the note never finishes and the wave plays infinitely
        beat = 0;                   

        #100;
        reset = 0;
        #100;

        // Test 1: Pure Sine (Harmonic 0)
        $display("Loading Harmonic 0 (Pure Sine)...");
        harmonic_to_load = 3'd0;
        play_enable = 1;
        load_new_note = 1;
        #10 
        load_new_note = 0;
        #5000000; // Wait 5ms to see several full waves

        // Test 2: Flute (Harmonic 1)
        $display("Loading Harmonic 1 (Flute)...");
        play_enable = 0;
        #100;
        harmonic_to_load = 3'd1;
        play_enable = 1;
        load_new_note = 1;
        #10 
        load_new_note = 0;
        #5000000;

        // Test 3: Brass (Harmonic 3)
        $display("Loading Harmonic 3 (Brass)...");
        play_enable = 0;
        #100;
        harmonic_to_load = 3'd3;
        play_enable = 1;
        load_new_note = 1;
        #10 
        load_new_note = 0;
        #5000000;

        // Test 4: Organ (Harmonic 4)
        $display("Loading Harmonic 4 (Organ)...");
        play_enable = 0;
        #100;
        harmonic_to_load = 3'd4;
        play_enable = 1;
        load_new_note = 1;
        #10 
        load_new_note = 0;
        #5000000;

        $display("Simulation Complete!");
        $finish;
    end
endmodule
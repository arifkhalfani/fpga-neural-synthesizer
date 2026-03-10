module song_reader_tb();

    reg clk, reset, play, note_done;
    reg [1:0] song;
    wire [5:0] note;
    wire [5:0] duration;
    wire song_done, new_note;

    song_reader dut(
        .clk(clk),
        .reset(reset),
        .play(play),
        .song(song),
        .song_done(song_done),
        .note(note),
        .duration(duration),
        .new_note(new_note),
        .note_done(note_done)
    );

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        repeat (4) #5 clk = ~clk;
        reset = 1'b0;
        forever #5 clk = ~clk;
    end

    always begin
        #1;
        if (new_note) begin
            #20;

            note_done = 1;
            #10;
            note_done = 0;
        end
    end

    initial begin
        play = 0;
        note_done = 0;
        song = 0;

        #60;

        song = 2'd0;
        play = 1;

        wait(song_done);
        #20;
        play = 0;

        #100;

        song = 2'd1;
        play = 1;

        wait(song_done);
        #20;
        play = 0;

        #200;
        $finish;
    end

endmodule
module neural_net_tb;

    reg        clk;
    reg        reset;
    reg        start;
    reg [95:0] ctxt;

    wire [11:0] new_note;
    wire        nn_done;

    neural_net dut (
        .clk      (clk),
        .reset    (reset),
        .start    (start),
        .ctxt     (ctxt),
        .new_note (new_note),
        .nn_done  (nn_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cycle_count;
    integer k;

    initial begin
        reset       = 1;
        start       = 0;
        ctxt        = 96'd0;
        cycle_count = 0;

        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // mario seed: (28,6),(28,6),(28,12),(25,6),(28,12),(32,12),(20,12),(25,12)
        // note 28 = 011100, dur  6 = 000110 -> 12'b000110_011100
        // note 25 = 011001, dur  6 = 000110 -> 12'b000110_011001
        // note 28 = 011100, dur 12 = 001100 -> 12'b001100_011100
        // note 25 = 011001, dur  6 = 000110 -> 12'b000110_011001
        // note 28 = 011100, dur 12 = 001100 -> 12'b001100_011100
        // note 32 = 100000, dur 12 = 001100 -> 12'b001100_100000
        // note 20 = 010100, dur 12 = 001100 -> 12'b001100_010100
        // note 25 = 011001, dur 12 = 001100 -> 12'b001100_011001
        ctxt = {
                12'b001100_100011,  // note 8: (35,12)
                12'b001100_100001,  // note 7: (33,12)
                12'b001100_011110,  // note 6: (30,12)
                12'b001100_011100,  // note 5: (28,12)
                12'b001100_011110,  // note 4: (30,12)
                12'b001100_100001,  // note 3: (33,12)
                12'b001100_011111,  // note 2: (31,12)
                12'b001100_100011   // note 1: (35,12)
        };
        // print ctxt bits to verify ordering matches Python
        $display("=== ctxt bit ordering check ===");
        for (k = 0; k < 96; k = k + 1)
            $display("ctxt[%0d] = %b", k, ctxt[k]);

        // pulse start
        @(posedge clk); #1;
        start = 1;
        @(posedge clk); #1;
        start = 0;

        // wait for nn_done
        while (!nn_done) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            if (cycle_count > 10000) begin
                $display("TIMEOUT - nn_done never asserted");
                $finish;
            end
        end

        $display("Done after %0d cycles", cycle_count);
        $display("new_note (12 bits): %b", new_note);
        $display("  note bits [5:0]:  %b = %0d", new_note[5:0],  new_note[5:0]);
        $display("  dur  bits [11:6]: %b = %0d", new_note[11:6], new_note[11:6]);
        $display("  duration in seconds: %f", new_note[11:6] / 48.0);

        $finish;
    end

endmodule


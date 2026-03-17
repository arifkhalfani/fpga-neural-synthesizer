module neural_net (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [95:0] ctxt,
    output wire [11:0] new_note,
    output wire        nn_done
);

    localparam W    = 16;
    localparam FRAC = 12;

    localparam STATE_WIDTH = 2;
    localparam IDLE   = 2'd0;
    localparam HIDDEN = 2'd1;
    localparam OUTPUT = 2'd2;
    localparam DONE   = 2'd3;

    wire [STATE_WIDTH-1:0] state, state_next;
    dffr #(STATE_WIDTH) state_r (.clk(clk), .r(reset), .d(state_next), .q(state));

    wire [6:0] input_index,  input_index_next;
    wire [4:0] hidden_index, hidden_index_next;
    wire [3:0] output_index, output_index_next;

    dffr #(7) input_index_r  (.clk(clk), .r(reset), .d(input_index_next),  .q(input_index));
    dffr #(5) hidden_index_r (.clk(clk), .r(reset), .d(hidden_index_next), .q(hidden_index));
    dffr #(4) output_index_r (.clk(clk), .r(reset), .d(output_index_next), .q(output_index));

    wire signed [47:0] acc, acc_next;
    dffr #(48) acc_r (.clk(clk), .r(reset), .d(acc_next), .q(acc));

    wire signed [31:0] hidden_out      [0:31];
    wire signed [31:0] hidden_out_next [0:31];
    wire               hidden_out_en   [0:31];

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : hidden_out_regs
            dffre #(32) hidden_out_r (
                .clk(clk), .r(reset),
                .en(hidden_out_en[g]),
                .d(hidden_out_next[g]),
                .q(hidden_out[g])
            );
        end
    endgenerate

    wire [11:0] new_note_reg, new_note_next;
    dffr #(12) new_note_r (.clk(clk), .r(reset), .d(new_note_next), .q(new_note_reg));
    assign new_note = new_note_reg;

    wire nn_done_reg, nn_done_next;
    dffr #(1) nn_done_r (.clk(clk), .r(reset), .d(nn_done_next), .q(nn_done_reg));
    assign nn_done = nn_done_reg;

    // Fast shift-adds replace the DSP index multiplier
    wire [11:0] wh_index = {1'b0, hidden_index, 6'd0} + {2'b0, hidden_index, 5'd0} + {5'd0, input_index};
    wire [8:0]  wo_index = {output_index, 5'd0} + {4'd0, hidden_index};

    wire [15:0] wh_data, bh_data, wo_data, bo_data;
    weight_hidden_rom wh_rom (.addr(wh_index),     .data(wh_data));
    bias_hidden_rom   bh_rom (.addr(hidden_index), .data(bh_data));
    weight_output_rom wo_rom (.addr(wo_index),     .data(wo_data));
    bias_output_rom   bo_rom (.addr(output_index), .data(bo_data));

    wire last_input  = (input_index  == 7'd95);
    wire last_hidden = (hidden_index == 5'd31);
    wire last_output = (output_index == 4'd11);

    // =========================================================================
    // Pipeline Stage 1: ROM Fetch Delay
    // =========================================================================
    wire [STATE_WIDTH-1:0] st_s1;
    wire [4:0] h_idx_s1;
    wire [3:0] o_idx_s1;
    wire li_s1, lh_s1;

    wire [15:0] wh_s1, wo_s1, bh_s1, bo_s1;
    wire ctxt_s1;
    wire signed [31:0] act_o_s1;

    dffr #(STATE_WIDTH) r_st_s1 (.clk(clk), .r(reset), .d(state), .q(st_s1));
    dffr #(5)  r_hi_s1 (.clk(clk), .r(reset), .d(hidden_index), .q(h_idx_s1));
    dffr #(4)  r_oi_s1 (.clk(clk), .r(reset), .d(output_index), .q(o_idx_s1));
    dffr #(1)  r_li_s1 (.clk(clk), .r(reset), .d(last_input), .q(li_s1));
    dffr #(1)  r_lh_s1 (.clk(clk), .r(reset), .d(last_hidden), .q(lh_s1));

    dffr #(16) r_wh_s1 (.clk(clk), .r(reset), .d(wh_data), .q(wh_s1));
    dffr #(16) r_wo_s1 (.clk(clk), .r(reset), .d(wo_data), .q(wo_s1));
    dffr #(16) r_bh_s1 (.clk(clk), .r(reset), .d(bh_data), .q(bh_s1));
    dffr #(16) r_bo_s1 (.clk(clk), .r(reset), .d(bo_data), .q(bo_s1));

    dffr #(1)  r_cx_s1 (.clk(clk), .r(reset), .d(ctxt[input_index]), .q(ctxt_s1));
    dffr #(32) r_ao_s1 (.clk(clk), .r(reset), .d(hidden_out[hidden_index]), .q(act_o_s1));

    // =========================================================================
    // Pipeline Stage 2: Operand Muxing (setup for multiplier)
    // =========================================================================
    wire signed [15:0] mult_a_next = (st_s1 == HIDDEN) ? wh_s1 : wo_s1;
    wire signed [31:0] mult_b_next = (st_s1 == HIDDEN) ? (ctxt_s1 ? 32'd1 : 32'd0) : act_o_s1;

    wire signed [15:0] mult_a_s2;
    wire signed [31:0] mult_b_s2;
    wire [15:0] bh_s2, bo_s2;
    wire [STATE_WIDTH-1:0] st_s2;
    wire [4:0] h_idx_s2;
    wire [3:0] o_idx_s2;
    wire li_s2, lh_s2;

    dffr #(16) r_ma_s2 (.clk(clk), .r(reset), .d(mult_a_next), .q(mult_a_s2));
    dffr #(32) r_mb_s2 (.clk(clk), .r(reset), .d(mult_b_next), .q(mult_b_s2));
    
    dffr #(16) r_bh_s2 (.clk(clk), .r(reset), .d(bh_s1), .q(bh_s2));
    dffr #(16) r_bo_s2 (.clk(clk), .r(reset), .d(bo_s1), .q(bo_s2));

    dffr #(STATE_WIDTH) r_st_s2 (.clk(clk), .r(reset), .d(st_s1), .q(st_s2));
    dffr #(5)  r_hi_s2 (.clk(clk), .r(reset), .d(h_idx_s1), .q(h_idx_s2));
    dffr #(4)  r_oi_s2 (.clk(clk), .r(reset), .d(o_idx_s1), .q(o_idx_s2));
    dffr #(1)  r_li_s2 (.clk(clk), .r(reset), .d(li_s1), .q(li_s2));
    dffr #(1)  r_lh_s2 (.clk(clk), .r(reset), .d(lh_s1), .q(lh_s2));

    // =========================================================================
    // Pipeline Stage 3: Multiplier Execution
    // =========================================================================
    wire signed [47:0] product_next = mult_a_s2 * mult_b_s2;
    
    wire signed [47:0] prod_s3;
    wire [15:0] bh_s3, bo_s3;
    wire [STATE_WIDTH-1:0] st_s3;
    wire [4:0] h_idx_s3;
    wire [3:0] o_idx_s3;
    wire li_s3, lh_s3;

    dffr #(48) r_pr_s3 (.clk(clk), .r(reset), .d(product_next), .q(prod_s3));
    
    dffr #(16) r_bh_s3 (.clk(clk), .r(reset), .d(bh_s2), .q(bh_s3));
    dffr #(16) r_bo_s3 (.clk(clk), .r(reset), .d(bo_s2), .q(bo_s3));

    dffr #(STATE_WIDTH) r_st_s3 (.clk(clk), .r(reset), .d(st_s2), .q(st_s3));
    dffr #(5)  r_hi_s3 (.clk(clk), .r(reset), .d(h_idx_s2), .q(h_idx_s3));
    dffr #(4)  r_oi_s3 (.clk(clk), .r(reset), .d(o_idx_s2), .q(o_idx_s3));
    dffr #(1)  r_li_s3 (.clk(clk), .r(reset), .d(li_s2), .q(li_s3));
    dffr #(1)  r_lh_s3 (.clk(clk), .r(reset), .d(lh_s2), .q(lh_s3));

    // =========================================================================
    // Stage 4: Accumulation & Bias (Combinational phase driving registers)
    // =========================================================================
    wire signed [47:0] acc_plus_product = acc + prod_s3;
    wire signed [47:0] bias_ext = (st_s3 == HIDDEN) ? {{32{bh_s3[15]}}, bh_s3} : {{32{bo_s3[15]}}, bo_s3};
    wire signed [47:0] final_val = acc_plus_product + bias_ext;

    // FSM Logic (Base index generators)
    assign state_next = (state == IDLE   && start)                      ? HIDDEN
                      : (state == HIDDEN && last_input && last_hidden)  ? OUTPUT
                      : (state == OUTPUT && last_hidden && last_output) ? DONE
                      : (state == DONE)                                 ? IDLE
                      :                                                   state;

    assign input_index_next = (state != HIDDEN) ? 7'd0
                            : last_input        ? 7'd0
                            :                     input_index + 7'd1;

    assign hidden_index_next = (state == IDLE)                                ? 5'd0
                             : (state == HIDDEN && last_input && last_hidden) ? 5'd0
                             : (state == HIDDEN && last_input)                ? hidden_index + 5'd1
                             : (state == OUTPUT && last_hidden)               ? 5'd0
                             : (state == OUTPUT)                              ? hidden_index + 5'd1
                             :                                                  hidden_index;

    assign output_index_next = (state != OUTPUT)            ? 4'd0
                             : (last_hidden && last_output) ? 4'd0
                             : last_hidden                  ? output_index + 4'd1
                             :                                output_index;

    // Accumulation uses Stage 3 logic so it adds precisely when the pipelined product arrives
    assign acc_next = (st_s3 == IDLE)            ? 48'd0
                    : (st_s3 == HIDDEN && li_s3) ? 48'd0
                    : (st_s3 == HIDDEN)          ? acc_plus_product
                    : (st_s3 == OUTPUT && lh_s3) ? 48'd0
                    : (st_s3 == OUTPUT)          ? acc_plus_product
                    :                              48'd0;

    generate
        for (g = 0; g < 32; g = g + 1) begin : hidden_out_next_logic
            assign hidden_out_en[g]   = (st_s3 == HIDDEN) && li_s3 && (h_idx_s3 == g);
            assign hidden_out_next[g] = (final_val > 0) ? final_val[43:12] : 32'd0;
        end
    endgenerate

    // Output assignments use Stage 3 logic
    assign new_note_next = (st_s3 == IDLE)            ? 12'd0
                         : (st_s3 == OUTPUT && lh_s3) ? (new_note_reg | ((final_val > 0 ? 12'd1 : 12'd0) << o_idx_s3))
                         :                              new_note_reg;

    assign nn_done_next = (st_s3 == DONE) ? 1'b1 : 1'b0;

//    // Debugging (Updated to trace Stage 3)
//    always @(posedge clk) begin
//        if (st_s3 == HIDDEN && h_idx_s3 <= 3 && prod_s3 != 0)
//            $display("h=%0d p=%d acc_after=%d",
//                h_idx_s3, prod_s3, acc_plus_product);

//        if (st_s3 == HIDDEN && li_s3 && h_idx_s3 <= 3)
//            $display("[HIDDEN %0d] hidden_final=%d stored=%d",
//                h_idx_s3, final_val,
//                (final_val > 0) ? final_val[43:12] : 32'd0);

//        if (st_s3 == HIDDEN && li_s3 && lh_s3) begin
//            $display("[HIDDEN done] hidden_out[0]=%d (python 0)", hidden_out[0]);
//            $display("[HIDDEN done] hidden_out[1]=%d (python 0)", hidden_out[1]);
//            $display("[HIDDEN done] hidden_out[2]=%d (python 2)", hidden_out[2]);
//            $display("[HIDDEN done] hidden_out[3]=%d (python 1)", hidden_out[3]);
//        end

//        if (st_s3 == OUTPUT && lh_s3)
//            $display("[OUTPUT %0d] output_final=%d bit=%b",
//                o_idx_s3, final_val,
//                (final_val > 0) ? 1'b1 : 1'b0);

//        if (st_s3 == DONE)
//            $display("[DONE] new_note=%b note=%0d dur=%0d",
//                new_note_reg, new_note_reg[5:0], new_note_reg[11:6]);
//    end

endmodule
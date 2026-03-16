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

    wire [11:0] wh_index;
    wire [8:0]  wo_index;
    assign wh_index = ({7'd0, hidden_index} * 12'd96) + {5'd0, input_index};
    assign wo_index = ({5'd0, output_index} * 9'd32)  + {4'd0, hidden_index};

    wire [15:0] wh_data, bh_data, wo_data, bo_data;
    weight_hidden_rom wh_rom (.addr(wh_index),     .data(wh_data));
    bias_hidden_rom   bh_rom (.addr(hidden_index), .data(bh_data));
    weight_output_rom wo_rom (.addr(wo_index),     .data(wo_data));
    bias_output_rom   bo_rom (.addr(output_index), .data(bo_data));

    wire signed [15:0] weight_val;
    wire signed [15:0] act_val_h;
    wire signed [31:0] act_val_o;
    wire signed [31:0] product_h;
    wire signed [47:0] product_o;
    wire signed [47:0] product;

    assign weight_val = $signed(state == HIDDEN ? wh_data : wo_data);
    assign act_val_h  = $signed({{15{1'b0}}, ctxt[input_index]});
    assign act_val_o  = $signed(hidden_out[hidden_index]);
    assign product_h  = $signed(weight_val) * $signed(act_val_h);
    assign product_o  = $signed({{16{weight_val[15]}}, weight_val}) * act_val_o;
    assign product    = (state == HIDDEN)
                      ? {{16{product_h[31]}}, product_h}
                      : product_o;

    wire signed [47:0] bias_h_ext, bias_o_ext;
    assign bias_h_ext = {{32{bh_data[15]}}, bh_data};
    assign bias_o_ext = {{32{bo_data[15]}}, bo_data};

    wire last_input  = (input_index  == 7'd95);
    wire last_hidden = (hidden_index == 5'd31);
    wire last_output = (output_index == 4'd11);

    wire signed [47:0] acc_plus_product;
    assign acc_plus_product = acc + product;

    wire signed [47:0] hidden_final, output_final;
    assign hidden_final = acc_plus_product + bias_h_ext;
    assign output_final = acc_plus_product + bias_o_ext;

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

    assign acc_next = (state == IDLE)                  ? 48'd0
                    : (state == HIDDEN && last_input)  ? 48'd0
                    : (state == HIDDEN)                ? acc_plus_product
                    : (state == OUTPUT && last_hidden) ? 48'd0
                    : (state == OUTPUT)                ? acc_plus_product
                    :                                   48'd0;

    generate
        for (g = 0; g < 32; g = g + 1) begin : hidden_out_next_logic
            assign hidden_out_en[g]   = (state == HIDDEN) && last_input
                                        && (hidden_index == g);
            assign hidden_out_next[g] = (hidden_final > 0)
                                      ? hidden_final[43:12]
                                      : 32'd0;
        end
    endgenerate

    assign new_note_next = (state == IDLE)                  ? 12'd0
                         : (state == OUTPUT && last_hidden) ? (new_note_reg
                             | ((output_final > 0 ? 12'd1 : 12'd0) << output_index))
                         :                                    new_note_reg;

    assign nn_done_next = (state == DONE) ? 1'b1 : 1'b0;

    // ── debug ─────────────────────────────────────────────────────────────
    always @(posedge clk) begin
        // print every non-zero product for neurons 0-3
        if (state == HIDDEN && hidden_index <= 3 && product != 0)
            $display("h=%0d i=%0d w=%d c=%b p=%d acc_after=%d",
                hidden_index, input_index,
                weight_val, ctxt[input_index],
                product, acc_plus_product);

        // print hidden_final for neurons 0-3
        if (state == HIDDEN && last_input && hidden_index <= 3)
            $display("[HIDDEN %0d] hidden_final=%d stored=%d",
                hidden_index, hidden_final,
                (hidden_final > 0) ? hidden_final[43:12] : 32'd0);

        // print hidden_out after all neurons done
        if (state == HIDDEN && last_input && last_hidden) begin
            $display("[HIDDEN done] hidden_out[0]=%d (python 0)", hidden_out[0]);
            $display("[HIDDEN done] hidden_out[1]=%d (python 0)", hidden_out[1]);
            $display("[HIDDEN done] hidden_out[2]=%d (python 2)", hidden_out[2]);
            $display("[HIDDEN done] hidden_out[3]=%d (python 1)", hidden_out[3]);
        end

        if (state == OUTPUT && last_hidden)
            $display("[OUTPUT %0d] output_final=%d bit=%b",
                output_index, output_final,
                (output_final > 0) ? 1'b1 : 1'b0);

        if (state == DONE)
            $display("[DONE] new_note=%b note=%0d dur=%0d",
                new_note_reg, new_note_reg[5:0], new_note_reg[11:6]);
    end

endmodule


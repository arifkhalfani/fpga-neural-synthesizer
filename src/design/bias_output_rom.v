module bias_output_rom (
    input  wire [3:0] addr,
    output reg  [15:0] data
);
    always @(*) begin
        case (addr)
            4'd0: data = 16'h0309;
            4'd1: data = 16'hfe6d;
            4'd2: data = 16'hfebf;
            4'd3: data = 16'hfe2f;
            4'd4: data = 16'h02a8;
            4'd5: data = 16'h0249;
            4'd6: data = 16'h00e6;
            4'd7: data = 16'h00d7;
            4'd8: data = 16'h01f3;
            4'd9: data = 16'hfec8;
            4'd10: data = 16'hfd47;
            4'd11: data = 16'h024c;
            default: data = 16'h0000;
        endcase
    end
endmodule

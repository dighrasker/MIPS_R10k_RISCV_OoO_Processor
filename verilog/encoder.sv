module encoder #(
)(
    input  wire [`PHYS_REG_SZ_R10K-1:0] in,                    // N-bit input
    output reg  [`PHYS_REG_ID_BITS-1:0] out                   // Encoded output
);

    integer i;
    
    always @(*) begin
        out   = 0;
        for (i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            if (in[i]) begin
                out   = i[`PHYS_REG_ID_BITS-1:0];  // Assign the index as output
            end
        end
    end
endmodule
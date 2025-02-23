module CompleteList #(
    parameter LENGTH = `PHYS_REG_SZ_R10K,
    parameter LENGTH_BITS = `PHYS_REG_ID_BITS
) (
    input   clock,
    input   reset,
    input  PHYS_REG_IDX_BIG    [`N-1:0] inputs_completing;
    input  PHYS_REG_IDX_BIG    [`N-1:0] inputs_retiring;
    output logic           [LENGTH-1:0] complete
);

    logic [LENGTH-1:0] next_complete;

    always_comb begin
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                if (inputs_completing[j] == i) begin
                    next_complete[i] = 1'b1;
                end
            end

            for (int j = 0; j < `N; ++j) begin
                if (inputs_retiring[j] == i) begin
                    next_complete[i] = 1'b0;
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            complete <= '0;
        end else begin
            complete <= next_complete
        end
    end

            // if (inputs_completing[i] != `PHYS_REG_SZ_R10K) begin
            //     next_complete[inputs_completing[i]] = 1'b1; // this is not synthesizable
            // end
endmodule
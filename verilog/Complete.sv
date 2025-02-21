module CompleteList #(
    parameter LENGTH = `PHYS_REG_SZ_R10K,
    parameter LENGTH_BITS = `PHYS_REG_ID_BITS
) (
    input   clock,
    input   reset,
    input  PHYS_REG_IDX    [`N-1:0] newly_completed;
    input  logic           [`N-1:0] valid_completes;
    //outputs??
);

    logic [LENGTH-1:0] complete, next_complete;

    always_comb begin
    
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            complete <= '0;
        end else begin
            complete <= next_complete
        end
    end

endmodule
module CompleteList #(
    parameter LENGTH = `PHYS_REG_SZ_R10K,
    parameter LENGTH_BITS = `PHYS_REG_ID_BITS
) (
    input   clock,
    input   reset,
    input  PHYS_REG_IDX        [`N-1:0] inputs_completing,    // phys reg indexes that are being completed (T_new)
    input  logic [`NUM_SCALAR_BITS-1:0] num_completing_valid, // number of retiring phys reg (T_New)
    input  PHYS_REG_IDX        [`N-1:0] inputs_retiring,      // phy reg indexes that are being retired (T_old)
    input  logic [`NUM_SCALAR_BITS-1:0] num_retiring_valid,   // number of retiring phys reg (T_old)
    output logic           [LENGTH-1:0] complete_list         // bitvector of the phys reg that are complete
);

    logic [LENGTH-1:0] next_complete_list;

    generate 
        next_complete = complete;
        for (genvar i = 0; i < `N; ++i) begin
            if (i < num_completing_valid) begin // TODO: build decoder if necessary
                next_complete_list[inputs_completing[i]] = 1'b1;
            end
        end

        for (genvar i = 0; i < `N; ++i) begin
            if (i < num_retiring_valid) begin // TODO: build decoder if necessary
                next_complete_list[inputs_retiring[i]] = 1'b0;
            end
        end
    endgenerate
    
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
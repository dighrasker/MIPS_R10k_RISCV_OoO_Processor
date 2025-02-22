module RS #(
    localparam NUM_SCALAR_BITS = $clog2(`N+1)
) (
    input  logic                        clock, 
    input  logic                        reset,
    input  logic              [`N-1:0]  valid_entries
    input  RS_ENTRY_PACKET    [`N-1:0]  rs_entries, // Write data
    input  PHYS_REG_IDX       [`N-1:0]  CDB_tags,
    input  logic [NUM_SCALAR_BITS-1:0]  num_in_CDB,
    input  logic              [`N-1:0]  free_FUs,

    output RS_EXIT_PACKET [`RS_SZ-1:0]  rs_outputs,
    output logic          [`RS_SZ-1:0]  outputs_valid

);
    // Main RS Data Here
    RS_ENTRY_PACKET [`RS_SZ-1:0] rs;

    always_comb begin
    
    end

    always_ff @(posedge clock) begin
        if (reset) begin
        
        end else begin
            
        end
    end

endmodule
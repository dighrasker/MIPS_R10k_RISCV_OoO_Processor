module RS #(
) (
    input  logic                        clock, 
    input  logic                        reset,

    // ------ TO/FROM: DISPATCH ------- //
    input  logic   [NUM_SCALAR_BITS:0] inputs_valid     // Number of input RS packets
    input  RS_ENTRY_PACKET    [`N-1:0] rs_entries,      // Input RS packets data
    output logic [NUM_SCALAR_BITS-1:0] spots,           // Number of spots 

    // --------- FROM: CDB ------------ //
    input  PHYS_REG_IDX       [`N-1:0] CDB_tags,        // Tags that are broadcasted from the CDB
    input  logic [NUM_SCALAR_BITS-1:0] CDB_valid,       // 
    
    // ------- TO/FROM: ISSUE --------- //
    input  logic          [`RS_SZ-1:0] outputs_issuing, // One-hot bitvecotr of RS packets issued
    output logic          [`RS_SZ-1:0] outputs_valid,   // One-hot bitvector of output RS packets
    output RS_EXIT_PACKET [`RS_SZ-1:0] rs_outputs,      // Output RS packets data
);

    // Main RS Data Here
    RS_ENTRY_PACKET [`RS_SZ-1:0] RS;
    logic [`RS_SZ-1:0] RS_valid;

    always_comb begin
        
    end

    always_ff @(posedge clock) begin
        if (reset) begin
        
        end else begin
            
        end
    end

endmodule
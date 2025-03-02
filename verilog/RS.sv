`include "sys_defs.svh"

module RS #(
) (
    input  logic                        clock, 
    input  logic                        reset,

    // ------ TO/FROM: DISPATCH ------- //
    input  logic   [`NUM_SCALAR_BITS:0] num_dispatched,      // Number of input RS packets actually coming from dispatch
    input  RS_PACKET           [`N-1:0] rs_entries,          // Input RS packets data
    output logic [`NUM_SCALAR_BITS-1:0] rs_spots,            // Number of spots       

    // --------- FROM: CDB ------------ //
    input  PHYS_REG_IDX        [`N-1:0] CDB_tags,            // Tags that are broadcasted from the CDB
    input  logic  [NUM_SCALAR_BITS-1:0] CDB_valid,           // 1 is the broadcast is valid
    
    // ------- TO/FROM: ISSUE --------- //
    input  logic           [`RS_SZ-1:0] rs_data_issuing,      // bit vector of rs_data that is being issued by issue stage
    output RS_PACKET       [`RS_SZ-1:0] RS_data,              // The entire RS data 

    // ------- FROM: EXECUTE (BRANCH) --------- //
    input B_MASK                        b_mm_resolve,         // b_mask_mask to resolve
    input logic                         b_mm_mispred          // 1 if mispredict happens
);

    // Main RS Data Here
    // RS_ENTRY_PACKET [`RS_SZ-1:0] RS;
    logic [`RS_SZ-1:0] RS_valid;

    always_comb begin
        
    end

    always_ff @(posedge clock) begin
        if (reset) begin
        
        end else begin
            
        end
    end

endmodule
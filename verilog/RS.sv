module RS #(
) (
    input  logic                        clock, 
    input  logic                        reset,

    // ------ TO/FROM: DISPATCH ------- //
    input  logic   [NUM_SCALAR_BITS:0] rs_entries_valid     // Number of input RS packets actually coming from dispatch
    input  RS_PACKET    [`N-1:0] rs_entries,         // Input RS packets data
    output logic [NUM_SCALAR_BITS-1:0] rs_spots,           // Number of spots       

    // --------- FROM: CDB ------------ //
    input  PHYS_REG_IDX       [`N-1:0] CDB_tags,        // Tags that are broadcasted from the CDB
    input  logic [NUM_SCALAR_BITS-1:0] CDB_valid,       // 
    
    // ------- TO/FROM: ISSUE --------- //
    output logic          [`N-1:0][`RS-SZ-1:0] ALU_grant_bus,
    output logic          [`N-1:0][`RS-SZ-1:0] Branch_grant_bus,
    output logic          [`N-1:0][`RS-SZ-1:0] Mult_grant_bus,
    output logic          [`N-1:0][`RS-SZ-1:0] LD_ST_grant_bus,
    output RS_PACKET              [`RS_SZ-1:0] rs_outputs,         // Output RS packets data

    // ------- FROM: EXECUTE --------- //
    input logic                     [] b_mask_mask_in
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
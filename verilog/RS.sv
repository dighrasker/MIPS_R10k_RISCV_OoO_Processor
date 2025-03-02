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
    input  logic [`NUM_SCALAR_BITS-1:0] CDB_valid,           // 1 is the broadcast is valid
    
    // ------- TO/FROM: ISSUE --------- //
    input  logic           [`RS_SZ-1:0] rs_data_issuing,      // bit vector of rs_data that is being issued by issue stage
    output RS_PACKET       [`RS_SZ-1:0] RS_data,              // The entire RS data 
    output logic           [`RS_SZ-1:0] RS_valid_next,        // 1 if RS data is valid

    // ------- FROM: EXECUTE (BRANCH) --------- //
    input B_MASK_MASK                   b_mm_resolve,         // b_mask_mask to resolve
    input logic                         b_mm_mispred          // 1 if mispredict happens
);

    logic [`RS_SZ-1:0] RS_valid;
    //Need to handle corner case where RS_SZ is odd - maybe with genvar
    logic [`NUM_SCALAR_BITS-1:0] temp_rs_spots [`RS_SZ/2-1:0];

    always_comb begin
        CountOnes #(`RS_SZ) RS_Counter (
            .bit_array(RS_valid)
            .count_ones(rs_spots)
        );
        for(int i = 0; i < `RS_SZ; ++i) begin
            //squashing step
            RS_valid_next[i] = (b_mm_mispred && (b_mm_resolve & RS_data[i].b_mask)) ? 0 : RS_valid[i];
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            RS_data <= '0;
            RS_valid <= '0;
        end else begin
            RS_valid <= RS_valid_next & ~(rs_data_issuing);
            for(int i = 0; i < `RS_SZ; ++i) begin
                //resolving mask
                RS_data[i].b_mask <= RS_data[i].b_mask & ~(b_mm_resolve);
            end
            for(int i = 0; i < `N; ++i) begin
                if(CDB_valid[i]) begin
                    for(int j = 0; j < `RS_SZ; ++i)begin
                        RS_data[j].Source1_ready <= RS_data[j].Source1 == CDB_tags[i];
                        RS_data[j].Source2_ready <= RS_data[j].Source2 == CDB_tags[i];
                    end
                end 
            end
        end
    end

endmodule
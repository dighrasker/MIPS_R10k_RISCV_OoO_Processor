`include "verilog/sys_defs.svh"

module btb #(
) (
    input   logic                                clock, 
    input   logic                                reset,

    // ------------- TO/FROM FETCH -------------- //
    input   ADDR                        [`N-1:0] PCs,
    output  ADDR                        [`N-1:0] target_PCs,
    output  logic                       [`N-1:0] btb_hit,

    // ------------- TO/FROM BRANCH STACK -------------- //
    input  logic                                 resolving_valid,
    input  ADDR                                  resolving_target_PC,
    //NOTE: This is not necessarily PC restore, this is whatever the target address is for a valid resolving branch

`ifdef DEBUG
    , output BTB_DEBUG                            btb_debug //define BP_DEBUG later sys defs
`endif
); 


BTB_CACHE_LINE []
logic [`HISTORY_BITS-1:0][`CTR_SZ-1:0] pattern_hist_table, next_pattern_hist_table; //history bits index, saturating ctr output

//should set CTR_SZ to 2

always_comb begin
    next_pattern_hist_table = pattern_hist_table;
    next_branch_hist_table = branch_hist_table; 

    if (branch_valid) begin

        //send prediction to fetch
        predict_taken = pattern_hist_table[branch_hist_table[branch_PC]][`CTR_SZ-1]; //bit 1 is T/NT on the saturating counter

        //update BHT
        next_branch_hist_table[branch_PC] = ((branch_hist_table[branch_pc] << 1) | actual_taken);
        
        //update PHT
        if (actual_taken) begin
            next_pattern_hist_table[branch_hist_table[branch_PC]] = pattern_hist_table[branch_hist_table[branch_PC]] + 1'b1;
        end else if (~actual_taken) begin
            next_pattern_hist_table[branch_hist_table[branch_PC]] = pattern_hist_table[branch_hist_table[branch_PC]] - 1'b1;
        end

    end 
end


always_ff @(posedge clock) begin
    if (reset) begin
        branch_hist_table <= '0;
        pattern_hist_table <= '0;
    end else begin
        branch_hist_table <= next_branch_hist_table;
        pattern_hist_table <= next_pattern_hist_table;
    end
end


endmodule
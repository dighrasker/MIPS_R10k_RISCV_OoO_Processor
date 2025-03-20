`include "verilog/sys_defs.svh"

module branchpredictor #(
) (
    input   logic                                clock, 
    input   logic                                reset,

    // ------------- TO/FROM FETCH or BTB -------------- //
    input   PC                                   branch_PC,
    input   logic                                branch_valid,

    
    output  logic                                predict_taken,

    // ------------- TO/FROM EXECUTE(complete) -------------- //
    input   logic                                actual_taken, //or whatever has the actual taken

`ifdef DEBUG
    , output BP_DEBUG                            bp_debug //define BP_DEBUG later sys defs
`endif
); 


//simple PAg predictor -- still need BTB 
//need to define parameters for branch and pattern history table sizes

logic [`ADDR-1:0][`HISTORY_BITS-1:0] branch_hist_table, next_branch_hist_table; //PC index, history output
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
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
    input  logic                                 resolving_valid_branch,
    input  ADDR                                  resolving_target_PC,
    // input  BTB_SET_IDX                           btb_set_idx,       // might not need if we have branch_PC
    input  ADDR                                  resolving_branch_PC,
    //NOTE: This is not necessarily PC restore, this is whatever the target address is for a valid resolving branch

`ifdef DEBUG
    , output BTB_DEBUG                            btb_debug //define BP_DEBUG later sys defs
`endif
); 


BTB_SET_PACKET [`BTB_NUM_SETS-1:0]  btb_set_entries, next_btb_set_entries;


// Write BTB logic

BTB_SET_IDX wr_btb_set_idx;
BTB_TAG wr_btb_tag;

assign wr_btb_set_idx = resolving_branch_PC[`BTB_SET_IDX_BITS-1:0];
assign wr_btb_tag = resolving_branch_PC[31:`BTB_SET_IDX_BITS];

logic [`NUM_BTB_WAYS-1:0] found;

always_comb begin
    next_btb_set_entries = btb_set_entries;
    found = '0;
    if(resolving_valid_branch) begin
        for(int i = 0; i < `NUM_BTB_WAYS; i++) begin
            if(btb_set_entries[wr_btb_set_idx].btb_entries[i].btb_tag == wr_btb_tag) begin
                found[i] = 1'b1;
                next_btb_set_entries[wr_btb_set_idx].btb_entries[i].target_PC = resolving_target_PC;
                next_btb_set_entries[wr_btb_set_idx].btb_entries[i].valid = 1'b1;
                //update LRU
                next_btb_set_entries[wr_btb_set_idx].btb_entries[i].LRU = `NUM_BTB_WAYS - 1'b1;
                for(int j = 0; j < `NUM_BTB_WAYS; j++) begin
                    if(j != i) begin
                        next_btb_set_entries[wr_btb_set_idx].btb_entries[j].LRU--;
                    end
                end
            end
        end
        // btb miss write 
        if(~(|found)) begin
            //search for LRU
            for(int i = 0; i < `NUM_BTB_WAYS; i++) begin
                if(!btb_set_entries[wr_btb_set_idx].btb_entries[i].LRU) begin
                    next_btb_set_entries[wr_btb_set_idx].btb_entries[i].btb_tag = wr_btb_tag;
                    next_btb_set_entries[wr_btb_set_idx].btb_entries[i].target_PC = resolving_target_PC;
                    next_btb_set_entries[wr_btb_set_idx].btb_entries[i].valid = 1'b1;
                    //update LRU
                    next_btb_set_entries[wr_btb_set_idx].btb_entries[i].LRU = `NUM_BTB_WAYS - 1'b1;
                    for(int j = 0; j < `NUM_BTB_WAYS; j++) begin
                        if(j != i) begin
                            next_btb_set_entries[wr_btb_set_idx].btb_entries[j].LRU--;
                        end
                    end
                end
            end
        end
    end
end

// Read BTB logic

BTB_SET_IDX [`N-1:0] rd_btb_set_idx;
BTB_TAG [`N-1:0] rd_btb_tag;

always_comb begin
    for(int i = 0; i < `N; i++) begin
        rd_btb_set_idx = PCs[`BTB_SET_IDX_BITS-1:0];
        rd_btb_tag = PCs[31:`BTB_SET_IDX_BITS];
        for(int j = 0; j < `NUM_BTB_WAYS; j++) begin
            if(btb_set_entries[rd_btb_set_idx].btb_entries[j].btb_tag == rd_btb_tag[i]) begin
                target_PCs[i] = btb_set_entries[rd_btb_set_idx].btb_entries[j].target_PC;
                btb_hit[i] = 1'b1;
            end
        end
    end
end

always_comb begin

end

always_ff@(posedge clock) begin
    if(reset) begin
        btb_set_entries <= '0;
    end else begin
        btb_set_entries <= next_btb_set_entries;
    end
end



endmodule
`include "verilog/sys_defs.svh"

module branchstack #(
) (
    input   logic                                clock, 
    input   logic                                reset,
    // ------------- TO ALL -------------- //
    output  logic                                restore_valid,
    // ------------- TO FETCH -------------- //
    output  ADDR                                 PC_restore,
    // ------------- FROM COMPLETE -------------- //
    input   BRANCH_REG_PACKET                    branch_completing,
    
    // ------------- TO ROB ------------------- //
    output  logic             [`ROB_SZ_BITS-1:0] rob_tail_restore,
    // ------------- TO FREDDY LIST ----------- //
    output  logic        [`PHYS_REG_SZ_R10K-1:0] freelist_restore,
    // ------------- TO/FROM DISPATCH -------------- //
    input   BS_ENTRY_PACKET  [`B_MASK_WIDTH-1:0] branch_stack_entries,
    input   B_MASK                               next_b_mask,
    output  PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table_restore,     
    output  B_MASK                               b_mask_combinational,
    output  logic         [`NUM_B_MASK_BITS-1:0] branch_stack_spots,

    // ------------- TO RS/EXECUTE -------------- //
    output  B_MASK                               b_mm_out

    // ------------- TO LSQ ------------------ //
    // output logic                                 lsq_tail_restore  //<--- STILL NEED TO UPDATE THIS
    // branch prediction repair?
`ifdef DEBUG
    , output BS_DEBUG                            bs_debug
`endif
); 

    B_MASK_MASK   b_mm_resolve;
    logic         b_mm_mispred;
    ADDR          target_PC;
    logic         taken;


    assign b_mm_resolve = branch_completing[i].b_mm;
    assign b_mm_mispred = branch_completing[i].bm_mispred;
    assign target_PC = branch_completing[i].result;
    assign taken = branch_completing[i].taken;


    BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack, next_branch_stack;
    logic [`NUM_B_MASK_BITS-1:0] next_branch_stack_spots;
    
    B_MASK b_mask_reg;
    
    always_comb begin 
        next_branch_stack = branch_stack;
        b_mask_combinational = b_mask_reg;
        for (int i = 0; i < `B_MASK_WIDTH; i++) begin
            if ((b_mm_mispred && ((branch_stack[i].b_m & b_mm_resolve) != 0)) | b_mm_resolve[i]) begin
                b_mask_combinational[i] = 0;
                next_branch_stack[i] = 0;
            end else begin
                next_branch_stack[i].b_m = branch_stack[i].b_m & ~b_mm_resolve;
            end
        end
    end

    always_comb begin
        
        restore_valid = 0;
        PC_restore = 0;
        rob_tail_restore = 0;
        freelist_restore = 0;
        map_table_restore = 0;
        b_mm_out = '0;
        
        for (int i = 0; i < `B_MASK_WIDTH; i++) begin
            if (b_mm_resolve[i] && b_mask_reg[i]) begin
                b_mm_out[i] = 1'b1;
                if (b_mm_mispred) begin
                    restore_valid = 1;
                    PC_restore = taken ? branch_stack[i].recovery_PC : target_PC;
                    rob_tail_restore = branch_stack[i].rob_tail;
                    freelist_restore = branch_stack[i].free_list;
                    map_table_restore = branch_stack[i].map_table;
                end
            end
        end
        
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            branch_stack_spots <= `B_MASK_WIDTH;
            b_mask_reg <= 0;
            branch_stack <= 0;
        end else begin
            branch_stack_spots <= next_branch_stack_spots;
            b_mask_reg <= next_b_mask;
            for (int i = 0; i < `B_MASK_WIDTH; i++) begin
                branch_stack[i] <= next_branch_stack[i] | branch_stack_entries[i];
            end
        end
    end

`ifdef DEBUG
    assign bs_debug.branch_stack = branch_stack;
    assign bs_debug.b_mask_reg = b_mask_reg;
    assign bs_debug.next_branch_stack = next_branch_stack;
`endif

endmodule
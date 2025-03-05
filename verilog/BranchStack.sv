`include "verilog/sys_defs.svh"

module BranchStack #(
) (
    input   logic                                clock, 
    input   logic                                reset,
    // ------------- TO FETCH -------------- //
    output  ADDR                                 PC_restore,
    output  logic                                PC_restore_valid,
    // ------------- FROM COMPLETE -------------- //
    input   B_MASK_MASK                          b_mm_resolve,
    input   logic                                b_mm_mispred,
    // ------------- TO ROB ------------------- //
    output  logic             [`ROB_SZ_BITS-1:0] rob_tail_restore,
    output  logic                                rob_tail_restore_valid,
    // ------------- TO FREDDY LIST ----------- //
    output  logic        [`PHYS_REG_SZ_R10K-1:0] freelist_restore,
    output  logic                                freelist_restore_valid,
    // ------------- TO/FROM DISPATCH -------------- //
    input   BS_ENTRY_PACKET  [`B_MASK_WIDTH-1:0] branch_stack_entries,
    input   logic            [`B_MASK_WIDTH-1:0] next_b_mask,
    output  PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table_restore,     // exit packet: recovery_PC, rob_tail, map_table, freelist
    output  logic                                map_table_restore_valid,
    output  B_MASK                               b_mask_combinational,
    output  logic         [`NUM_B_MASK_BITS-1:0] branch_stack_spots//,
    // ------------- TO LSQ ------------------ //
    // output logic                                 lsq_tail_restore  //<--- STILL NEED TO UPDATE THIS
    // branch prediction repair?
`ifdef DEBUG
    , output BS_DEBUG                            bs_debug
`endif
); 

    BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack, next_branch_stack;
    
    B_MASK b_mask_reg;
    
    logic [`NUM_B_MASK_BITS-1:0] next_branch_stack_spots; // might not care

    always_comb begin
        next_branch_stack_spots = 0;
        // Just counting spots. Maybe could be done better? Also, consider genvar but genvar doesn't work in comb block apparently. More research needs to be done
        for (int i = 0; i < `B_MASK_WIDTH; i++) begin
            next_branch_stack_spots += ~next_b_mask[i];
        end
    end
    
    always_comb begin 
        next_branch_stack = branch_stack;
        b_mask_combinational = b_mask_reg;
        for (int i = 0; i < `B_MASK_WIDTH; i++) begin
            if ((b_mm_mispred & ((branch_stack[i].b_m & b_mm_resolve) != 0)) | b_mm_resolve[i]) begin
                b_mask_combinational[i] = 0;
                next_branch_stack[i] = 0;
            end else begin
                next_branch_stack[i].b_m = branch_stack[i].b_m & ~b_mm_resolve;
            end
        end
    end

    always_comb begin
        
        PC_restore = 0;
        PC_restore_valid = 0;
        rob_tail_restore = 0;
        rob_tail_restore_valid = 0;
        freelist_restore = 0;
        freelist_restore_valid = 0;
        map_table_restore = 0;
        map_table_restore_valid = 0;
        
        for (int i = 0; i < `B_MASK_WIDTH; i++) begin
            if (b_mm_mispred && b_mm_resolve[i]) begin
                PC_restore = branch_stack[i].recovery_PC;
                PC_restore_valid = 1;
                rob_tail_restore = branch_stack[i].rob_tail;
                rob_tail_restore_valid = 1;
                freelist_restore = branch_stack[i].free_list;
                freelist_restore_valid = 1;
                map_table_restore = branch_stack[i].map_table;
                map_table_restore_valid = 1;
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
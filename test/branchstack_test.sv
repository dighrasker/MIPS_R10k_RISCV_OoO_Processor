// branchstack module testbench
// This module generates the test vectors

`include "verilog/sys_defs.svh"
`include "test/freddylist_sva.svh"

`define DEBUG

module BranchStack_test ();

    logic                                clock; 
    logic                                reset;
    // ------------- TO FETCH -------------- //
    ADDR                                 PC_restore;
    logic                                PC_restore_valid;
    // ------------- FROM COMPLETE -------------- //
    B_MASK_MASK                          b_mm_resolve;
    logic                                b_mm_mispred;
    // ------------- TO ROB ------------------- //
    logic             [`ROB_SZ_BITS-1:0] rob_tail_restore;
    logic                                rob_tail_restore_valid;
    // ------------- TO FREDDY LIST ----------- //
    logic        [`PHYS_REG_SZ_R10K-1:0] freelist_restore;
    logic                                freelist_restore_valid;
    // ------------- TO/FROM DISPATCH -------------- //
    BS_ENTRY_PACKET  [`B_MASK_WIDTH-1:0] branch_stack_entries;
    logic            [`B_MASK_WIDTH-1:0] next_b_mask;
    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table_restore;
    logic                                map_table_restore_valid;
    B_MASK                               b_mask_combinational;

    BranchStack dut (
        .clock(clock),
        .reset(reset),
        .PC_restore(PC_restore),
        .PC_restore_valid(PC_restore_valid),
        .b_mm_resolve(b_mm_resolve),
        .b_mm_mispred(b_mm_mispred),
        .rob_tail_restore(rob_tail_restore),
        .rob_tail_restore_valid(rob_tail_restore_valid),
        .freelist_restore(freelist_restore),
        .freelist_restore_valid(freelist_restore_valid),
        .branch_stack_entries(branch_stack_entries),
        .next_b_mask(next_b_mask),
        .map_table_restore(map_table_restore),
        .map_table_restore_valid(map_table_restore_valid),
        .b_mask_combinational(b_mask_combinational)
    );

    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end


    // Only recovery PC and b_m is randomize for this purpose
    task randomize_all_bs(output BS_ENTRY_PACKET bs_entries);
        for(int i = 0; i < `B_MASK_WIDTH; ++i) begin
            bs_entries[i].recovery_PC = $urandom;
            bs_entries[i].rob_tail = 0;
            bs_entries[i].free_list = 0;
            bs_entries[i].map_table = 0;
            bs_entries[i].b_m = $urandom;
        end
    endtask

    task randomize_one_hot_bmm(output logic [`B_MASK_WIDTH-1:0] bmm);
        int rand_idx;
        rand_idx = $urandom_range(0, `B_MASK_WIDTH-1);
        bmm = 1'b1 << rand_idx;
    endtask

    task dispatch_based_on_b_mask_combinational(input logic [`B_MASK_WIDTH-1:0] bm_comb, output BS_ENTRY_PACKET bs_entries, output logic [`B_MASK_WIDTH-1:0] next_bm);
        for(int i = 0; i < `B_MASK_WIDTH; ++i) begin
            if(!bm_comb[i]) begin
                bs_entries[i].recovery_PC = $urandom;
                bs_entries[i].b_m = $urandom;
                next_bm[i] = 1'b1;
            end else begin
                bs_entries[i] = 0;
                next_bm[i] = bm_comb[i];
            end
        end
    endtask

    initial begin
        $display("\nStart Testbench");

        clock = 1;
        reset = 1;
        b_mm_resolve = 0;
        b_mm_mispred = 0;
        branch_stack_entries = 0;
        next_b_mask = 0;
        $monitor("  %3d | b_mm_resolve: %b   b_mm_mispred: %0d,   next_b_mask: %b,   b_mask_combinational: %b,",
                  $time,  b_mm_resolve,      b_mm_mispred,        next_b_mask,       b_mask_combinational);

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // fill the branch stack 
        next_b_mask = ~0;
        randomize_all_bs(branch_stack_entries);
        
        @(negedge clock);
        branch_stack_entries = 0;
        
        // ---------- Test 1 ---------- //
        $display("\nTest 1: b_mm_resolve and next_b_mask interaction, no mispredict");
        $display("Randomize b_mm_resolve");

        for(int i = 0; i < 100; ++i) begin
            b_mm_mispred = 0;
            randomize_one_hot_bmm(b_mm_resolve);
            dispatch_based_on_b_mask_combinational(b_mask_combinational, branch_stack_entries, next_b_mask);
            @(negedge clock);
        end

        b_mm_resolve = 0;
        branch_stack_entries = 0;

        @(negedge clock);
        @(negedge clock);

        // ---------- Test 2 ---------- //
        $display("\nTest 2: b_mm_resolve and next_b_mask interaction, yes mispredict");
        $display("Randomize b_mm_resolve");

        for(int i = 0; i < 100; ++i) begin
            b_mm_mispred = 1'b1;
            randomize_one_hot_bmm(b_mm_resolve);
            dispatch_based_on_b_mask_combinational(b_mask_combinational, branch_stack_entries, next_b_mask);
            @(negedge clock);
        end


    end


endmodule
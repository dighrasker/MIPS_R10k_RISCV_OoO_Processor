// ROB module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "verilog/sys_defs.svh"
`include "test/freddylist_sva.svh"

`define DEBUG

module FreddyList_test ();
    logic                        clock; 
    logic                        reset;
    PHYS_REG_IDX           [`N-1:0] phys_reg_completing;    // phys reg indexes that are being completed (T_new)
    logic                  [`N-1:0] completing_valid;       // bit vector of N showing which phys_reg_completing is valid
    // ------------- FROM RETIRE -------------- //
    PHYS_REG_IDX           [`N-1:0] phys_reg_retiring;      // phy reg indexes that are being retired (T_old)
    logic    [`NUM_SCALAR_BITS-1:0] num_retiring_valid;     // number of retiring phys reg (T_old)
    // ------------- FROM BRANCH STACK -------------- //
    logic   [`PHYS_REG_SZ_R10K-1:0] free_list_restore;      // snapshot of freelist at mispredicted branch
    logic                           restore_flag;           // branch mispredict flag
    // ------------- FROM DISPATCH -------------- //
    logic   [`PHYS_REG_SZ_R10K-1:0] updated_free_list;      // freelist from dispatch
    // logic    [`NUM_SCALAR_BITS-1:0] num_dispatched;
    // ------------- TO DISPATCH -------------- //
    PHYS_REG_IDX           [`N-1:0] phys_regs_to_use;       // physical register indices for dispatch to use
    // logic    [`NUM_SCALAR_BITS-1:0] free_list_spots,        // how many physical registers are free
    logic   [`PHYS_REG_SZ_R10K-1:0] free_list;              // bitvector of the phys reg that are complete
    // ------------- TO ISSUE -------------- //
    logic   [`PHYS_REG_SZ_R10K-1:0] complete_list;           // bitvector of the phys reg that are complete

    logic [`PHYS_REG_SZ_R10K-1:0] next_free_list;

    // INSTANCE is from the sys_defs.svh file
    // it renames the module if SYNTH is defined in
    // order to rename the module to FIFO_svsim
    FreddyList dut (
        .clock                  (clock),
        .reset                  (reset),
        .phys_reg_completing    (phys_reg_completing),
        .completing_valid       (completing_valid), 
        .phys_reg_retiring      (phys_reg_retiring),
        .num_retiring_valid     (num_retiring_valid),
        .free_list_restore      (free_list_restore),
        .restore_flag           (restore_flag),
        .updated_free_list      (updated_free_list),
        // .num_dispatched         (num_dispatched),
        .phys_regs_to_use       (phys_regs_to_use),
        .free_list              (free_list),
        .complete_list          (complete_list)
    );
    
    FreddyList_sva DUT_sva (
        .clock                  (clock),
        .reset                  (reset),
        .phys_reg_completing    (phys_reg_completing),
        .completing_valid       (completing_valid), 
        .phys_reg_retiring      (phys_reg_retiring),
        .num_retiring_valid     (num_retiring_valid),
        .free_list_restore      (free_list_restore),
        .restore_flag           (restore_flag),
        .updated_free_list      (updated_free_list),
        // .num_dispatched         (num_dispatched),
        .phys_regs_to_use       (phys_regs_to_use),
        .free_list              (free_list),
        .complete_list          (complete_list)
    );
    
    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    // logic [`N-1:0] [$bits(ROB_ENTRY_PACKET)-`PHYS_REG_ID_BITS-1:0] temp;
    //Generate random numbers for our write data on each cycle
    // always_ff @(negedge clock) begin
    //     //std::randomize(wr_data);
    //     for(int i = 0; i < `N; ++i) begin  
    //         temp[i] = '0;
    //     end
    // end

    // always_comb begin : generateRobInputs 
    //     for(int i = 0; i < `N; ++i) begin
    //         // T_new[i] = (rob_debug.Tail + i)%DEPTH;
    //         // rob_inputs[i].T_new = {T_new[i], temp[i]}; 
    //         rob_inputs[i] = index + i; 
    //         // $display(" rob_inputs[%0d]: %0d, index %d",
    //         //       i,    (i + index),   rob_inputs[i], index);
    //     end
    // end

    PHYS_REG_IDX index;

    initial begin
        $display("\nStart Testbench");

        clock = 1;
        reset = 1;
        $monitor("  %3d | retiring_valid: %0d   restore_flag: %0d,   free_list: %b,   updated_free_list: %b,   difference: %b,   complete_list: %b,   completing_valid: %b",
                  $time,  num_retiring_valid,      restore_flag,       free_list,       updated_free_list,     free_list ^ updated_free_list, complete_list, completing_valid;

        // for (int Index = 0; Index < `N; ++Index) begin
        //     $monitor("Index: %b | rob_inputs: %b   rob_outputs: %b",
        //               Index,      rob_inputs[Index].T_new, rob_outputs[Index].T_new);
        // end

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        updated_free_list = free_list;
        restore_flag = 0;
        completing_valid = 0;
        
        // ---------- Test 1 ---------- //
        $display("\nTest 1: No interaction, updated_free_list copied to free_list");
        $display("Randomize updated_free_list input");
        @(negedge clock);
        num_retiring_valid = 0;
        for (int i = 0; i < 10; ++i) begin
            for(int j = 0; j < `PHYS_REG_SZ_R10K; j++) begin
                updated_free_list[j] = $urandom_range(1);
            end
            @(negedge clock);
        end
        @(negedge clock);


        @(negedge clock);
        
        // ---------- Test 2 ---------- //
        $display("\nTest 2: Updated_free_list and num_retiring_valid interaction");
        updated_free_list = 0;
        @(negedge clock);

        index = 0;
        num_retiring_valid = `N;

        while (index < 12) begin
            updated_free_list = free_list;
            for(int i = 0; i < num_retiring_valid; ++i) begin
                phys_reg_retiring[i] = index + i;
            end
            index = index + num_retiring_valid;
            
            @(negedge clock);
        end

        @(negedge clock);
        num_retiring_valid = 0;

        // ---------- Test 3 ---------- //
        $display("\nTest 3: Testing restoring of old free list");

        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            updated_free_list[i] = $urandom_range(1);
        end

        free_list_restore = updated_free_list;

        @(negedge clock);

        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            updated_free_list[i] = $urandom_range(1);
        end

        @(negedge clock);
        
        restore_flag = 1;
        
        @(negedge clock);

        // ---------- Test 4 ---------- //
        $display("\nTest 4: Testing restoring of old free list and something is retiring");

        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            updated_free_list[i] = $urandom_range(1);
        end

        free_list_restore = updated_free_list;

        @(negedge clock);

        for(int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            updated_free_list[i] = $urandom_range(1);
        end

        @(negedge clock);

        num_retiring_valid = `N;
        for (int i = 0; i < num_retiring_valid; i++) begin
            for (int j = 0; j < `PHYS_REG_SZ_R10K; j++) begin
                if (~updated_free_list[j]) begin
                    updated_free_list[j] = 1;
                    break;
                end
            end
        end

        restore_flag = 1;
        

        // Break
        @(negedge clock);

        restore_flag = 0;
        num_retiring_valid = 0;

        @(negedge clock);

        // ---------- Test 5 ---------- //
        $display("\nTest 5: Complete list changes with completing instructions");

        completing_valid = `1;
        for (int i = 0; i < `N; i++) begin
            if (completing_valid[i]) begin
                for (int j = 0; j < `PHYS_REG_SZ_R10K; j++) begin
                    if (~complete_list[j]) begin
                        phys_reg_completing[j] = 1;
                        break;
                    end
                end
            end
        end

        @(negedge clock);

        $display("\n\033[32m@@@ Passed\033[0m\n");

        $finish;
    end
endmodule

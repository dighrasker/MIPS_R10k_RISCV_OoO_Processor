// ROB module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "verilog/sys_defs.svh"
`include "test/rob_sva.svh"

`define DEBUG

module RS_test ();
    logic                        clock; 
    logic                        reset;

    // ------ TO/FROM: DISPATCH ------- //
    logic   [`NUM_SCALAR_BITS:0] num_dispatched;      // Number of input RS packets actually coming from dispatch
    RS_PACKET           [`N-1:0] rs_entries;          // Input RS packets data
    logic [`NUM_SCALAR_BITS-1:0] rs_spots;            // Number of spots <-- Coded       

    // --------- FROM: CDB ------------ //
    PHYS_REG_IDX        [`N-1:0] CDB_tags;            // Tags that are broadcasted from the CDB
    logic [`NUM_SCALAR_BITS-1:0] CDB_valid;           // 1 is the broadcast is valid
    
    // ------- TO/FROM: ISSUE --------- //
    logic           [`RS_SZ-1:0] rs_data_issuing;      // bit vector of rs_data that is being issued by issue stage
    RS_PACKET       [`RS_SZ-1:0] RS_data;              // The entire RS data 
    logic           [`RS_SZ-1:0] RS_valid_next;        // 1 if RS data is valid <-- Coded

    // ------- FROM: EXECUTE (BRANCH) --------- //
    B_MASK_MASK                   b_mm_resolve;         // b_mask_mask to resolve
    logic                         b_mm_mispred;
    RS_DEBUG                      rs_debug; 

    rs dut (
        .clock             (clock),
        .reset             (reset),
        .num_dispatched    (num_dispatched),
        .rs_entries        (rs_entries), 
        .rs_spots          (rs_spots),
        .CDB_tags          (CDB_tags),
        .CDB_valid         (CDB_valid),
        .rs_data_issuing   (rs_data_issuing),
        .RS_data           (RS_data),
        .RS_valid_next     (RS_valid_next),
        .b_mm_resolve      (b_mm_resolve),
        .b_mm_mispred      (b_mm_mispred)
    );
    
    RS_sva DUT_sva (
        .clock             (clock),
        .reset             (reset),
        .num_dispatched    (num_dispatched),
        .rs_entries        (rs_entries), 
        .rs_spots          (rs_spots),
        .CDB_tags          (CDB_tags),
        .CDB_valid         (CDB_valid),
        .rs_data_issuing   (rs_data_issuing),
        .RS_data           (RS_data),
        .RS_valid_next     (RS_valid_next),
        .b_mm_resolve      (b_mm_resolve),
        .b_mm_mispred      (b_mm_mispred)
    );
    
    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    logic [`N-1:0] [$bits(ROB_ENTRY_PACKET)-`PHYS_REG_ID_BITS-1:0] temp;
    logic [`N-1:0] [`PHYS_REG_ID_BITS - 1:0] T_new;
    //Generate random numbers for our write data on each cycle
    always_ff @(negedge clock) begin
        //std::randomize(wr_data);
        for(int i = 0; i < `N; ++i) begin  
            temp[i] = '0;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            
        end else begin

        end
    end

    /*
    Variables that can be independent (truly randomized)
    1. T_new
    2. Source1
    3. Source2
    4. Op
    5. CDB_tags
    6. CDB_valid
    7. b_mm_mispred

    Variables that are dependent
    1. Source1_ready = (Source1 == CDB_tag)
    2. Source2_ready = (Source2 == CDB_tag)
    3. b_mask &= ~b_mm_resolve
    4. if (B_mm_mispred) --> num_dispatching = 0;
    5. else num_dispatching = (num_dispatching > rs_spots) ? rs_spots : num_dispatching


    
    Things to control
    1. Phys regs tags in src1 and src2 need to be rdy if on cdb
    2. bmasks for incoming entries cannot be 1 in the idx that is
    currrently being resolved
    3. If we have a mispredict, num_dispatching should be 0
    4. Num_dispathing should be <= rs_spots
    */
    
    always_comb begin : generateRSInputs 
        for(int i = 0; i < `N; ++i) begin
            rs_entries[i] = index + i; 

        end
    end


    initial begin
        $display("\nStart Testbench");

        clock = 1;
        reset = 1;
        rob_inputs_valid = 0;
        num_retiring = 0;
        tail_restore = 0;
        tail_restore_valid = 0;

        $monitor("  %3d | inputs_valid: %d   outputs_valid: %d   num_retiring: %d,   spots: %d,   rob_head: %d,   tail: %d,   entries: %d",
                  $time,  rob_inputs_valid,      rob_outputs_valid,      num_retiring,       rob_spots,       rob_debug.head, rob_debug.rob_tail, rob_debug.rob_num_entries);

        // for (int Index = 0; Index < `N; ++Index) begin
        //     $monitor("Index: %b | rob_inputs: %b   rob_outputs: %b",
        //               Index,      rob_inputs[Index].T_new, rob_outputs[Index].T_new);
        // end

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ---------- Test 1 ---------- //
        $display("\nTest 1: Add/Retire 1 entry to/from the ROB");
        $display("Add 1 entry to the ROB");
        rob_inputs_valid = 1;
        @(negedge clock);
        rob_inputs_valid = 0;

        @(negedge clock);

        $display("Retire 1 entry from the ROB");
        num_retiring = 1;
        @(negedge clock);
        num_retiring = 0;

        @(negedge clock);
        
        // ---------- Test 2 ---------- //
        $display("\nTest 2: Add/Retire N entries to/from ROB");

        rob_inputs_valid = `N;
        @(negedge clock);
        rob_inputs_valid = 0;
        
        @(negedge clock);

        num_retiring = `N;
        @(negedge clock);
        num_retiring = 0;

        // ---------- Test 3 ---------- //
        $display("\nTest 3: Simultaneuos Write and Retire");
        $display("Start with N Entries");
        rob_inputs_valid = `N;
        @(negedge clock);
        rob_inputs_valid = 0;

        $display("Write and Retire 1 values");
        rob_inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        rob_inputs_valid = 0;
        num_retiring = 0;
        @(negedge clock);

        $display("Write and Retire N values");
        rob_inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock);
        rob_inputs_valid = 0;
        num_retiring = 0;
        @(negedge clock);

        // ---------- Test 4 ---------- //
        $display("\nTest 4: Write until full");

        while (rob_spots) begin // checking spots > 0
           rob_inputs_valid = rob_spots;
           @(negedge clock);
        end

        // ---------- Test 5 ---------- //
        $display("\nTest 5: Simultaneous Write and Retire when full");
        $display("Write and Retire 1");
        rob_inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        rob_inputs_valid = 0;
        num_retiring = 0;

        $display("Write and Retire N");
        rob_inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock); 
        rob_inputs_valid = 0;
        num_retiring = 0;

        // ---------- Test 6 ---------- //
        $display("\nTest 6: Simultaneous Write and Retire when one less than Full");
        $display("Retire 1");
        num_retiring = 1;
        @(negedge clock);
        num_retiring = 0;

        $display("Write and Retire 1");
        rob_inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        rob_inputs_valid = 0;
        num_retiring = 0;

        $display("Write and Retire N");
        rob_inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock);
        rob_inputs_valid = 0;
        num_retiring = 0;

        // ---------- Test 7 ---------- //
        $display("\nTest 7: Retire until Empty");
        while (rob_outputs_valid) begin // checking spots > 0
           num_retiring = rob_outputs_valid;
           @(negedge clock);
           num_retiring = 0;
        end

        // ---------- Test 8 ---------- //
        $display("\nTest 8: Write and Retire randon number of values");
        @(negedge clock);
        for (int i=0; i <= 100; ++i) begin
            for (int j=0; j <= 100; ++j) begin
                rob_inputs_valid = $urandom_range(rob_spots); 
                num_retiring = $urandom_range(rob_outputs_valid);
                @(negedge clock);
                rob_inputs_valid = 0;
                num_retiring = 0;
            end
        end

        // ---------- Test 9 ---------- //
         $display("\nTest 9: Generic Tail Restore");
         @(negedge clock);
         for (int i=0; i <= 10; ++i) begin
            for (int j=0; j <= 10; ++j) begin
                rob_inputs_valid = $urandom_range(rob_spots); 
                num_retiring = $urandom_range(rob_outputs_valid);
                //tail_restore_valid = $urandom_range(1, 0);
                //tail_restore = $urandom_range(rob_outputs_valid);
                @(negedge clock);
                rob_inputs_valid = 0;
                num_retiring = 0;
            end
        end

        $display("\n\033[32m@@@ Passed\033[0m\n");

        $finish;
    end
endmodule

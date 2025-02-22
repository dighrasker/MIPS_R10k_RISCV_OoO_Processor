// ROB module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "sys_defs.svh"
`include "test/rob_sva.svh"
`define DEBUG

module ROB_test ();

    localparam DEPTH = `ROB_SZ;
    localparam DEPTH_BITS = $clog2(DEPTH);
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1);
    localparam NUM_SCALAR_BITS = $clog2(`N+1);


    logic                        clock; 
    logic                        reset;
    ROB_ENTRY_PACKET    [`N-1:0] rob_inputs; // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    logic  [NUM_SCALAR_BITS-1:0] inputs_valid; // To distinguish invalid instructions being passed in from Dispatch
    ROB_EXIT_PACKET     [`N-1:0] rob_outputs; // For retire to check eligibility
    logic  [NUM_SCALAR_BITS-1:0] outputs_valid; // If not all N rob entries are valid entries they should not be considered
    logic  [NUM_SCALAR_BITS-1:0] num_retiring; // Retire module tells the ROB how many entries can be cleared
    logic  [NUM_SCALAR_BITS-1:0] spots;
    ROB_DEBUG                    rob_debug;



    // variable to count values written to FIFO
    int cnt;

    // INSTANCE is from the sys_defs.svh file
    // it renames the module if SYNTH is defined in
    // order to rename the module to FIFO_svsim
    ROB #(
        .DEPTH(DEPTH)
    ) dut (
        .clock         (clock),
        .reset         (reset),
        .rob_inputs    (rob_inputs),
        .inputs_valid  (inputs_valid), 
        .rob_outputs   (rob_outputs),
        .outputs_valid (outputs_valid),
        .num_retiring  (num_retiring),
        .spots         (spots),
        .rob_debug     (rob_debug)
    );

    bind dut ROB_sva #(
        .DEPTH(DEPTH)) 
    DUT_sva (.*);

    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    logic [`N-1:0] [$bits(ROB_ENTRY_PACKET)-`PHYS_REG_ID_BITS-1:0] temp;
    logic [`N-1:0] [`PHYS_REG_ID_BITS - 1:0] T_new;
    //Generate random numbers for our write data on each cycle
    // always_ff @(negedge clock) begin
    //     //std::randomize(wr_data);
    //     for(int i = 0; i < `N; ++i) begin  
    //         temp[i] = '0;
    //     end
    // end

    always_comb begin : generateRobInputs 
        for(int i = 0; i < `N; ++i) begin
            T_new[i] = (rob_debug.Tail + i)%DEPTH;
            // rob_inputs[i].T_new = {T_new[i], temp[i]}; 
            rob_inputs[i].T_new = T_new[i]; 
        end
    end

    initial begin
        $display("\nStart Testbench");

        clock = 1;
        reset = 1;
        inputs_valid = 0;
        num_retiring = 0;

        $monitor("  %3d | inputs_valid: %b   outputs_valid: %b   num_retiring: %b   spots: %b,   rob_head: %b,   tail: %b,   entries: %b",
                  $time,  inputs_valid,      outputs_valid,      num_retiring,      spots,       rob_debug.Head, rob_debug.Tail, rob_debug.num_entries);

        // for (int Index = 0; Index < `N; ++Index) begin
        //     $monitor("Index: %b | rob_inputs: %b   rob_outputs: %b",
        //               Index,      rob_inputs[Index].T_new, rob_outputs[Index].T_new);
        // end

        @(negedge clock);
        @(negedge clock);
        reset = 0;

        // ---------- Test 1 ---------- //
        $display("\nTest 1: Add/Retire 1 entry to/from the ROB");
        inputs_valid = 1;
        @(negedge clock);
        inputs_valid = 0;

        @(negedge clock);
        num_retiring = 1;

        @(negedge clock);
        num_retiring = 0;

        @(negedge clock);
        
        // ---------- Test 2 ---------- //
        $display("\nTest 2: Add/Retire N entries to/from ROB");

        inputs_valid = `N;
        @(negedge clock);
        inputs_valid = 0;
        
        @(negedge clock);

        num_retiring = `N;
        @(negedge clock);
        num_retiring = 0;

        // ---------- Test 3 ---------- //
        $display("\nTest 3: Simultaneuos Write and Retire");
        $display("Start with N Entries");
        inputs_valid = `N;
        @(negedge clock);
        inputs_valid = 0;

        $display("Write and Retire 1 values");
        inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        inputs_valid = 0;
        num_retiring = 0;
        @(negedge clock);

        $display("Write and Retire N values");
        inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock);
        inputs_valid = 0;
        num_retiring = 0;
        @(negedge clock);

        // ---------- Test 4 ---------- //
        $display("\nTest 4: Write until full");

        while (spots) begin // checking spots > 0
           inputs_valid = spots;
           @(negedge clock);
        end

        // ---------- Test 5 ---------- //
        $display("\nTest 5: Simultaneous Write and Retire when full");
        $display("Write and Retire 1");
        inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        inputs_valid = 0;
        num_retiring = 0;

        $display("Write and Retire N");
        inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock); 
        inputs_valid = 0;
        num_retiring = 0;

        // ---------- Test 6 ---------- //
        $display("\nTest 6: Simultaneous Write and Retire when one less than Full");
        $display("Retire 1");
        num_retiring = 1;
        @(negedge clock);
        num_retiring = 0;

        $display("Write and Retire 1");
        inputs_valid = 1;
        num_retiring = 1;
        @(negedge clock);
        inputs_valid = 0;
        num_retiring = 0;

        $display("Write and Retire N");
        inputs_valid = `N;
        num_retiring = `N;
        @(negedge clock);
        inputs_valid = 0;
        num_retiring = 0;

        // ---------- Test 7 ---------- //
        $display("\nTest 7: Retire until Empty");
        while (outputs_valid) begin // checking spots > 0
           num_retiring = outputs_valid;
           @(negedge clock);
           num_retiring = 0;
        end

        // ---------- Test 8 ---------- //
        $display("\nTest 8: Write and Retire randon number of values");
        @(negedge clock);
        for (int i=0; i <= 100; ++i) begin
            for (int j=0; j <= 100; ++j) begin
                inputs_valid = $urandom_range(spots); 
                num_retiring = $urandom_range(outputs_valid);
                @(negedge clock);
                inputs_valid = 0;
                num_retiring = 0;
            end
        end

        $display("\n\033[32m@@@ Passed\033[0m\n");

        $finish;
    end

endmodule

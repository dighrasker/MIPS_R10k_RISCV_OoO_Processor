// ROB module testbench
// This module generates the test vectors
// Correctness checking is in FIFO_sva.svh

`include "verilog/sys_defs.svh"
//`include "test/rob_sva.svh"
//`include "../verilog/rob.sv"
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

    logic [$bits(ROB_ENTRY_PACKET)-1:0] index;

    // INSTANCE is from the sys_defs.svh file
    // it renames the module if SYNTH is defined in
    // order to rename the module to FIFO_svsim
    rob dut (
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
    /*
    bind dut ROB_sva DUT_sva (
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
    */
    always begin
        #(`CLOCK_PERIOD/2) clock = ~clock;
    end

    // logic [`N-1:0] [$bits(ROB_ENTRY_PACKET)-`PHYS_REG_ID_BITS-1:0] temp;
    logic [`N-1:0] [`PHYS_REG_ID_BITS - 1:0] T_new;
    //Generate random numbers for our write data on each cycle
    // always_ff @(negedge clock) begin
    //     //std::randomize(wr_data);
    //     for(int i = 0; i < `N; ++i) begin  
    //         temp[i] = '0;
    //     end
    // end

    always_ff @(posedge clock) begin
        if (reset) begin
            index <= 0;
        end else begin
            index <= index + inputs_valid;
        end
    end

    always_comb begin : generateRobInputs 
        for(int i = 0; i < `N; ++i) begin
            // T_new[i] = (rob_debug.Tail + i)%DEPTH;
            // rob_inputs[i].T_new = {T_new[i], temp[i]}; 
            rob_inputs[i] = index + i; 
            // $display(" rob_inputs[%0d]: %0d, index %d",
            //       i,    (i + index),   rob_inputs[i], index);
        end
    end

    initial begin
        $display("\nStart Testbench");

        clock = 1;
        reset = 1;
        inputs_valid = 0;
        num_retiring = 0;

        $monitor("  %3d | inputs_valid: %d   outputs_valid: %d   num_retiring: %d,   spots: %d,   rob_head: %d,   tail: %d,   entries: %d",
                  $time,  inputs_valid,      outputs_valid,      num_retiring,       spots,       rob_debug.Head, rob_debug.Tail, rob_debug.num_entries);

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
        inputs_valid = 1;
        @(negedge clock);
        inputs_valid = 0;

        @(negedge clock);

        $display("Retire 1 entry from the ROB");
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

    //////////////////////////////////////////
    //                                      //
    //COPIED SVA CODE TO AVOID LINKER ISSUE //                             //
    //                                      //
    //////////////////////////////////////////
    int spots_manual;
    assign spots_manual = rob_debug.Head == rob_debug.Tail && rob_debug.Spots == 0 && rob_debug.num_entries != 0
                            ? 0
                            : DEPTH - ((rob_debug.Tail - rob_debug.Head + DEPTH) % DEPTH) > `N 
                                ? `N
                                : DEPTH - ((rob_debug.Tail - rob_debug.Head + DEPTH) % DEPTH);

    logic [$bits(ROB_ENTRY_PACKET)-1:0] index_SVA;

    always_ff @(posedge clock) begin
        if (reset) begin
            index_SVA <= 0;
        end else begin
            index_SVA <= index_SVA + num_retiring;
        end
    end

    task exit_on_error;
        begin
            $display("\n\033[31m@@@ Failed at time %4d\033[0m\n", $time);
            $finish;
        end
    endtask
    
    always @(posedge clock) begin

    // Check each valid output
        for (int i = 0; i < outputs_valid; i++) begin
            assert (reset || rob_outputs[i] == (i + index_SVA))
                else begin
                    $error("Mismatch on rob_outputs[%0d]: expected %0d, got %0d", 
                        i,    (i + index_SVA),      rob_outputs[i]);
                    $finish;
                end
        end

        // Check overall conditions
        assert (reset || rob_debug.Spots == spots_manual)
            else begin
                $error("rob_debug.Spots (%0d) does not equal spots_manual (%0d)", 
                        rob_debug.Spots, spots_manual);
                $finish;
            end
        
        assert (reset || {1'b0, inputs_valid} <= ({1'b0, spots} + {1'b0, num_retiring}))
            else begin
                $error("inputs_valid (%0d) exceeds spots + num_retiring (%0d)", 
                        inputs_valid, spots + num_retiring);
                $finish;
            end

        assert (reset || num_retiring <= rob_debug.num_entries)
            else begin
                $error("num_retiring (%0d) exceeds num_entries (%0d)", 
                        num_retiring, rob_debug.num_entries);
                $finish;
            end
    end
endmodule

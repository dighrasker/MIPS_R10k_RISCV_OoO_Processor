`include "verilog/sys_defs.svh"

module rob #(
    parameter DEPTH = `ROB_SZ,
    localparam DEPTH_BITS = $clog2(DEPTH),
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1)
) (
    input   logic                        clock, 
    input   logic                        reset,

    // ------------ TO/FROM DISPATCH ------------- //
    input   ROB_ENTRY_PACKET     [`N-1:0] rob_inputs,        // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    input   logic  [`NUM_SCALAR_BITS-1:0] rob_inputs_valid,  // To distinguish invalid instructions being passed in from Dispatch (A number, NOT one hot)
    output  logic  [`NUM_SCALAR_BITS-1:0] rob_spots,         //number of spots available, saturated at N

    // ------------- TO/FROM RETIRE -------------- //
    input   logic  [`NUM_SCALAR_BITS-1:0] num_retiring,      // Retire module tells the ROB how many entries can be cleared
    output  ROB_EXIT_PACKET      [`N-1:0] rob_outputs,       // For retire to check eligibility
    output  logic  [`NUM_SCALAR_BITS-1:0] rob_outputs_valid, // If not all N rob entries are valid entries they should not be considered

    // ------------- FROM BRANCH STACK -------------- //
    input   logic                         tail_restore_valid,
    input   logic        [DEPTH_BITS-1:0] tail_restore
`ifdef DEBUG
    output  ROB_DEBUG                  rob_debug
`endif
); 

    // Main ROB Data Here
    ROB_ENTRY_PACKET [`ROB_SZ-1:0] rob_entries;

    logic       [DEPTH_BITS-1:0] head, next_head;
    logic       [DEPTH_BITS-1:0] tail, next_tail;
    logic [NUM_ENTRIES_BITS-1:0] entries, next_entries;

    always_comb begin
        next_head = (head + num_retiring) % DEPTH;
        next_tail = (tail + inputs_valid) % DEPTH;
        next_entries = entries + inputs_valid - num_retiring;
        spots = (DEPTH - entries < `N) ? DEPTH - entries : `N;
        outputs_valid = (entries < `N) ? entries : `N;
        rob_outputs = '0;
        for (int i = 0; i < `N; ++i) begin
            if (i < outputs_valid) begin
                rob_outputs[i] = rob_entries[(head + i)%DEPTH];
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_entries <= '0;
            head <= 0;
            tail <= 0;
            entries <= 0;
        end else begin
            for (int i = 0; i < `N; ++i) begin
                if (i < inputs_valid) begin
                    rob_entries[(tail + i)%DEPTH] <= rob_inputs[i]; 
                end
            end
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
        end
    end

// Debug signals
`ifdef DEBUG
    assign rob_debug = {
        Entries:        rob_entries,
        Head:           head,
        Tail:           tail,
        Spots:          spots,
        Outputs_valid:  outputs_valid,
        Rob_Outputs:    rob_outputs,
        num_entries:    entries
    };
`endif

endmodule
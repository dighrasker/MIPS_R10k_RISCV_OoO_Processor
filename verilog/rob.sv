module ROB #(
    parameter DEPTH = `ROB_SZ,
    localparam DEPTH_BITS = $clog2(DEPTH),
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1)
    localparam NUM_SCALAR_BITS = $clog2(`N+1)
) (
    input   logic                        clock, 
    input   logic                        reset,
    input   ROB_ENTRY_PACKET    [`N-1:0] rob_inputs, // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    input   logic  [NUM_SCALAR_BITS-1:0] num_valid, // To distinguish invalid instructions being passed in from Dispatch
    output  ROB_RETIRE_PACKET   [`N-1:0] rob_outputs, // For retire to check eligibility
    output  logic               [`N-1:0] outputs_valid, // If not all N rob entries are valid entries they should not be considered
    input   logic  [NUM_SCALAR_BITS-1:0] num_retiring, // Retire module tells the ROB how many entries can be cleared
    output  logic [NUM_ENTRIES_BITS-1:0] spots
`ifdef DEBUG
    , output  ROB_DEBUG                  rob_debug
`endif
); 

    // Main ROB Data Here
    ROB_ENTRY_PACKET [`ROB_SZ-1:0] rob_entries;

    logic       [DEPTH_BITS-1:0] head, next_head;
    logic       [DEPTH_BITS-1:0] tail, next_tail;
    logic [NUM_ENTRIES_BITS-1:0] entries, next_entries;
    logic     [$clog2(`N+1)-1:0] num_valid;
    logic     [$clog2(`N+1)-1:0] num_allocated;

    always_comb begin
        next_head = (head + num_retiring) % DEPTH;
        next_tail = (tail + num_valid) % DEPTH;
        next_entries = entries + num_valid - num_retiring;
        spots = DEPTH - entries;
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_entries <= '0;
            head <= 0;
            tail <= 0;
            entries <= 0;
        end else begin
            for (int i = 0; i < num_valid; ++i) rob_entries[(tail + i)%DEPTH] <= rob_inputs[i]; 
            for (int i = 0; i < num_retiring; ++i) rob_outputs[i] <= rob_entries[(head + i)%DEPTH];
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
        Rob_Outputs:    rob_outputs
    }
`endif

endmodule
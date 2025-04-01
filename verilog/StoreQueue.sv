`include "verilog/sys_defs.svh"

module store_queue #(
) (
    // ------------ FROM Store Unit ------------- //
    input   SQ_PACKET                     sq_packet,

    // ------------- TO/FROM DISPATCH -------------- // 
    input   logic                  [`N-1:0] stores_dispatched,
    output  logic        [`NUM_SQ_BITS-1:0] sq_spots,
    output  SQ_IDX                          sq_tail,
    output  SQ_MASK                         sq_mask,
    
    // ------------- TO/FROM Load Unit -------------- //
    input SQ_IDX                            load_sq_tail,
    input ADDR                              load_addr,
    output DATA                             sq_load_data,
    output BYTE_MASK                        sq_data_mask,

    // ------------- FROM BRANCH STACK -------------- //
    input   logic                           sq_restore_valid,
    input   logic      [`ROB_SZ_BITS-1:0]   sq_tail_restore,

    // ------------- TO/FROM D Cache-------------- //
    input logic                             cache_store_accepted,
    output logic                            cache_store_valid,
    output DATA                             cache_store_data,

    // ------------- TO/FROM Retire -------------- //
    input logic                 [`NUM_SCALAR_BITS-1:0] num_sq_retiring
); 

    STORE_QUEUE_PACKET     [`SQ_SZ-1:0] store_queue, next_store_queue;

    logic          [`ROB_SZ_BITS-1:0] head, next_head;
    logic          [`ROB_SZ_BITS-1:0] true_head, next_true_head;
    logic          [`ROB_SZ_BITS-1:0] tail, next_tail;

    logic [`ROB_NUM_ENTRIES_BITS-1:0] entries, next_entries;

    always_comb begin
        next_head = (head + num_retiring) % `ROB_SZ;
        next_tail = tail_restore_valid ? tail_restore : (rob_tail + rob_inputs_valid) % `ROB_SZ;
        next_entries = entries + rob_inputs_valid - num_retiring;
        rob_spots = (`ROB_SZ - entries < `N) ? `ROB_SZ - entries : `N;
        rob_outputs_valid = (entries < `N) ? entries : `N;
        rob_outputs = '0;
        for (int i = 0; i < `N; ++i) begin
            if (i < rob_outputs_valid) begin
                rob_outputs[i] = rob_entries[(head + i) % `ROB_SZ];
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_entries <= '0;
            head <= 0;
            rob_tail <= 0;
            entries <= 0;
        end else if(tail_restore_valid) begin
            head <= next_head;
            rob_tail <= tail_restore;
            entries <= (tail_restore == next_head) ? `ROB_SZ : (tail_restore - next_head + `ROB_SZ) % `ROB_SZ;
        end else begin
            for (int i = 0; i < `N; ++i) begin
                if (i < rob_inputs_valid) begin
                    rob_entries[(rob_tail + i) % `ROB_SZ] <= rob_inputs[i]; 
                end
            end
            head <= next_head;
            rob_tail <= next_tail;
            entries <= next_entries;
        end
        $display("rob_entries: %d\nrob_head: %d\nrob_tail: %d", entries, head, rob_tail);
    end

// Debug signals
`ifdef DEBUG
    assign rob_debug = {
        rob_inputs:         rob_entries,
        head:               head,
        rob_tail:           rob_tail,
        rob_spots:          rob_spots,
        rob_outputs_valid:  rob_outputs_valid,
        rob_outputs:        rob_outputs,
        rob_num_entries:    entries
    };
`endif

endmodule
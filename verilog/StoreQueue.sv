`include "verilog/sys_defs.svh"

module store_queue #(
) (
    // ------------ FROM Store Unit ------------- //
    input   SQ_PACKET                     sq_packet,

    // ------------- TO/FROM DISPATCH -------------- // 
    input   logic    [`NUM_SCALAR_BITS-1:0] stores_dispatched,
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
    input   SQ_IDX                          sq_tail_restore,
    input   SQ_MASK                         sq_mask_restore,

    // ------------- TO/FROM D Cache-------------- //
    input logic                             cache_store_accepted,
    output logic                            cache_store_valid,
    output DATA                             cache_store_data,
    output ADDR                             cache_store_addr,

    // ------------- TO/FROM Retire -------------- //
    input logic                 [`NUM_SCALAR_BITS-1:0] num_store_retiring
); 

    STORE_QUEUE_PACKET     [`SQ_SZ-1:0] store_queue, next_store_queue;

    SQ_IDX head, next_head;
    SQ_IDX true_head, next_true_head;
    SQ_IDX next_tail;

    logic [`SQ_NUM_ENTRIES_BITS-1:0] sq_entries, next_sq_entries;
    logic [`SQ_NUM_ENTRIES_BITS-1:0] store_buffer_entries, next_store_buffer_entries;

    always_comb begin
        cache_store_data = store_queue[true_head].store_result;
        cache_store_addr = store_queue[true_head].store_addr;
    end

    always_comb begin
        next_head = (head + num_sq_retiring) % `SQ_SZ;
        next_tail = (sq_tail + stores_dispatched) % `SQ_SZ;
        next_true_head = (true_head + cache_store_accepted) % `SQ_SZ;
        next_sq_entries = sq_entries + stores_dispatched - cache_store_accepted;
        next_store_buffer_entries = store_buffer_entries + num_store_retiring - cache_store_accepted;
        sq_spots = (`SQ_SZ - sq_entries < `N) ? `SQ_SZ - sq_entries : `N;
        cache_store_valid = store_buffer_entries != 0;
    end

generate
for (int i = 0; i < 4; ++i) begin
   psel_gen #(
        .WIDTH(`SQ_SZ),
        .REQS(1)
   ) newest_inst (
        .req(),
        .gnt()
   );

end
endgenerate

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
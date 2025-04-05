`include "verilog/sys_defs.svh"

module store_queue #(
) (
    // ------------ FROM Store Unit ------------- //
    input   SQ_PACKET                     sq_packet,
    input   SQ_MASK                       resolving_sq_mask,                    

    // ------------- TO/FROM DISPATCH -------------- // 
    input   logic    [`NUM_SCALAR_BITS-1:0] stores_dispatching,
    input   SQ_MASK                         dispatch_sq_mask,
    output  logic        [`NUM_SQ_BITS-1:0] sq_spots,
    output  SQ_POINTER                      sq_tail,
    output  SQ_MASK                         sq_mask_combinational,

    
    // ------------- TO/FROM Load Unit -------------- //
    input SQ_POINTER                        load_sq_tail,
    input ADDR                              load_req_addr,
    output DATA                             sq_load_data,
    output BYTE_MASK                        sq_data_mask,

    // ------------- FROM BRANCH STACK -------------- //
    input   logic                           sq_restore_valid,
    input   SQ_POINTER                      sq_tail_restore,
    input   SQ_MASK                         sq_mask_restore,

    // ------------- TO/FROM D Cache-------------- //
    input logic                             store_req_accepted,
    output logic                            store_req_valid,
    output DATA                             store_req_data, 
    output ADDR                             store_req_addr,

    // ------------- TO/FROM Retire -------------- //
    input logic                 [`NUM_SCALAR_BITS-1:0] num_store_retiring
); 
    STORE_QUEUE_PACKET     [`SQ_SZ-1:0] store_queue, next_store_queue;

    //TODO: Update these to add parity bit to the front assuming SQ_SZ is a power of 2
    SQ_POINTER head, next_head;
    SQ_POINTER true_head, next_true_head;
    SQ_POINTER next_tail;

    logic [`SQ_NUM_ENTRIES_BITS-1:0] sq_entries, next_sq_entries;
    logic [`SQ_NUM_ENTRIES_BITS-1:0] store_buffer_entries, next_store_buffer_entries;
    logic [`SQ_NUM_ENTRIES_BITS-1:0] sq_mask, next_sq_mask;

    assign sq_mask_combinational = sq_mask & (~resolving_sq_mask);
    assign next_store_buffer_entries = store_buffer_entries + num_store_retiring - store_req_accepted;
    assign store_req_data            = store_queue[true_head].store_result;
    assign store_req_addr            = store_queue[true_head].store_addr;
    assign store_req_valid           = store_buffer_entries != 0;
    assign next_true_head            = true_head + store_req_accepted;
    assign next_head                 = (head + num_sq_retiring) % `SQ_SZ;
    assign next_tail                 = sq_restore_valid ? sq_tail_restore : (sq_tail + stores_dispatching);
    assign sq_spots                  = (`SQ_SZ - sq_entries < `N) ? `SQ_SZ - sq_entries : `N;

    assign next_sq_entries           = sq_restore_valid ? (next_head ^ sq_tail_restore) == (1'b1 << `SQ_IDX_BITS) ? `SQ_SZ : 
                                                                                  sq_tail_restore.sq_idx - next_head.sq_id : 
                                                                      sq_entries + stores_dispatching - store_req_accepted;  // if restore valid -> if only parities different -> full
                                                                                                                              //                  -> else -> size = difference between indices
                                                                                                                              // else calculate with entries

    assign next_sq_mask = sq_restore_valid ? sq_mask_restore & (~resolving_sq_mask) : dispatch_sq_mask;

    generate
    for (genvar i = 0; i < 4; ++i) begin
        logic [`SQ_SZ-1:0] byte_matches;
        logic [`SQ_SZ-1:0] dependent_store; 

        psel_gen #(
            .WIDTH(`SQ_SZ),
            .REQS(1)
        ) newest_inst (
            .req(byte_matches),
            .gnt(dependent_store)
        );
        
        always_comb begin
            //address checking
            for(int j = 0; j < `SQ_SZ; ++j) begin
                byte_matches[j] = (load_req_addr.w.addr == store_queue[j].addr.w.addr) && store_queue[j].byte_mask[i];
            end

            //rotation logic
            byte_matches = (byte_matches << (`SQ_SZ - load_sq_tail.sq_idx)) | (byte_matches >> load_sq_tail.sq_idx);
            
            //squashing 
            for (int j = 0; j < `SQ_SZ; ++j) begin
                if (j < (true_head.sq_idx - load_sq_tail.sq_idx)) begin
                    byte_matches[j] = 1'b0;
                end
            end
            
            // sq is empty
            if (true_head == load_sq_tail) begin
                byte_matches = '0;
            end
        end
            // psel that shit
        
        always_comb begin
            sq_load_data.bytes[i] = '0;
            sq_data_mask[i] = 1'b0;
            for (int j = 0; j < `SQ_SZ; ++j) begin
                if (dependent_store[j]) begin
                    sq_load_data.bytes[i] = sq_entries[j].result.bytes[i];
                    sq_data_mask[i] = 1'b1;
                end
            end
        end
    end
    endgenerate

    always_comb begin
        next_store_queue = store_queue;
        for (int i = 0; i < `SQ_SZ; ++i) begin
            if (resolving_sq_mask[i]) begin
                next_store_queue[i] = sq_packet;
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            sq_tail <= '0;
            head <= '0;
            true_head <= '0;
            sq_entries <= '0;
            store_buffer_entries <= '0;
            sq_mask <= '0;
            store_queue <= '0;
        end else begin
            sq_tail <= next_tail;
            head <= next_head;
            true_head <= next_true_head;
            sq_entries <= next_sq_entries;
            store_buffer_entries <= next_store_buffer_entries;
            sq_mask <= next_sq_mask;
            store_queue <= next_store_queue;
        end
    end

endmodule
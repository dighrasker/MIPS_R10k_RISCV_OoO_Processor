
/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv                                           //
//                                                                     //
//  Description :  The instruction cache module that reroutes memory   //
//                 accesses to decrease misses.                        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"

/**
 * A quick overview of the cache and memory:
 *
 * We've increased the memory latency from 1 cycle to 100ns. which will be
 * multiple cycles for any reasonable processor. Thus, memory can have multiple
 * transactions pending and coordinates them via memory tags (different meaning
 * than cache tags) which represent a transaction it's working on. Memory tags
 * are 4 bits long since 15 mem accesses can be live at one time, and only one
 * access happens per cycle.
 *
 * On a request, memory responds with the tag it will use for that transaction.
 * Then, ceiling(100ns/clock period) cycles later, it will return the data with
 * the corresponding tag. The 0 tag is a sentinel value and unused. It would be
 * very difficult to push your clock period past 100ns/15=6.66ns, so 15 tags is
 * sufficient.
 *
 * This cache coordinates those memory tags to speed up fetching reused data.
 *
 * Note that this cache is blocking, and will wait on one memory request before
 * sending another (unless the input address changes, in which case it abandons
 * that request). Implementing a non-blocking cache can count towards simple
 * feature points, but will require careful management of memory tags.
 */

module dcache (
    input logic clock,
    input logic reset,

    // ------------------- LOAD DATA STAGE --------------- //
    input logic                             load_req_valid,
    input ADDR                              load_req_addr,
    output LOAD_DATA_CACHE_PACKET           load_data_cache_packet,        

    // ------------------- LOAD BUFFER --------------- //
    output LOAD_BUFFER_CACHE_PACKET         load_buffer_cache_packet,
    
    // ------------------- STORE UNIT --------------- //
    input logic                             store_req_valid,
    input ADDR                              store_req_addr,
    input DATA                              store_req_data,
    input SQ_MASK                           store_req_byte_mask,
    output wor                              store_req_accepted, // TODO Make sure this works. At the very least, this is how it should be thought of

    // ------------------ MAIN MEM ------------------- //
    input logic                             dcache_mem_req_accepted,
    input MEM_TAG                           dcache_mem_trxn_tag,
    input MEM_DATA_PACKET                   mem_data_packet,
    output MEM_REQ_PACKET                   dcache_mem_req_packet
);

    // ------- WB BUFFER WIRES -------- //
    
    WB_ENTRY          [`WB_LINE-1:0] wb_buffer, next_wb_buffer; 
    WB_LINE_BITS                     wb_head, next_wb_head;
    WB_LINE_BITS                     wb_tail, next_wb_tail; 
    logic                            load_wb_hit;
    WB_IDX                           load_wb_idx;
    logic                            store_wb_hit;
    WB_IDX                           store_wb_idx;
    logic [`WB_NUM_ENTRIES_BITS-1:0] wb_spots;

    // ------- MSHR WIRES -------- //
    
    DCACHE_MSHR_ENTRY [`MSHR_SZ-1:0] mshrs, next_mshrs; 
    MSHR_IDX                         mshr_true_head, next_mshr_true_head;
    MSHR_IDX                         mshr_head, next_mshr_head; 
    MSHR_IDX                         mshr_tail, next_mshr_tail; 
    
    logic                            load_mshr_hit;
    MSHR_IDX                         load_mshr_idx;
    logic                            store_mshr_hit;
    MSHR_IDX                         store_mshr_idx;

    logic [`MSHR_NUM_ENTRIES_BITS-1:0] mshr_spots;

    
    // ---- DCACHE WIRES ---- //

    DCACHE_META_DATA [`DCACHE_NUM_SETS-1:0] [`DCACHE_NUM_WAYS-1:0] dcache_meta_data, next_dcache_meta_data;
    DCACHE_WAY_IDX [`DCACHE_NUM_SETS-1:0] dcache_lru_idx;
    
    
    logic                                load_dcache_hit;
    DCACHE_IDX                           load_dcache_idx;
    logic                                store_dcache_hit;
    DCACHE_IDX                           store_dcache_idx;

    logic                                dirty_dcache_lru;

    // ----- VCACHE WIRES ---- //
    VCACHE_META_DATA [`VCACHE_LINES-1:0] vcache_meta_data, next_vcache_meta_data;
    VCACHE_IDX                           vcache_lru;

    logic                                load_vcache_hit;
    VCACHE_IDX                           load_vcache_idx;
    logic                                store_vcache_hit;
    VCACHE_IDX                           store_vcache_idx;
    logic                                dirty_vcache_lru;

    // --------     

    logic  load_miss, store_miss;
    assign load_miss = load_req_valid && !load_wb_hit && !load_mshr_hit && !load_dcache_hit && !load_vcache_hit;
    assign store_miss = store_req_valid && !store_wb_hit && !store_mshr_hit && !store_dcache_hit && !store_vcache_hit; 

    logic mshr_full;
    assign mshr_full = mshr_spots == 0;

    logic full_eviction;
    assign full_eviction = dirty_dcache_lru && dirty_vcache_lru && (wb_buffer.spots == 0);

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`DCACHE_LINES),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    dcache_mem (
        .clock(clock),
        .reset(reset),
        .re   (1'b1),
        .raddr(current_index),
        .rdata(Icache_data_out),
        .we   (got_mem_data),
        .waddr(current_index),
        .wdata(Imem2proc_data)
    );

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`VCACHE_LINES), 
        .READ_PORTS(1),
        .BYPASS_EN (0))
    vcache_mem (
        .clock(clock),
        .reset(reset),
        .re   (1'b1),
        .raddr(current_index),
        .rdata(Icache_data_out),
        .we   (got_mem_data),
        .waddr(current_index),
        .wdata(Imem2proc_data)
    );

    always_comb begin
    //Set LRU ? ? ? ? ? ? ?sus
        if (load_dcache_hit) begin
            for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
                next_dcache_meta_data[load_req_addr.dcache.set_idx][load_dcache_idx] = `DCACHE_NUM_WAYS-1;
                if (dcache_meta_data[i].lru > dcache_meta_data[load_req_addr.dcache.set_idx].lru) begin
                    next_dcache_meta_data[i].lru--;
                end
            end
        end else if (load_vcache_hit) begin
            for (int i = 0; i < `VCACHE_LINES; ++i) begin
                //eviction logic in dcache
                next_dcache_meta_data[vcache_meta_data[i].addr.dcache.set_idx][load_vcache_idx]; //TODO sus sus sus s        
        
            end
        end else if (store_dcache_hit) begin
            for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
                next_dcache_meta_data[load_req_addr.dcache.set_idx].lru = `DCACHE_NUM_WAYS-1;
                if (dcache_meta_data[i].lru > dcache_meta_data[load_req_addr.dcache.set_idx].lru) begin
                    next_btb_set_entries[i].btb_entries[l].btb_lru--;
                end
            end
        end 
    end
    
    // find lru of dcache
    always_comb begin
        for (int i = 0; i < `DCACHE_NUM_SETS; ++i) begin
            for (int j = 0; j < `DCACHE_NUM_WAYS; ++j) begin
                if ()
            end
        end
    end

    // cam that dcache shi
    always_comb begin
        load_dcache_hit = 0;
        store_dcache_hit = 0;
        load_dcache_idx = 0;
        store_dcache_idx = 0;
        for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
            if (load_req_valid && dcache_meta_data[load_req_addr.dcache.set_idx][i].addr.dcache.tag == load_req_addr.dcache.tag) begin
                load_dcache_hit = 1;
                load_dcache_idx = (load_req_addr.dcache.set_idx * `DCACHE_NUM_WAYS) + i;
            end
        end
        for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
            if (store_req_valid && dcache_meta_data[store_req_addr.dcache.set_idx][i].addr.dcache.tag == store_req_addr.dcache.tag) begin
                store_dcache_hit = 1;
                store_dcache_idx = (store_req_addr.dcache.set_idx * `DCACHE_NUM_WAYS) + i;
            end
        end
    end

    //cam that mshr shi
    always_comb begin
        load_mshr_hit = 1'b0;
        load_mshr_idx = '0;
        store_mshr_hit = 1'b0;
        store_mshr_idx = '0;

        for (int i = 0; i < `MSHR_SZ; ++i) begin
            if (i < `MSHR_SZ - mshr_spots) begin
                if (load_req_valid && mshrs[(mshr_true_head + i) % `MSHR_SZ].addr.dw.addr == load_req_addr.dw.addr) begin
                    load_mshr_hit = 1'b1;
                    load_mshr_idx = (mshr_true_head + i) % `MSHR_SZ;
                end
                if (store_req_valid && mshrs[(mshr_true_head + i) % `MSHR_SZ].addr.dw.addr == store_req_addr.dw.addr) begin
                    store_mshr_hit = 1'b1;
                    store_mshr_idx = (mshr_true_head + i) % `MSHR_SZ;
                end
            end
        end
    end

    //cam that vcache shi
    always_comb begin
        load_vcache_hit = 1'b0;
        load_vcache_idx = '0;
        store_vcache_hit = 1'b0;
        store_vcache_idx = '0;
        for (int i = 0; i < `VCACHE_LINES; ++i) begin
            if (load_req_valid && vcache_meta_data[i].addr.dw.addr == load_req_addr.dw.addr) begin
                load_vcache_hit = 1'b1;
                load_vcache_idx = i; 
            end 
            if (store_req_valid && vcache_meta_data[i].addr.dw.addr == store_req_addr.dw.addr) begin
                store_vcache_hit = 1'b1;
                store_vcache_idx = i; 
            end
        end
    end

    //cam that wb buffer shi
    always_comb begin
        load_wb_hit = 1'b0;
        load_wb_idx = '0;
        store_wb_hit = 1'b0;
        store_wb_idx = '0;
        for (int i = 0; i < `WB_LINES; ++i) begin
            if(load_req_valid && wb_buffer[i].addr.dw.addr == load_req_addr.dw.addr) begin
                load_wb_hit = 1'b1;
                load_wb_idx = i; 
            end       
            if (store_req_valid && wb_buffer[i].addr.dw.addr == store_req_addr.dw.addr) begin
                store_wb_hit = 1'b1;
                store_wb_idx = i; 
            end
        end
    end

    // find dcache lru
    always_comb begin


    end

    always_ff @(posedge clock) begin
        if (reset) begin
            
        end else begin
            
        end
    end

endmodule

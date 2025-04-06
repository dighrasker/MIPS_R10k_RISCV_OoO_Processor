
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
    output logic                            store_req_accepted, // TODO Make sure this works. At the very least, this is how it should be thought of

    // ------------------ MAIN MEM ------------------- //
    input logic                             dcache_mem_req_accepted,
    input MEM_TAG                           dcache_mem_trxn_tag,
    input MEM_DATA_PACKET                   mem_data_packet,
    output MEM_REQ_PACKET                   dcache_mem_req_packet
);

    // ------- WB BUFFER WIRES -------- //
    
    WB_ENTRY          [`WB_LINE-1:0] wb_buffer, next_wb_buffer; 
    WB_IDX                           wb_head, next_wb_head;
    WB_IDX                           wb_tail, next_wb_tail; 
    logic                            load_wb_hit;
    WB_IDX                           load_wb_idx;
    logic                            store_wb_hit;
    WB_IDX                           store_wb_idx;
    logic [`WB_NUM_ENTRIES_BITS-1:0] wb_spots;
    logic                            wb_allocated;
    logic                            wb_mem_accepted;
    

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
    logic                              mshr_cache_accepted;
    logic                              mshr_allocated;

    
    // ---- DCACHE WIRES ---- //

    DCACHE_META_DATA [`DCACHE_NUM_SETS-1:0] [`DCACHE_NUM_WAYS-1:0] dcache_meta_data, next_dcache_meta_data;
    DCACHE_WAY_IDX [`DCACHE_NUM_SETS-1:0] dcache_lru_idx;
    
    logic                                load_dcache_hit;
    DCACHE_IDX                           load_dcache_idx;
    logic                                store_dcache_hit;
    DCACHE_IDX                           store_dcache_idx;

    DCACHE_IDX                           dcache_idx;
    DCACHE_IDX                           dcache_set_idx;
    DCACHE_IDX                           dcache_way_idx;
    DATA                           [1:0] dcache_data_out;
    logic                                dcache_rd_en;
    logic                                dcache_wr_en;
    DATA                           [1:0] dcache_wr_data;

    

    // ----- VCACHE WIRES ---- //
    VCACHE_META_DATA [`VCACHE_LINES-1:0] vcache_meta_data, next_vcache_meta_data;
    VCACHE_IDX                           vcache_lru;

    logic                                load_vcache_hit;
    VCACHE_IDX                           load_vcache_idx;
    logic                                store_vcache_hit;
    VCACHE_IDX                           store_vcache_idx;

    VCACHE_IDX                           vcache_idx;
    DATA                           [1:0] vcache_data_out;
    logic                                vcache_rd_en;
    logic                                vcache_wr_en;
    DATA                           [1:0] vcache_wr_data;

    // --------     

    logic  load_miss, store_miss;
    assign load_miss = load_req_valid && !load_wb_hit && !load_mshr_hit && !load_dcache_hit && !load_vcache_hit;
    assign store_miss = store_req_valid && !store_wb_hit && !store_mshr_hit && !store_dcache_hit && !store_vcache_hit; 

    logic mshr_full;
    assign mshr_full = mshr_spots == 0;

    logic  dirty_dcache_lru, dirty_vcache_lru;
    assign dirty_dcache_lru = dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx][dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx]].dirty;
    assign dirty_vcache_lru = vcache_meta_data[vcache_lru_idx].dirty;
    logic full_eviction;
    assign full_eviction = dirty_dcache_lru && dirty_vcache_lru && (wb_buffer.spots == 0);

    assign wb_mem_accepted = (dcache_mem_req_accepted && !mshr_allocated);

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`DCACHE_LINES),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    dcache_mem (
        .clock(clock),
        .reset(reset),
        .re   (dcache_rd_en),
        .raddr(dcache_idx),
        .rdata(dcache_data_out),
        .we   (dcache_wr_en),
        .waddr(dcache_idx),
        .wdata(dcache_wr_data)
    );

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`VCACHE_LINES), 
        .READ_PORTS(1),
        .BYPASS_EN (0))
    vcache_mem (
        .clock(clock),
        .reset(reset),
        .re   (vcache_rd_en),
        .raddr(vcache_idx),
        .rdata(vcache_data_out),
        .we   (vcache_wr_en),
        .waddr(vcache_idx),
        .wdata(vcache_wr_data)
    );

    // all hit logic
    always_comb begin
        next_dcache_meta_data = dcache_meta_data;
        dcache_idx = '0;
        dcache_rd_en = 1'b0;
        dcache_wr_en = 1'b0;
        dcache_wr_data = '0;

        next_vcache_meta_data = vcache_meta_data;
        vcache_idx = '0;
        vcache_rd_en = 1'b0;
        vcache_wr_en = 1'b0;
        vcache_wr_data = '0;
        
        next_mshr_true_head = mshr_true_head;
        next_mshr_head = mshr_head;
        next_mshr_tail = mshr_tail;
        mshr_cache_accepted = 1'b0;

        next_wb_buffer = wb_buffer;
        next_wb_tail = wb_tail;
        wb_allocated = 0;

        store_req_accepted = 1'b0;
        load_data_cache_packet = '0;

        if (mem_data_packet.mem_tag == mshrs[mshr_head].mem_tag) begin
            for (int i = 0; i < 2; ++i) begin
                for (int j = 0; j < 4; ++j) begin
                    if (!mshrs[mshr_head].byte_mask[i][j]) begin
                        next_mshrs[mshr_head].data[i].bytes[j] = mem_data_packet.data[i].bytes[j];
                    end
                end
            end
            next_mshrs[mshrs_head].byte_mask = '1;
            next_mshr_head = (mshr_head + 1) % `MSHR_SZ;

            load_buffer_cache_packet.valid = 1'b1;
            load_buffer_cache_packet.mshr_idx = mshr_head;
            load_buffer_cache_packet.data = next_mshrs[mshrs_head].data;
        end

        // include mshr hit logic

        if (load_mshr_hit) begin
            load_data_cache_packet.valid = 1'b1;
            load_data_cache_packet.mshr_idx = load_mshr_idx;
            load_data_cache_packet.byte_mask = next_mshrs[load_mshr_idx].byte_mask;
            load_data_cache_packet.data = next_mshrs[load_mshr_idx].data;
        end

        if (store_mshr_hit) begin
            store_req_accepted = 1'b1;
            for (int i = 0; i < 4; ++i) begin
                if (store_req_byte_mask[i]) begin
                    next_mshrs[store_mshr_idx].data[store_req_addr.dw.w_idx].bytes[i] = store_req_data.bytes[i];
                    next_mshrs[store_mshr_idx].byte_mask[store_req_addr.dw.w_idx][i] = 1'b1;
                end
            end
            next_mshrs[store_mshr_idx].dirty = 1'b1;
        end

        if (load_wb_hit) begin
            load_data_cache_packet.valid = 1'b1;
            load_data_cache_packet.byte_mask = 2'hFF;
            load_data_cache_packet.data = wb_buffer[load_wb_idx].data;
        end

        if (store_wb_hit) begin
            store_req_accepted = 1'b1;
            for (int i = 0; i < 4; ++i) begin
                if (store_req_byte_mask[i]) begin
                    next_wb_buffer[store_wb_idx].data[store_req_addr.dw.w_idx].bytes[i] = store_req_data.bytes[i];
                end
            end
        end

        if (load_dcache_hit) begin
            load_data_cache_packet.valid = 1'b1;
            dcache_rd_en = 1'b1;

            dcache_index = (load_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + load_dcache_idx;

            load_data_cache_packet.byte_mask = 2'hFF; //shove that shi IN 
            load_data_cache_packet.data = dcache_data_out;

        end else if (load_vcache_hit) begin
            load_data_cache_packet.valid = 1'b1;
            dcache_rd_en = 1'b1;
            dcache_wr_en = 1'b1;
            vcache_rd_en = 1'b1;
            vcache_wr_en = 1'b1;

            dcache_index = (load_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + dcache_lru_idx[load_req_addr.dcache.set_idx];
            vcache_index = load_vcache_idx;
            dcache_wr_data = vcache_data_out;
            vcache_wr_data = dcache_data_out;

            next_dcache_meta_data[load_req_addr.dcache.set_idx][dcache_lru_idx[load_req_addr.dcache.set_idx]].addr = vcache_meta_data[load_vcache_idx].addr;
            next_dcache_meta_data[load_req_addr.dcache.set_idx][dcache_lru_idx[load_req_addr.dcache.set_idx]].dirty = vcache_meta_data[load_vcache_idx].dirty;

            next_vcache_meta_data[load_vcache_idx].addr = dcache_meta_data[load_req_addr.dcache.set_idx][dcache_lru_idx[load_req_addr.dcache.set_idx]].addr;
            next_vcache_meta_data[load_vcache_idx].dirty = dcache_meta_data[load_req_addr.dcache.set_idx][dcache_lru_idx[load_req_addr.dcache.set_idx]].dirty;
            
            load_buffer_cache_packet.byte_mask = 2'hFF;
            load_data_cache_packet.data = vcache_data_out;
            
        end else if (store_dcache_hit) begin
            store_req_accepted = 1'b1;

            dcache_rd_en = 1'b1;
            dcache_wr_en = 1'b1;
            dcache_index = (store_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + dcache_lru_idx[store_req_addr.dcache.set_idx];

            dcache_wr_data = dcache_data_out;
            for (int i = 0; i < 4; ++i) begin
                if (store_req_byte_mask[i]) begin
                    dcache_wr_data[store_req_addr.dw.w_idx].bytes[i] = store_req_data.bytes[i];
                end
            end

            next_dcache_meta_data[store_req_addr.dcache.set_idx][dcache_lru_idx[store_req_addr.dcache.set_idx]].dirty = 1'b1;

        end else if (store_vcache_hit) begin
            store_req_accepted = 1'b1;

            dcache_rd_en = 1'b1;
            dcache_wr_en = 1'b1;
            vcache_rd_en = 1'b1;
            vcache_wr_en = 1'b1;

            dcache_index = (store_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + dcache_lru_idx[store_req_addr.dcache.set_idx];
            vcache_index = vcache_lru_idx;

            dcache_wr_data = vcache_data_out; //return store to d$
            for (int i = 0; i < 4; ++i) begin
                if (store_req_byte_mask[i]) begin
                    dcache_wr_data[store_req_addr.dw.w_idx].bytes[i] = store_req_data.bytes[i];
                end
            end
        
            vcache_wr_data = dcache_data_out; //evict to v$

            next_dcache_meta_data[store_req_addr.dcache.set_idx][dcache_lru_idx[store_req_addr.dcache.set_idx]].addr = vcache_meta_data[store_vcache_idx].addr;
            next_dcache_meta_data[store_req_addr.dcache.set_idx][dcache_lru_idx[store_req_addr.dcache.set_idx]].dirty = 1'b1;

            next_vcache_meta_data[store_vcache_idx].addr = dcache_meta_data[store_req_addr.dcache.set_idx][dcache_lru_idx[store_req_addr.dcache.set_idx]].addr;
            next_vcache_meta_data[store_vcache_idx].dirty = dcache_meta_data[store_req_addr.dcache.set_idx][dcache_lru_idx[store_req_addr.dcache.set_idx]].dirty;

        end else if ((mshr_true_head != next_mshr_head || mshr_full) && (!full_eviction || wb_mem_accepted)) begin
            mshr_cache_accepted = 1;

            dcache_rd_en = 1'b1;
            dcache_wr_en = 1'b1;
            dcache_wr_data = next_mshrs[mshr_true_head].data;
            dcache_idx = (mshrs[mshr_true_head].addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx];

            next_mshr_true_head = (mshr_true_head + 1) % `MSHR_SZ;

            next_dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx][dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx]].dirty = next_mshrs[mshr_true_head].dirty;
            next_dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx][dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx]].addr = next_mshrs[mshr_true_head].addr;
            next_dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx][dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx]].valid = 1;

            // punt to victim cache
            if (dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx].valid) begin

                next_vcache_meta_data[vcache_lru].addr = dcache_meta_data[mshrs[mshr_true_head].addr.dcache.set_idx][dcache_lru_idx[mshrs[mshr_true_head].addr.dcache.set_idx]].addr;
                next_vcache_meta_data[vcache_lru].dirty = dirty_dcache_lru;
                next_vcache_meta_data[vcache_lru].valid = 1;
                vcache_rd_en = 1'b1;
                vcache_wr_en = 1'b1;
                vcache_wr_data = dcache_data_out;
                vcache_idx = vcache_lru;
                
                // punt to wb buffer
                if (vcache_meta_data[vcache_lru].valid) begin
                    next_wb_buffer[wb_tail] = vcache_data_out;
                    next_wb_tail = wb_tail + 1;
                    wb_allocated = 1;
                end
            end    
        end

        if (!mshr_full) begin
            if (load_miss) begin
                load_data_cache_packet.valid = 1'b1;
                next_mshrs[mshr_tail].dirty = 0;
                next_mshrs[mshr_tail].mem_tag = dcache_mem_trxn_tag; 
                next_mshrs[mshr_tail].addr = load_req_addr; 
                next_mshrs[mshr_tail].data = '0;
                next_mshrs[mshr_tail].byte_mask = '0;      
                next_mshr_tail = (mshr_tail + 1) % `MSHR_SZ;       
            end else if (store_miss) begin
                store_req_accepted = 1'b1;
                next_mshrs[mshr_tail].dirty = 1;
                next_mshrs[mshr_tail].mem_tag = dcache_mem_trxn_tag; 
                next_mshrs[mshr_tail].addr = store_req_addr;
                next_mshrs[mshr_tail].data[store_req_addr.dw.w_idx] = store_req_data;
                next_mshrs[mshr_tail].byte_mask[store_req_addr.dw.w_idx] = store_req_byte_mask;
                next_mshr_tail = (mshr_tail + 1) % `MSHR_SZ;
            end
        end

        // update lru bits
        dcache_set_idx = dcache_idx >> `DCACHE_WAY_IDX_BITS;
        dcache_way_idx = dcache_idx & `DCACHE_WAY_IDX_BITS{1'b1};
        next_dcache_meta_data[dcache_set_idx][dcache_way_idx].lru = `DCACHE_NUM_WAYS - 1;
        for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
            if ((dcache_rd_en || dcache_wr_en) && dcache_meta_data[dcache_set_idx][i].valid && dcache_meta_data[dcache_set_idx][i].lru > dcache_meta_data[dcache_set_idx][dcache_way_idx].lru) begin
                next_dcache_meta_data[dcache_set_idx][i].lru--;
            end
        end

        next_vcache_meta_data[vcache_idx].lru = `VCACHE_NUM_WAYS - 1;
        for (int i = 0; i < `VCACHE_NUM_WAYS; ++i) begin
            if ( (vcache_rd_en || vcache_wr_en) && vcache_meta_data[i].valid && (vcache_meta_data[i].lru > vcache_meta_data[vcache_idx].lru)) begin
                next_vcache_meta_data[i].lru--;
            end 
        end
    end

    // Find the LRU index for each set in the dcache
    generate
    genvar i;
    genvar j;

    for (i = 0; i < `DCACHE_NUM_SETS; ++i) begin
        logic [`DCACHE_NUM_WAYS-1:0] lru_gnt_line;
        logic [`DCACHE_NUM_WAYS-1:0] requests;

        for(j = 0; j < `DCACHE_NUM_WAYS; ++j) begin
            assign requests[j] = dcache_meta_data[i][j].lru == 0;
        end
        
        psel_gen #(
            .WIDTH(`DCACHE_NUM_WAYS),
            .REQS(1)
        ) lru_psel (
            .req(requests),
            .gnt(lru_gnt_line)
        );

        encoder #(`DCACHE_NUM_WAYS, `DCACHE_WAY_IDX_BITS) lru_idx_encoder (lru_gnt_line, dcache_lru_idx[i]);
    end

    endgenerate

    // Find the LRU index for the vcache
    logic [`VCACHE_NUM_WAYS-1:0] vcache_lru_gnt_line;
    logic [`VCACHE_NUM_WAYS-1:0] vcache_lru_requests;
    for(j = 0; j < `VCACHE_NUM_WAYS; ++j) begin
        assign vcache_lru_requests[j] = vcache_meta_data[i][j].lru == 0;
    end
    
    psel_gen #(
        .WIDTH(`VCACHE_NUM_WAYS),
        .REQS(1)
    ) lru_psel (
        .req(vcache_lru_requests),
        .gnt(vcache_lru_gnt_line)
    );

    encoder #(`VCACHE_NUM_WAYS, `VCACHE_WAY_IDX_BITS) lru_idx_encoder (vcache_lru_gnt_line, vcache_lru_idx);

    // cam that dcache shi
    always_comb begin
        load_dcache_hit = 0;
        store_dcache_hit = 0;
        load_dcache_idx = 0;
        store_dcache_idx = 0;
        for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
            if (load_req_valid && dcache_meta_data[load_req_addr.dcache.set_idx][i].valid && dcache_meta_data[load_req_addr.dcache.set_idx][i].addr.dcache.tag == load_req_addr.dcache.tag) begin
                load_dcache_hit = 1;
                load_dcache_idx = (load_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + i;
            end
        end
        for (int i = 0; i < `DCACHE_NUM_WAYS; ++i) begin
            if (store_req_valid && dcache_meta_data[store_req_addr.dcache.set_idx][i].valid && dcache_meta_data[store_req_addr.dcache.set_idx][i].addr.dcache.tag == store_req_addr.dcache.tag) begin
                store_dcache_hit = 1;
                store_dcache_idx = (store_req_addr.dcache.set_idx << `DCACHE_WAY_IDX_BITS) + i;
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
            if (i < `WB_LINES - wb_spots) begin
                if(load_req_valid && wb_buffer[wb_head + i].addr.dw.addr == load_req_addr.dw.addr) begin
                    load_wb_hit = 1'b1;
                    load_wb_idx = wb_head + i; 
                end       
                if (store_req_valid && wb_buffer[wb_head + i].addr.dw.addr == store_req_addr.dw.addr) begin
                    store_wb_hit = 1'b1;
                    store_wb_idx = wb_head + i; 
                end
            end
        end
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            
        end else begin
            
        end
    end

endmodule

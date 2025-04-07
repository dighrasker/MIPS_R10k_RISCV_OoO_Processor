/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  icache.sv                                           //
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

module icache (
    input clock,
    input reset,

    // ------------ TO/FROM FETCH ---------------//
    input ADDR                   [`N-1:0] PCs,
    output DATA                  [`N-1:0] cache_data, //instructions being sent to Fetch
    output logic                 [`N-1:0] cache_miss, 
 
    // ------------ TO/FROM MAIN MEMORY ---------------//
    input logic                             icache_mem_req_accepted,
    input MEM_TAG                           icache_mem_trxn_tag,
    input MEM_DATA_PACKET                   mem_data_packet,
    output MEM_REQ_PACKET                   icache_mem_req_packet
);
    
    // ----- mshr wires ----- // 

    ICACHE_MSHR_ENTRY [`MSHR_SZ-1:0] mshrs, next_mshrs; 
    MSHR_IDX                         mshr_head, next_mshr_head; // Next mshr to get mem data
    MSHR_IDX                         mshr_tail, next_mshr_tail; // Next mshr to get assigned a mem req
    logic       [`PREFETCH_DIST-1:0] mshr_miss;   

    logic                            mem_data_returned;

    
    // ---- ICACHE WIRES ---- //

    wand                               [`PREFETCH_DIST-1:0] icache_miss;  // TODO: MAKE SURE THIS WORKS! (. O .)
    DATA                      [`ICACHE_NUM_BANKS-1:0] [1:0] icache_rd_data; 
    ADDR [`PREFETCH_DIST-1:0]                               prefetch_window;
    logic                              [`PREFETCH_DIST-1:0] prefetch_miss;  

    assign prefetch_miss = icache_miss & mshr_miss;

    always_comb begin
        prefetch_window = '0;
        for (int i = 0; i < `PREFETCH_DIST; ++i) begin
            prefetch_window[i] = PCs[0] + (4 * i);
        end
    end

    //generate the BANKS 
    generate
        genvar i;
        for (i = 0; i < `ICACHE_NUM_BANKS; ++i) begin
            logic icache_rd_en, icache_wr_en;
            ICACHE_IDX icache_rd_idx, icache_wr_idx;
            DATA [1:0] icache_wr_data;
            ICACHE_META_DATA [`ICACHE_NUM_SETS-1:0] [`ICACHE_NUM_WAYS-1:0] icache_meta_data, next_icache_meta_data;

            memDP #(
                .WIDTH     ($bits(MEM_BLOCK)),
                .DEPTH     (`ICACHE_LINES),
                .READ_PORTS(1),
                .BYPASS_EN (0))
            icache_mem (
                .clock(clock),
                .reset(reset),
                .re   (1'b1),
                .raddr(icache_rd_idx),
                .rdata(icache_rd_data[i]),
                .we   (icache_wr_en),
                .waddr(icache_wr_idx),
                .wdata(icache_wr_data)
            );

            // cam
            always_comb begin
                icache_miss = '1;
                for (int j = 0; j < `PREFETCH_DIST; ++j) begin
                    for (int k = 0; k < `ICACHE_NUM_WAYS; ++k) begin
                        if ((prefetch_window[j].icache.bank_idx == i) && (icache_meta_data[prefetch_window[j].icache.set_idx][k].addr.icache.tag == prefetch_window[i].icache.tag)) begin
                            icache_miss[j] = 1'b0;
                            if (j < `N) begin
                                icache_rd_idx = (prefetch_window[i].icache.set_idx << `ICACHE_NUM_WAYS) + k;
                            end
                        end
                    end
                end
            end

            always_ff @(posedge clock) begin
                if (reset) begin
                    icache_meta_data <= '0;
                end else begin
                    icache_meta_data <= next_icache_meta_data;
                end
            end
        end
    endgenerate

    //cam mshrs for in flight pcs
    always_comb begin
        mshr_miss = '1;
        for (int i = 0; i < `PREFETCH_DIST; ++i) begin
            for (int j = 0; j < `MSHR_SZ; ++j) begin
                if((j < `MSHR_SZ - mshr_spots) && (prefetch_window[i].dw.addr == mshrs[(mshr_head + j) % `MSHR_SZ].dw.addr)) begin
                   mshr_miss[i] = 1'b0;
                end
            end
        end

    end

    always_comb begin
        cache_miss = '1;
        for (int i = 0; i < `N; ++i) begin
            if (!icache_miss[i]) begin
                cache_miss[i] = 1'b0;
                cache_data[i] = icache_rd_data[PCs[i].icache.bank_idx][PCs[i].dw.w_idx];
            end
        end
    end


endmodule // icache

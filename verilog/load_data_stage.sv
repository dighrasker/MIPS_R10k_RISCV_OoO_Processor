
`include "verilog/sys_defs.svh"

module load_data_stage (
    input clock,
    input reset,
    // ------------ FROM LOAD ADDR STAGE ------------- //
    input LOAD_DATA_PACKET          load_data_packet_in,
    output logic                    load_data_free,
    
    // ------------ TO/FROM CACHE ------------- //
    input logic                     cache_load_accepted,
    input DATA                [1:0] cache_load_data,
    input BYTE_MASK           [1:0] cache_data_mask,
    input MSHR_IDX                  cache_mshr_idx,
    output logic                    load_valid,

    // ------------ TO/FROM STORE QUEUE ------------- //
    input DATA                      sq_load_data,
    input BYTE_MASK                 sq_data_mask,
    output SQ_IDX                   load_sq_tail,
    output ADDR                     load_addr, //also goes to cache
    
    // ------------ TO LOAD BUFFER ------------- //
    output LOAD_BUFFER_PACKET       load_buffer_packet
);

    LOAD_DATA_PACKET load_data_packet;

    //ldback press
    assign load_data_free = !load_data_packet.valid | cache_load_accepted;
    assign load_addr = load_data_packet.load_addr;
    assign load_valid = load_data_packet.valid;
    assign load_sq_tail = load_data_packet.sq_tail;

    
    
    always_comb begin
        load_buffer_packet.mshr_idx = cache_mshr_idx;
        load_buffer_packet.bm = load_data_packet.bm;
        load_buffer_packet.valid = load_data_packet.valid;
        load_buffer_packet.dest_reg_idx = load_data_packet.dest_reg_idx;
        load_buffer_packet.load_addr = load_data_packet.load_addr;
        load_buffer_packet.load_func = load_data_packet.load_func;
        load_buffer_packet.result = '0;
        load_buffer_packet.byte_mask = load_data_packet.byte_mask;
        for (int i = 0; i < 4; ++i) begin
            if (load_data_packet.byte_mask[i]) begin
                if (sq_data_mask[i]) begin
                    load_buffer_packet.result.bytes[i] = sq_load_data.bytes[i];
                    load_buffer_packet.byte_mask[i] = 1'b0;
                end else if (cache_data_mask[load_data_packet.load_addr.dw.w_idx][i]) begin
                    load_buffer_packet.result.bytes[i] = cache_load_data[load_data_packet.load_addr.dw.w_idx].bytes[i];
                    load_buffer_packet.byte_mask[i] = 1'b0;
                end
            end 
        end

        if (b_mm_resolve & load_data_packet.bm) begin
            load_buffer_packet.bm = load_data_packet.bm & ~(b_mm_resolve);
            if (b_mm_mispred) begin
                load_buffer_packet = NOP_LOAD_BUFFER_PACKET;
            end
        end
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            load_data_packet <= NOP_LOAD_DATA_PACKET;
        end else if (load_data_free) begin
            load_data_packet <= load_data_packet_in;
        end
    end

endmodule // alu
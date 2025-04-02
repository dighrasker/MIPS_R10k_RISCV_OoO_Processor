
`include "verilog/sys_defs.svh"

module store_addr_stage (
    input                   clock,
    input                   reset,

    // ------------ TO/FROM STORE UNIT ------------- //
    input STORE_ADDR_PACKET            store_addr_packet_in,
    output STORE_QUEUE_PACKET          store_queue_packet,

    // ------------ FROM BRANCH STACK --------------//
    input B_MASK                        b_mm_resolve,
    input logic                         b_mm_mispred,
);

    STORE_ADDR_PACKET store_addr_packet; 
    
    BYTE_MASK temp_byte_mask;

    always_comb begin
        store_queue_packet.valid = store_addr_packet.valid;
        store_queue_packet.addr = store_addr_packet.source_reg_1 + store_addr_packet.store_imm; 
        store_queue_packet.result = store_addr_packet.source_reg_2;
        store_queue_packet.bm = store_addr_packet.bm;
        store_queue_packet.byte_mask = temp_byte_mask << store_queue_packet.store_address.w.offset;
        if (b_mm_resolve & store_addr_packet.bm) begin
            store_queue_packet.bm = store_addr_packet.bm & ~(b_mm_resolve);
            if (b_mm_mispred) begin
                store_queue_packet = NOP_STORE_QUEUE_PACKET;
            end
        end
    end

    always_comb begin
        case (MEM_SIZE(store_addr_packet.store_func[1:0]))
            BYTE:       temp_byte_mask = 4'b0001;
            HALF:       temp_byte_mask = 4'b0011;
            WORD:       temp_byte_mask = 4'b1111;
            default:    temp_byte_mask = 4'b0000;
        endcase
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            store_addr_packet <= NOP_STORE_ADDR_PACKET;
        end else begin
            store_addr_packet <= store_addr_packet_in;
        end
    end

endmodule // alu
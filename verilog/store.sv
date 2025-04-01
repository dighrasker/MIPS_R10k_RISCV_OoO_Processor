`include "verilog/sys_defs.svh"

module load_addr_stage (
    input                   clock,
    input                   reset,

    // ------------ TO/FROM Execute ------------- //
    input LOAD_ADDR_PACKET  load_addr_packet_in,
    output logic            load_addr_free,

    // ------------ TO/FROM LOAD_DATA REG ------------- //
    input logic             load_data_free,
    output LOAD_DATA_PACKET load_data_packet,

    // ------------ FROM LOAD_BUFFER ------------- //
    input logic             load_buffer_free
);

    LOAD_ADDR_PACKET load_addr_packet;
    
    BYTE_MASK temp_byte_mask;

    assign load_addr_free = (load_buffer_free & load_data_free) | ~load_addr_packet.valid;
    assign load_data_packet.valid = load_addr_packet.valid;
    assign load_data_packet.dest_reg_idx = load_addr_packet.dest_reg_idx;
    assign load_data_packet.bm = load_addr_packet.bm;
    assign load_data_packet.load_addr = load_addr_packet.source_reg_1 + load_addr_packet.source_reg_2;
    assign load_data_packet.byte_mask = temp_byte_mask << load_data_packet.load_addr.w.offset;
    assign load_data_packet.sq_tail = load_addr_packet.sq_tail;
    assign load_data_packet.load_func = load_addr_packet.load_func; 

    always_comb begin
        case (MEM_SIZE(load_addr_packet.load_func[1:0]))
            BYTE:       temp_byte_mask = 4'b0001;
            HALF:       temp_byte_mask = 4'b0011;
            WORD:       temp_byte_mask = 4'b1111;
            default:    temp_byte_mask = 4'b0000;
        endcase
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            load_addr_packet <= NOP_LOAD_ADDR_PACKET;
        end else if (load_addr_free) begin
            load_addr_packet <= load_addr_packet_in;
        end
    end

endmodule // alu

`include "verilog/sys_defs.svh"

module load_addr_stage (
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
    
    DATA opa, opb;

    BYTE_MASK temp_byte_mask;

    assign load_addr_free = (load_buffer_free & load_data_free) | ~load_addr_packet.valid;

    assign load_data_packet.valid = load_addr_packet.valid;
    assign load_data_packet.dest_reg_idx = load_addr_packet.dest_reg_idx;
    assign load_data_packet.bm = load_addr_packet.bm;
    assign load_data_packet.load_addr = opa + opb;
    assign load_data_packet.byte_mask = temp << load_data_packet.load_addr.w.offset;
    assign load_data_packet.sq_tail = load_addr_packet.sq_tail;

    // ALU opA mux
    always_comb begin
        case (load_addr_packet.opa_select)
            OPA_IS_RS1:  opa = load_addr_packet.source_reg_1;
            // OPA_IS_NPC:  opa = load_addr_packet.NPC; 
            // OPA_IS_PC:   opa = load_addr_packet.PC;
            OPA_IS_ZERO: opa = 0;
            default:     opa = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (load_addr_packet.opb_select)
            OPB_IS_RS2:   opb = load_addr_packet.source_reg_2;
            OPB_IS_I_IMM: opb = `RV32_signext_Iimm(load_addr_packet.inst);
            OPB_IS_S_IMM: opb = `RV32_signext_Simm(load_addr_packet.inst);
            OPB_IS_B_IMM: opb = `RV32_signext_Bimm(load_addr_packet.inst);
            OPB_IS_U_IMM: opb = `RV32_signext_Uimm(load_addr_packet.inst);
            OPB_IS_J_IMM: opb = `RV32_signext_Jimm(load_addr_packet.inst);
            default:      opb = 32'hfacefeed; // face feed
        endcase
    end

    always_comb begin
        case (MEM_SIZE(load_addr_packet.inst.r.funct3[1:0]))
            BYTE:       temp_byte_mask = 4'b0001;
            HALF:       temp_byte_mask = 4'b0011;
            WORD:       temp_byte_mask = 4'b1111;
            default:    temp_byte_mask = 4'b0000;
        endcase
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            load_addr_packet <= NOP_LOAD_ADDR_PACKET;
        end else if (!load_addr_free) begin
            load_addr_packet <= load_addr_packet_in;
        end
    end

endmodule // alu
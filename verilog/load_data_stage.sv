
`include "verilog/sys_defs.svh"

module load_data_stage (
    input LOAD_DATA_PACKET          load_data_packet_in,
    input logic                     cache_load_accepted,
    input DATA                      cache_load_data,
    input BYTE_MASK                 cache_data_mask,
    input MSHR_IDX                  cache_mshr_idx,
    input DATA                      sq_load_data,
    input BYTE_MASK                 sq_data_mask,

    
    output ADDR                     load_addr,
    output logic [`SQ_IDX_BITS-1:0] load_sq_tail,
    output LB_PACKET                load_buffer_packet,
    output logic                    load_data_backpressure
);
    //ldback press
    assign load_data_backpressure = load_packet.valid && !cache_load_accepted;

    assign alu_result.completing_reg = alu_packet.dest_reg_idx;
    assign alu_result.valid = alu_packet.valid;

    DATA opa, opb;

    // ALU opA mux
    always_comb begin
        case (alu_packet.opa_select)
            OPA_IS_RS1:  opa = alu_packet.source_reg_1;
            OPA_IS_NPC:  opa = alu_packet.NPC;
            OPA_IS_PC:   opa = alu_packet.PC;
            OPA_IS_ZERO: opa = 0;
            default:     opa = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (alu_packet.opb_select)
            OPB_IS_RS2:   opb = alu_packet.source_reg_2;
            OPB_IS_I_IMM: opb = `RV32_signext_Iimm(alu_packet.inst);
            OPB_IS_S_IMM: opb = `RV32_signext_Simm(alu_packet.inst);
            OPB_IS_B_IMM: opb = `RV32_signext_Bimm(alu_packet.inst);
            OPB_IS_U_IMM: opb = `RV32_signext_Uimm(alu_packet.inst);
            OPB_IS_J_IMM: opb = `RV32_signext_Jimm(alu_packet.inst);
            default:      opb = 32'hfacefeed; // face feed
        endcase
    end

    always_comb begin
        case (alu_packet.alu_func)
            ALU_ADD:  alu_result.result = opa + opb;
            ALU_SUB:  alu_result.result = opa - opb;
            ALU_AND:  alu_result.result = opa & opb;
            ALU_SLT:  alu_result.result = signed'(opa) < signed'(opb);
            ALU_SLTU: alu_result.result = opa < opb;
            ALU_OR:   alu_result.result = opa | opb;
            ALU_XOR:  alu_result.result = opa ^ opb;
            ALU_SRL:  alu_result.result = opa >> opb[4:0];
            ALU_SLL:  alu_result.result = opa << opb[4:0];
            ALU_SRA:  alu_result.result = signed'(opa) >>> opb[4:0]; // arithmetic from logical shift
            // here to prevent latches:
            default:  alu_result.result = 32'hfacebeec;
        endcase
    end

    always_ff @(posedge clock) begin
        if(reset) begin
            load_data_packet <= NOP_LOAD_DATA_PACKET;
        end else begin
            load_data_packet <= load_data_packet_in;
        end
    end

endmodule // alu
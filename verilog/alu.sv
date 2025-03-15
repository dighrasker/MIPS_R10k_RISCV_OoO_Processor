module alu (
    input ALU_PACKET alu_packet,
    output CDB_REG_PACKET result
);

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
        case (alu_packet.alu_flags.alu_func)
            ALU_ADD:  result = opa + opb;
            ALU_SUB:  result = opa - opb;
            ALU_AND:  result = opa & opb;
            ALU_SLT:  result = signed'(opa) < signed'(opb);
            ALU_SLTU: result = opa < opb;
            ALU_OR:   result = opa | opb;
            ALU_XOR:  result = opa ^ opb;
            ALU_SRL:  result = opa >> opb[4:0];
            ALU_SLL:  result = opa << opb[4:0];
            ALU_SRA:  result = signed'(opa) >>> opb[4:0]; // arithmetic from logical shift
            // here to prevent latches:
            default:  result = 32'hfacebeec;
        endcase
    end

endmodule // alu
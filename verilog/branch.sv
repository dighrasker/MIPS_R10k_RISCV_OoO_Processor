module branch (
    input  BRANCH_PACKET     branch_packet,
    output BRANCH_REG_PACKET branch_reg_result,
    output CDB_REG_PACKET    branch_result // True/False condition result
);

    DATA opa, opb;

    // ALU opA mux
    always_comb begin
        case (branch_packet.opa_select)
            OPA_IS_RS1:  opa = branch_packet.source_reg_1;
            OPA_IS_NPC:  opa = branch_packet.NPC;
            OPA_IS_PC:   opa = branch_packet.PC;
            OPA_IS_ZERO: opa = 0;
            default:     opa = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (branch_packet.opb_select)
            OPB_IS_RS2:   opb = branch_packet.source_reg_2;
            OPB_IS_I_IMM: opb = `RV32_signext_Iimm(branch_packet.inst);
            OPB_IS_S_IMM: opb = `RV32_signext_Simm(branch_packet.inst);
            OPB_IS_B_IMM: opb = `RV32_signext_Bimm(branch_packet.inst);
            OPB_IS_U_IMM: opb = `RV32_signext_Uimm(branch_packet.inst);
            OPB_IS_J_IMM: opb = `RV32_signext_Jimm(branch_packet.inst);
            default:      opb = 32'hfacefeed; // face feed
        endcase
    end

    assign branch_result.result = opa + opb;

    always_comb begin
        if(branch_packet.conditional) begin
            case (branch_packet.branch_func)
                3'b000:  take = signed'(branch_packet.source_reg_1) == signed'(branch_packet.source_reg_2); // BEQ
                3'b001:  take = signed'(branch_packet.source_reg_1) != signed'(branch_packet.source_reg_2); // BNE
                3'b100:  take = signed'(branch_packet.source_reg_1) <  signed'(branch_packet.source_reg_2); // BLT
                3'b101:  take = signed'(branch_packet.source_reg_1) >= signed'(branch_packet.source_reg_2); // BGE
                3'b110:  take = branch_packet.source_reg_1 < branch_packet.source_reg_2;                    // BLTU
                3'b111:  take = branch_packet.source_reg_1 >= branch_packet.source_reg_2;                   // BGEU
                default: take = `FALSE;
            endcase
        end else begin
            take = `TRUE;
        end

        branch_result.result = branch_packet.NPC;
        branch_result.completing_reg = branch_packet.completing_reg;
        branch_result.valid = branch_packet.valid;

        branch_reg_result.target_PC = opa + opb;
        branch_reg_result.bmm = branch_packet.bmm;
        branch_reg_result.bm_mispred = branch_packet.taken != take;
        branch_reg_result.taken = branch_packet.taken;
        branch_reg_result.valid = branch_packet.valid;
    end

endmodule // conditional_branch
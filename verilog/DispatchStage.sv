`include "sys_defs.svh"

module Dispatch #(
    
) (
    input   logic                               clock,
    input   logic                               reset,

    // ------------ FROM INSTRUCTION BUFFER ------------- //
    input   FETCH_PACKET                        instruction_packets,
    input   logic        [`NUM_SCALAR_BITS-1:0] instructions_valid,

    // ------------ TO/FROM BRANCH STACK ------------- //
    input   PHYS_REG_IDX    [`ARCH_REG_SZ_R10K] map_table_restore,
    input   logic                               restore_valid,
    input   B_MASK                              b_mask_combinational,
    output  BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack_entries,
    output  B_MASK                              next_b_mask,

    // ------------ TO/FROM ROB ------------- //
    input   logic            [`ROB_SZ_BITS-1:0] rob_tail,
    input   logic        [`NUM_SCALAR_BITS-1:0] rob_spots,
    output  ROB_ENTRY_PACKET           [`N-1:0] rob_entries,

    // ------------ TO/FROM RS ------------- //
    output  RS_PACKET                  [`N-1:0] rs_entries,
    input   logic        [`NUM_SCALAR_BITS-1:0] rs_spots,

    // ------------ TO/FROM FREDDY LIST ------------- //
    input   logic        [`NUM_SCALAR_BITS-1:0] num_regs_available,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] next_complete_list,
    input   PHYS_REG_IDX               [`N-1:0] regs_to_use,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] free_list_copy,
    output  logic       [`PHYS_REG_SZ_R10K-1:0] updated_free_list,
    
    // ------------ FROM ISSUE? ------------- //
    input   logic       [`NUM_SCALAR_BITS-1:0] num_issuing,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    output   logic       [`NUM_SCALAR_BITS-1:0] num_dispatched
);

    //Should have a decoder module inside here or maybe we decode in Fetch?

    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table, next_map_table;

    //insert decoder module here
    //N Inputs are raw instruction 32 bit data from front of fetch buffer
    //Outputs are fully decoded packets which should go straight into an RS packet
    // TODO: Replace every "decoder_out" when decoder is done
    
    // For BS entry ordering

    
    logic bs_empty;
    logic [`B_MASK_WIDTH-1:0] gnt;
    logic [`B_MASK_ID_BITS-1:0] empty_bs_index;
    logic [`B_MASK_WIDTH-1:0] psel_output; // might be useless

    /* -------------------- DECODER ---------------------------*/

    INST           [`N-1:0] inst;      
    logic          [`N-1:0] valid; // when low, ignore inst. Output will look like a NOP
   
    for(i = 0; i < `N; ++i) begin
        assign inst[i] = instruction_packets[i].inst;
        assign valid[i] = (i < instructions_valid) ? 1 : 0;
    end

    ADDR           [`N-1:0] PC;
    ADDR           [`N-1:0] NPC; //Only use one or the other

    ALU_OPA_SELECT [`N-1:0] opa_select;
    ALU_OPB_SELECT [`N-1:0] opb_select;
    logic          [`N-1:0] has_dest; // if there is a destination register
    ALU_FUNC       [`N-1:0] alu_func;
    logic          [`N-1:0] mult, rd_mem, wr_mem, cond_branch, uncond_branch;
    logic          [`N-1:0] csr_op; // used for CSR operations, we only use this as a cheap way to get the return code out
    logic          [`N-1:0] halt;   // non-zero on a halt
    logic          [`N-1:0] illegal; // non-zero on an illegal instruction

    decoder decoder_inst [`N-1:0](
        .inst(inst),
        .valid(valid),
        .opa_select(opa_select),
        .opb_select(opb_select),
        .has_dest(has_dest),
        .alu_func(alu_func),
        .mult(mult),
        .rd_mem(rd_mem),
        .wr_mem(wr_mem),
        .cond_branch(cond_branch),
        .uncond_branch(uncond_branch),
        .csr_op(csr_op),
        .halt(halt),
        .illegal(illegal)
    );

    logic [`N-1:0] is_rs1_used, is_rs2_used;
    ARCH_REG_IDX [`N-1:0] source1_arch_reg, source2_arch_reg, dest_arch_reg;
    FU_TYPE [`N-1:0] fu_type;

    for(int i = 0; i < `N; ++i) begin
        assign is_rs1_used[i] = cond_branch[i] || (opa_select[i] == OPA_IS_RS1);
        assign is_rs2_used[i] = cond_branch[i] || wr_mem[i] || (opb_select[i] == OPB_IS_RS2);
        assign source1_arch_reg[i] = inst[i].r.rs1;
        assign source2_arch_reg[i] = inst[i].r.rs2;
        assign dest_arch_reg[i] = inst[i].r.rd;

        assign fu_type[i] = (cond_branch[i] || uncond_branch[i]) ? BU :
                                        (rd_mem[i] || wr_mem[i]) ? LDST :
                                                       (mult[i]) ? MULT :
                                                                   ALU;
    end

/*-------------------------------------------------------*/

    psel_gen #(
         .WIDTH(`B_MASK_WIDTH),  // The width of the request bus
         .REQS(1) // The number of requests that can be simultaenously granted
    ) psel_inst (
         .req(~next_b_mask), // Input request bus
         .gnt(gnt),          // Output with all granted requests on a bus
         .gnt_bus(psel_output),  // Output bus for each request
         .empty(bs_empty)       // Output asserted when there are no requests
    );

    encoder #(
        .INPUT_LENGTH(`B_MASK_WIDTH),
        .OUTPUT_LENGTH(`B_MASK_ID_BITS)
    ) encoder_inst (
        .in(gnt),
        .out(empty_bs_index)
    );

    logic [`NUM_SCALAR_BITS-1:0] i_num_dispatched;

    logic [`NUM_SCALAR_BITS-1:0] min;           // min (rs_spots +num_issuing, rob_spots, instruction valid)

    assign min = (((rs_spots + num_issuing) <= rob_spots) && ((rs_spots + num_issuing) <= instructions_valid)) ? (rs_spots + num_issuing) :
                                ((rob_spots <= (rs_spots + num_issuing)) && (rob_spots <= instructions_valid)) ? rob_spots : instructions_valid;

    assign i_num_dispatched = restore_valid ? 0 : min; //if not restoring, num_dispatching = min (rs_entries, rob_entries, free_list)
    
    
    always_comb begin
        branch_stack_entries = '0;
        next_b_mask = b_mask_combinational;
        num_dispatched = 0;
        next_map_table = map_table;
        updated_free_list = free_list_copy;
        for (int i = 0; i < `N; ++i) begin
            if(i < i_num_dispatched) begin
                
                // Create rob/rs/branch-stack entries. probably will change this code
                
                //Create RS Packet
                rs_entries[i].inst = instruction_packets[i].inst;
                rs_entries[i].valid = valid[i];
                rs_entries[i].opa_select = opa_select[i];
                rs_entries[i].opb_select = opb_select[i];
                rs_entries[i].has_dest = has_dest[i];
                rs_entries[i].alu_func = alu_func[i];
                rs_entries[i].mult = mult[i];
                rs_entries[i].rd_mem = rd_mem[i];
                rs_entries[i].wr_mem = wr_mem[i];
                rs_entries[i].cond_branch = cond_branch[i];
                rs_entries[i].uncond_branch = uncond_branch[i];
                rs_entries[i].csr_op = csr_op[i];
                rs_entries[i].halt = halt[i];
                rs_entries[i].illegal = illegal[i];
                rs_entries[i].PC = instruction_packets[i].PC;
                rs_entries[i].NPC = instruction_packets[i].PC + 4;
                rs_entries[i].T_new = regs_to_use[i];
                rs_entries[i].Source1 = next_map_table[source1_arch_reg[i]];
                rs_entries[i].Source1_ready = is_rs1_used[i] ? next_complete_list[rs_entries[i].Source1] : 1;
                rs_entries[i].Source2 = next_map_table[source2_arch_reg[i]];
                rs_entries[i].Source2_ready = is_rs2_used[i] ? next_complete_list[rs_entries[i].Source2] : 1;
                rs_entries[i].b_mask = next_b_mask;
                rs_entries[i].b_mask_mask = '0;
                rs_entries[i].FU_type = fu_type[i];

                //Create ROB Packet
                /*
                    PHYS_REG_IDX    T_new; // Use as unique rob id
                    PHYS_REG_IDX    T_old;
                    ARCH_REG_IDX    Arch_reg;
                */
                rob_entries[i].T_new = regs_to_use[i];                          //this should be the output from freddy
                rob_entries[i].has_dest = has_dest[i];
                rob_entries[i].Arch_reg = dest_arch_reg[i];         //this should come from instruction dest_reg
                rob_entries[i].T_old = has_dest[i] ? next_map_table[dest_arch_reg[i]] : 0;      //this should be coming from map table


                // create the branch checkpoint
                if(cond_branch[i] || uncond_branch[i])begin // TODO: need to check 'branch' to an actual flag
                    if(~bs_empty) begin // checking that there is room in the BS
                    //allocate BS entry (snapshotting recovery PC, map table, rob_tail, free_list, b_m)
                    // empty_bs_index -> the index of the empty bs to put in smth
                        updated_free_list[regs_to_use[i]] = 0;
                        next_map_table[arch_dest_reg[i]] = has_dest[i] ? regs_to_use[i] : next_map_table[arch_dest_reg[i]];

                        branch_stack_entries[empty_bs_index].recovery_PC = instruction_packets[i].PC; // TODO: change to instruction PC
                        branch_stack_entries[empty_bs_index].rob_tail = (rob_tail + i) % `ROB_SZ;
                        branch_stack_entries[empty_bs_index].free_list = updated_free_list;
                        branch_stack_entries[empty_bs_index].map_table = next_map_table;
                        branch_stack_entries[empty_bs_index].b_m = next_b_mask;

                        rs_entries[i].b_mask_mask = psel_output;
                        
                        next_b_mask[empty_bs_index] = 1'b1;
                    end else begin
                        break;
                    end
                end
                
                updated_free_list[regs_to_use[i]] = 0;
                next_map_table[arch_dest_reg[i]] = has_dest[i] ? regs_to_use[i] : next_map_table[arch_dest_reg[i]];

                num_dispatched = i;

            end
        end
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i = 0; i < `ARCH_REG_SZ_R10K; ++i) begin
                map_table[i] <= i[`ARCH_REG_ID_BITS-1:0];
            end
        end else begin
            map_table <= next_map_table;
        end
    end

    //No sequential elements since this is a combinational stage

endmodule
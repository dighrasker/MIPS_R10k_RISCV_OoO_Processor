/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cpu.sv                                              //
//                                                                     //
//  Description :  Top-level module of the verisimple processor;       //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline together.                       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

module cpu (
    input clock, // System clock
    input reset, // System reset

    /*
    input MEM_TAG   mem2proc_transaction_tag, // Memory tag for current transaction
    input MEM_BLOCK mem2proc_data,            // Data coming back from memory
    input MEM_TAG   mem2proc_data_tag,        // Tag for which transaction data is for

    output MEM_COMMAND proc2mem_command, // Command sent to memory
    output ADDR        proc2mem_addr,    // Address sent to memory
    output MEM_BLOCK   proc2mem_data,    // Data sent to memory
    output MEM_SIZE    proc2mem_size,    // Data size sent to memory
    */

    // Note: these are assigned at the very bottom of the module
    output COMMIT_PACKET [`N-1:0] committed_insts,
    output ADDR          [`N-1:0] PC

    // Debug outputs: these signals are solely used for debugging in testbenches
    // Do not change for project 3
    // You should definitely change these for project 4
    /*output ADDR  if_NPC_dbg,
    output DATA  if_inst_dbg,
    output logic if_valid_dbg,
    output ADDR  if_id_NPC_dbg,
    output DATA  if_id_inst_dbg,
    output logic if_id_valid_dbg,
    output ADDR  id_ex_NPC_dbg,
    output DATA  id_ex_inst_dbg,
    output logic id_ex_valid_dbg,
    output ADDR  ex_mem_NPC_dbg,
    output DATA  ex_mem_inst_dbg,
    output logic ex_mem_valid_dbg,
    output ADDR  mem_wb_NPC_dbg,
    output DATA  mem_wb_inst_dbg,
    output logic mem_wb_valid_dbg*/
);

    // ONLY OUTPUTS ARE UNCOMMENTED

    /*------- ROB WIRES ----------*/

    // INPUT clock
    // INPUT reset
    // INPUT ROB_PACKET           [`N-1:0] rob_entries;
    // INPUT logic  [`NUM_SCALAR_BITS-1:0] num_dispatched;
    logic  [`NUM_SCALAR_BITS-1:0] rob_spots;
    logic      [`ROB_SZ_BITS-1:0] rob_tail;
    // INPUT logic  [`NUM_SCALAR_BITS-1:0] num_retiring;
    ROB_PACKET           [`N-1:0] rob_outputs;
    logic  [`NUM_SCALAR_BITS-1:0] rob_outputs_valid;
    // INPUT logic                         restore_valid;
    // INPUT logic      [`ROB_SZ_BITS-1:0] rob_tail_restore;

`ifdef DEBUG
    ROB_DEBUG                   rob_debug;
`endif

    /*------- RS WIRES ----------*/
    
    // INPUT clock
    // INPUT reset
    // INPUT logic  [`NUM_SCALAR_BITS-1:0] num_dispatched;
    // INPUT RS_PACKET            [`N-1:0] rs_entries;
    logic  [`NUM_SCALAR_BITS-1:0] rs_spots;

    // INPUT CDB_ETB_PACKET       [`N-1:0] cdb_completing;

    // INPUT logic           [`RS_SZ-1:0] rs_data_issuing;      // bit vector of rs_data that is being issued by issue stage
    RS_PACKET       [`RS_SZ-1:0] rs_data;              // The entire RS data 
    logic           [`RS_SZ-1:0] rs_valid_next;        // 1 if RS data is valid <-- Coded

    // INPUT B_MASK_MASK                   b_mm_out;
    // INPUT logic                         restore_valid;
`ifdef DEBUG
    RS_DEBUG               rs_debug;
`endif


    /*------- FREDDYLIST WIRES ----------*/

    // INPUT clock,
    // INPUT reset,
    // TODO:: DECIDE WHAT TO DO WITH CDB
    // INPUT PHYS_REG_IDX           [`N-1:0] phys_reg_completing,    // phys reg indexes that are being completed (T_new)
    // INPUT logic                  [`N-1:0] completing_valid,       // bit vector of N showing which phys_reg_completing is valid
    
    // INPUT PHYS_REG_IDX           [`N-1:0] phys_regs_retiring,      // phy reg indexes that are being retired (T_old)
    // INPUT logic    [`NUM_SCALAR_BITS-1:0] num_retiring_valid,     // number of retiring phys reg (T_old)

    // INPUT logic   [`PHYS_REG_SZ_R10K-1:0] freelist_restore,      // snapshot of freelist at mispredicted branch
    // INPUT logic                           restore_valid,           // branch mispredict flag

    // INPUT logic   [`PHYS_REG_SZ_R10K-1:0] updated_free_list,      // freelist from dispatch

    PHYS_REG_IDX           [`N-1:0] phys_regs_to_use,       // physical register indices for dispatch to use
    logic   [`PHYS_REG_SZ_R10K-1:0] free_list,              // bitvector of the phys reg that are complete

    logic   [`PHYS_REG_SZ_R10K-1:0] next_complete_list;          // bitvector of the phys reg that are complete
    logic   [`PHYS_REG_SZ_R10K-1:0] complete_list;

`ifdef DEBUG
    logic   [`PHYS_REG_SZ_R10K-1:0] debug_complete_list;
`endif
    

    /*------- BRANCH STACK WIRES ----------*/

    logic                         restore_valid;
    logic      [`ROB_SZ_BITS-1:0] rob_tail_restore;

    /*------- FETCH WIRES ----------*/

    /*------- INSTBUFFER WIRES ----------*/    
        //input   logic                        clock, 
        //input   logic                        reset,

        // ------------ TO/FROM FETCH ------------- //
        //input   FETCH_PACKET         [`N-1:0] inst_buffer_inputs,
        //input   logic  [`NUM_SCALAR_BITS-1:0] instructions_valid, //number of valid instructions fetch sends to instruction buffer     // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
        output  logic  [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,

        // ------------ FROM EXECUTE ------------- //
        //input   logic                         restore_valid,

        // ------------ TO/FROM DISPATCH -------- //
        //input   logic  [`NUM_SCALAR_BITS-1:0] num_dispatched,     //number of spots available in dispatch
        output  FETCH_PACKET         [`N-1:0] inst_buffer_outputs,   // For retire to check eligibility
        output  logic  [`NUM_SCALAR_BITS-1:0] outputs_valid,


         /*------- DECODER WIRES ----------*/
input  FETCH_PACKET  inst_buffer_input,
    output DECODE_PACKET decoder_out,
    output logic         is_rs1_used,
    output logic         is_rs2_used,
    output ARCH_REG_IDX  source1_arch_reg,
    output ARCH_REG_IDX  source2_arch_reg,
    output ARCH_REG_IDX  dest_arch_reg

    /*------- DISPATCH WIRES ----------*/

    ROB_PACKET           [`N-1:0] rob_entries;
    logic  [`NUM_SCALAR_BITS-1:0] num_dispatched;
    RS_PACKET            [`N-1:0] rs_entries;
    logic  [`NUM_SCALAR_BITS-1:0] rs_spots;


    /*------- ISSUE WIRES ----------*/
     
    // ------------- TO/FROM RS -------------- //
    output  wor                   [`RS_SZ-1:0] rs_data_issuing,     // set index to 1 when a rs_data is selected to be issued

    // ------------- TO/FROM REGFILE -------------- //
    

     DATA            [`NUM_FU_ALU-1:0] issue_alu_regs_reading_1,
     DATA            [`NUM_FU_ALU-1:0] issue_alu_regs_reading_2,
     DATA           [`NUM_FU_MULT-1:0] issue_mult_regs_reading_1,
     DATA           [`NUM_FU_MULT-1:0] issue_mult_regs_reading_2,
     DATA         [`NUM_FU_BRANCH-1:0] issue_branch_regs_reading_1,
     DATA         [`NUM_FU_BRANCH-1:0] issue_branch_regs_reading_2,
    
    // ------------- FROM CDB -------------- //


    // ------------- TO/FROM EXECUTE -------------- //
     logic                  [`NUM_FU_MULT-1:0] mult_cdb_gnt,
     logic                  [`NUM_FU_LDST-1:0] ldst_cdb_gnt,
     ALU_ENTRY_PACKET        [`NUM_FU_ALU-1:0] alu_packets,
     MULT_ENTRY_PACKET      [`NUM_FU_MULT-1:0] mult_packets,
     BRANCH_ENTRY_PACKET  [`NUM_FU_BRANCH-1:0] branch_packets,
    output LDST_ENTRY_PACKET      [`NUM_FU_LDST-1:0] ldst_packets,

    output logic [`N-1:0]        [`NUM_FU_TOTAL-1:0] complete_gnt_bus
    

    /*----------EXECUTE WIRES -------------*/
    
    logic              [`NUM_FU_MULT-1:0] mult_free;
    logic              [`NUM_FU_LDST-1:0] ldst_free;
    CDB_ETB_PACKET               [`N-1:0] cdb_completing;
    CDB_REG_PACKET               [`N-1:0] cdb_reg;
    BRANCH_REG_PACKET                     branch_reg;

    /*------- COMPLETE WIRES ----------*/

    /*------- RETIRE WIRES ----------*/

    logic  [`NUM_SCALAR_BITS-1:0] num_retiring;

    //////////////////////////////////////////////////
    //                                              //
    //               DATA STRUCTURES                //
    //                                              //
    //////////////////////////////////////////////////


    /*----------------Reorder Buffer----------------*/

    rob rob (
        .clock             (clock),
        .reset             (reset),
        .rob_inputs        (rob_entries),
        .rob_inputs_valid  (num_dispatched), 
        .rob_spots         (rob_spots),
        .rob_tail          (rob_tail),
        .num_retiring      (num_retiring),
        .rob_outputs       (rob_outputs),
        .rob_outputs_valid (rob_outputs_valid),
        .tail_restore_valid(restore_valid),
        .tail_restore      (rob_tail_restore)
    `ifdef DEBUG
        ,.rob_debug         (rob_debug)
    `endif
    );


    /*---------------Reservation Station------------*/

    rs rs (
        .clock             (clock),
        .reset             (reset),
        .num_dispatched    (num_dispatched),
        .rs_entries        (rs_entries), 
        .rs_spots          (rs_spots),
        .ETB_tags          (cdb_completing),
        .rs_data_issuing   (rs_data_issuing),
        .rs_data           (rs_data),
        .rs_valid_next     (rs_valid_next),
        .b_mm_resolve      (b_mm_out),
        .b_mm_mispred      (restore_valid)
    `ifdef DEBUG
        ,.rs_debug          (rs_debug)
    `endif
    );


    /*-------------Freddy List--------------------*/

    freddylist fl (
        .clock                  (clock),
        .reset                  (reset),
        .phys_reg_completing    (phys_reg_completing),
        .completing_valid       (completing_valid), 
        .phys_reg_retiring      (phys_regs_retiring),
        .num_retiring_valid     (num_retiring_valid),
        .free_list_restore      (free_list_restore),
        .restore_flag           (restore_flag),
        .updated_free_list      (updated_free_list),
        .phys_regs_to_use       (phys_regs_to_use),
        .free_list              (free_list),
        .complete_list          (complete_list)
    );


    /*-------------Branch Stack--------------------*/

    branchstack bs (
        .clock(clock),
        .reset(reset),
        .PC_restore(PC_restore),
        .b_mm_resolve(b_mm_resolve),
        .b_mm_mispred(b_mm_mispred),
        .rob_tail_restore(rob_tail_restore),
        .restore_valid(restore_valid),
        .freelist_restore(freelist_restore),
        .branch_stack_entries(branch_stack_entries),
        .next_b_mask(next_b_mask),
        .map_table_restore(map_table_restore),
        .b_mask_combinational(b_mask_combinational),
        .bs_debug(bs_debug)
    );

    /*------------------Reg File --------------------*/
    regfile regfile_instance (
        .clock(clock),
        .reset(reset),
        .retire_phys_regs_reading(retire_phys_regs_reading),
        .retire_read_data(retire_read_data),
        .issue_alu_phys_regs_reading_1(issue_alu_phys_regs_reading_1),
        .issue_alu_phys_regs_reading_2(issue_alu_phys_regs_reading_2),
        .issue_alu_read_data_1(issue_alu_read_data_1),
        .issue_alu_read_data_2(issue_alu_read_data_2),
        .issue_branch_phys_regs_reading_1(issue_branch_phys_regs_reading_1),
        .issue_branch_phys_regs_reading_2(issue_branch_phys_regs_reading_2),
        .issue_branch_read_data_1(issue_branch_read_data_1),
        .issue_branch_read_data_2(issue_branch_read_data_2),
        .issue_mult_phys_regs_reading_1(issue_mult_phys_regs_reading_1),
        .issue_mult_phys_regs_reading_2(issue_mult_phys_regs_reading_2),
        .issue_mult_read_data_1(issue_mult_read_data_1),
        .issue_mult_read_data_2(issue_mult_read_data_2),
        .phys_regs_completing(phys_regs_completing),
        .write_en(write_en),
        .write_data(write_data)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  FETCH                       //
    //                                              //
    //////////////////////////////////////////////////

    Fetch fetch_stage(

        .clock(clock), 
        .reset(reset),

        // ------------ TO/FROM MEMORY ------------- //
        .i_buffer_inputs(i_buffer_inputs),    // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
        .inputs_valid(inputs_valid),  // To distinguish invalid instructions being passed in from Dispatch (A number, NOT one hot)
        .PC_reg(PC_reg),
        
        // ------------- FROM BRANCH STACK -------------- //
        .recovery_PC(recovery_PC),  // Retire module tells the ROB how many entries can be cleared
        
        // ------------ FROM EXECUTE ------------- //
        .target_PC(target_PC),
        .mispredict(mispredict),
        .taken(taken),            //original prediction was taken

        // ------------ TO/FROM DISPATCH ------------- //
        .i_buffer_outputs(i_buffer_outputs),   // For retire to check eligibility
        .outputs_valid(outputs_valid), // If not all N rob entries are valid entries they should not be considered  
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  INSTBUFFER                  //
    //                                              //
    //////////////////////////////////////////////////


    instbuffer inst_buffer(
        .clock(clock), 
        .reset(reset),

        // ------------ TO/FROM FETCH ------------- //
        .inst_buffer_inputs(inst_buffer_inputs),
        .insttructions_valid(instructions_valid), //number of valid instructions fetch sends to instruction buffer     // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
        output  logic  [`NUM_SCALAR_BITS-1:0] inst_buffer_spots,

        // ------------ FROM EXECUTE ------------- //
        input   logic                         restore_valid,

        // ------------ TO/FROM DISPATCH -------- //
        input   logic  [`NUM_SCALAR_BITS-1:0] num_dispatched,     //number of spots available in dispatch
        output  FETCH_PACKET         [`N-1:0] inst_buffer_outputs,   // For retire to check eligibility
        output  logic  [`NUM_SCALAR_BITS-1:0] outputs_valid, // If not all N FB entries are valid entries they should not be considered 
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  DECODER                     //
    //                                              //
    //////////////////////////////////////////////////
    
    decoder #() decode [`N-1:0] (
        .inst_buffer_input(),
        .decoder_out(),
        .is_rs1_used(),
        .is_rs2_used(),
        .source1_arch_reg(),
        .source2_arch_reg(),
        .dest_arch_reg()
    );


    //////////////////////////////////////////////////
    //                                              //
    //                  DISPATCH                    //
    //                                              //
    //////////////////////////////////////////////////

    Dispatch dispatch_stage (
        .clock                (clock),
        .reset                (reset),
        .instruction_packets  (instruction_packets),
        .instructions_valid   (instructions_valid), 
        .map_table_restore    (map_table_restore),
        .restore_valid        (restore_valid),
        .b_mask_combinational (b_mask_combinational),
        .branch_stack_entries (branch_stack_entries),
        .next_b_mask          (next_b_mask),
        .rob_tail             (rob_tail),
        .rob_spots            (rob_spots),
        .rob_entries          (rob_entries),
        .rs_entries           (rs_entries),
        .rs_spots             (rs_spots),
        .num_regs_available   (num_regs_available),
        .next_complete_list   (next_complete_list),
        .regs_to_use          (regs_to_use),
        .free_list_copy       (free_list_copy),
        .updated_free_list    (updated_free_list),
        .num_issuing          (num_issuing),
        .num_dispatched       (num_dispatched),
        .dispatch_debug       (dispatch_debug)
    );



    //////////////////////////////////////////////////
    //                                              //
    //                  ISSUE                       //
    //                                              //
    //////////////////////////////////////////////////
    
   

    Issue issue_instance (
        // ------------- FROM FREDDY -------------- //
        .complete_list(complete_list),

        // ------------- TO/FROM RS -------------- //
        .rs_data(rs_data),
        .rs_valid_next(rs_valid_next),
        .rs_data_issuing(rs_data_issuing),
        // ------------- TO/FROM REGFILE -------------- //
        .issue_alu_read_data_1(issue_alu_read_data_1),
        .issue_alu_read_data_2(issue_alu_read_data_2),
        .issue_mult_read_data_1(issue_mult_read_data_1),
        .issue_mult_read_data_2(issue_mult_read_data_2),
        .issue_branch_read_data_1(issue_branch_read_data_1),
        .issue_branch_read_data_2(issue_branch_read_data_2),
        .issue_alu_regs_reading_1(issue_alu_regs_reading_1),
        .issue_alu_regs_reading_2(issue_alu_regs_reading_2),
        .issue_mult_regs_reading_1(issue_mult_regs_reading_1),
        .issue_mult_regs_reading_2(issue_mult_regs_reading_2),
        .issue_branch_regs_reading_1(issue_branch_regs_reading_1),
        .issue_branch_regs_reading_2(issue_branch_regs_reading_2),
         // ------------- FROM CDB -------------- //
        .CDB_data_forwarded(CDB_data_forwarded),
        .CDB_tags_forwarded(CDB_tags_forwarded),
        // ------------- TO/FROM EXECUTE -------------- //
        .mult_free(mult_free),
        .ldst_free(ldst_free),
        .mult_cdb_req(mult_cdb_req),
        .ldst_cdb_req(ldst_cdb_req),
        .mult_cdb_gnt(mult_cdb_gnt),
        .ldst_cdb_gnt(ldst_cdb_gnt),
        .alu_packets(alu_packets),
        .mult_packets(mult_packets),
        .branch_packets(branch_packets),
        .ldst_packets(ldst_packets),
        .complete_gnt_bus(complete_gnt_bus)
    );
    
    //////////////////////////////////////////////////
    //                                              //
    //                  EXECUTE                     //
    //                                              //
    //////////////////////////////////////////////////

    ExecuteStage execute_instance (
        .clock(clock),
        .reset(reset),
        // --------------- TO/FROM ISSUE --------------- //
        .mult_packets_issuing_in(mult_packets_issuing_in),
        .alu_packets_issuing_in(alu_packets_issuing_in),
        .branch_packets_issuing_in(branch_packets_issuing_in),
        .mult_cdb_en(mult_cdb_en),
        .complete_gnt_bus(complete_gnt_bus_exec),
        .mult_free(mult_free),
        .ldst_free(ldst_free),
        .cdb_completing(cdb_completing),
        .cdb_reg(cdb_reg),
        .b_mm_resolve(b_mm_resolve),
        .b_mm_mispred(b_mm_mispred),
        .branch_reg(branch_reg)
    );

    //////////////////////////////////////////////////
    //                                              //
    //                  RETIRE                      //
    //                                              //
    //////////////////////////////////////////////////

    retire retire_stage (
        .clock                (clock),
        .reset                (reset),
    // ------------- TO/FROM ROB -------------- //

        .rob_outputs(rob_outputs),
        .rob_outputs_valid(rob_outputs_valid),             // Coming from rob, to check which output is valid, only valid rob outputs can be retired
        .num_retiring(num_retiring),                  // Send to rob, how many rob_outputs can be retired

    // ------------- TO/FROM FREDDYLIST -------------- //
        .complete_list_exposed(),         // Coming from freddylist, to find out which rob_output is actually completed and ready to retire
        .phys_regs_retiring(),             // Send to freddylist, which physical registers are being retired

    // ------------- TO CPU -------------- //
        .committed_insts(),

    /*---------------- FROM/TO REGFILE ---------------------------*/
        .retire_phys_regs_reading(),
        .retire_read_data()
    );

    //////////////////////////////////////////////////
    //                                              //
    //               Pipeline Outputs               //
    //                                              //
    //////////////////////////////////////////////////

    // Output the committed instruction to the testbench for counting
    assign committed_insts[0] = wb_packet;

endmodule // pipeline

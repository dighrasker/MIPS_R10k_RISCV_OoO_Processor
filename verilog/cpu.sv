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
    output ADDR             

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

    //////////////////////////////////////////////////
    //                                              //
    //                Pipeline Wires                //
    //                                              //
    //////////////////////////////////////////////////

    // Pipeline register enables
    logic if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;

    // From IF stage to memory
    MEM_COMMAND Imem_command; // Command sent to memory

    // Outputs from IF-Stage and IF/ID Pipeline Register
    ADDR Imem_addr;
    IF_ID_PACKET if_packet, if_id_reg;

    // Outputs from ID stage and ID/EX Pipeline Register
    ID_EX_PACKET id_packet, id_ex_reg;

    // Outputs from EX-Stage and EX/MEM Pipeline Register
    EX_MEM_PACKET ex_packet, ex_mem_reg;

    // Outputs from MEM-Stage and MEM/WB Pipeline Register
    MEM_WB_PACKET mem_packet, mem_wb_reg;

    // Outputs from MEM-Stage to memory
    ADDR        Dmem_addr;
    MEM_BLOCK   Dmem_store_data;
    MEM_COMMAND Dmem_command;
    MEM_SIZE    Dmem_size;

    // Outputs from WB-Stage (These loop back to the register file in ID)
    COMMIT_PACKET wb_packet;

    // Logic for stalling memory stage
    logic       load_stall;
    logic       new_load;
    logic       mem_tag_match;
    logic       rd_mem_q;       // previous load
    MEM_TAG     outstanding_mem_tag;    // tag load is waiting in
    MEM_COMMAND Dmem_command_filtered;  // removes redundant loads

    //////////////////////////////////////////////////
    //                                              //
    //                Memory Outputs                //
    //                                              //
    //////////////////////////////////////////////////

    // these signals go to and from the processor and memory
    // we give precedence to the mem stage over instruction fetch
    // note that there is no latency in project 3
    // but there will be a 100ns latency in project 4

    always_comb begin
        if (Dmem_command != MEM_NONE) begin  // read or write DATA from memory
            proc2mem_command = Dmem_command_filtered;
            proc2mem_size    = Dmem_size;
            proc2mem_addr    = Dmem_addr;
        end else begin                      // read an INSTRUCTION from memory
            proc2mem_command = Imem_command;
            proc2mem_addr    = Imem_addr;
            proc2mem_size    = DOUBLE;      // instructions load a full memory line (64 bits)
        end
        proc2mem_data = Dmem_store_data;
    end

    //////////////////////////////////////////////////
    //                                              //
    //                  Valid Bit                   //
    //                                              //
    //////////////////////////////////////////////////

    // This state controls the stall signal that artificially forces IF
    // to stall until the previous instruction has completed.
    // For project 3, start by assigning if_valid to always be 1

    logic if_valid, start_valid_on_reset, wb_valid;


    always_ff @(posedge clock) begin
        // Start valid on reset. Other stages (ID,EX,MEM,WB) start as invalid
        // Using a separate always_ff is necessary since if_valid is combinational
        // Assigning if_valid = reset doesn't work as you'd hope :/
        start_valid_on_reset <= reset;
    end

    // valid bit will cycle through the pipeline and come back from the wb stage
    assign if_valid = start_valid_on_reset || wb_valid;

    //////////////////////////////////////////////////
    //                                              //
    //                  IF-Stage                    //
    //                                              //
    //////////////////////////////////////////////////

    stage_if stage_if_0 (
        // Inputs
        .clock (clock),
        .reset (reset),
        .if_valid      (if_valid),
        .take_branch   (ex_mem_reg.take_branch),
        .branch_target (ex_mem_reg.alu_result),
        .Imem_data     (mem2proc_data),
        
        .Imem2proc_transaction_tag(mem2proc_transaction_tag),
        .Imem2proc_data_tag       (mem2proc_data_tag),

        // Outputs
        .Imem_command  (Imem_command),
        .if_packet     (if_packet),
        .Imem_addr     (Imem_addr)
    );

    // debug outputs
    assign if_NPC_dbg   = if_packet.NPC;
    assign if_inst_dbg  = if_packet.inst;
    assign if_valid_dbg = if_packet.valid;

    //////////////////////////////////////////////////
    //                                              //
    //            IF/ID Pipeline Register           //
    //                                              //
    //////////////////////////////////////////////////

    assign if_id_enable = !load_stall;

    always_ff @(posedge clock) begin
        if (reset) begin
            if_id_reg.inst  <= `NOP;
            if_id_reg.valid <= `FALSE;
            if_id_reg.NPC   <= 0;
            if_id_reg.PC    <= 0;
        end else if (if_id_enable) begin
            if_id_reg <= if_packet;
        end
    end

    // debug outputs
    assign if_id_NPC_dbg   = if_id_reg.NPC;
    assign if_id_inst_dbg  = if_id_reg.inst;
    assign if_id_valid_dbg = if_id_reg.valid;

    //////////////////////////////////////////////////
    //                                              //
    //            REGs & WIREs STRUCTURES           //
    //                                              //
    //////////////////////////////////////////////////

    // ONLY OUTPUTS ARE UNCOMMENTED

    /*------- ROB SHIT ----------*/
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

    /*------- RS SHIT ----------*/
    // INPUT logic  [`NUM_SCALAR_BITS-1:0] num_dispatched;
    // INPUT RS_PACKET            [`N-1:0] rs_entries;
    // INPUT logic  [`NUM_SCALAR_BITS-1:0] rs_spots;


    /*------- FREDDYLIST SHIT ----------*/

    /*------- BRANCH STACK SHIT ----------*/

    logic                         restore_valid;
    logic      [`ROB_SZ_BITS-1:0] rob_tail_restore;

    /*------- FETCH SHIT ----------*/

    /*------- DISPATCH SHIT ----------*/

    ROB_PACKET           [`N-1:0] rob_entries;
    logic  [`NUM_SCALAR_BITS-1:0] num_dispatched;
    RS_PACKET            [`N-1:0] rs_entries;
    logic  [`NUM_SCALAR_BITS-1:0] rs_spots;


    /*------- ISSUE SHIT ----------*/

    /*------- COMPLETE SHIT ----------*/

    /*------- RETIRE SHIT ----------*/

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
        .tail_restore      (rob_tail_restore),
        .rob_debug         (rob_debug)
    );


    /*---------------Reservation Station------------*/

    rs rs (
        .clock             (clock),
        .reset             (reset),
        .num_dispatched    (num_dispatched),
        .rs_entries        (rs_entries), 
        .rs_spots          (rs_spots),
        .CDB_tags          (CDB_tags),
        .CDB_valid         (CDB_valid),
        .rs_data_issuing   (rs_data_issuing),
        .rs_data           (rs_data),
        .rs_valid_next     (rs_valid_next),
        .b_mm_resolve      (b_mm_resolve),
        .b_mm_mispred      (b_mm_mispred),
        .rs_debug          (rs_debug)
    );


    /*-------------Freddy List--------------------*/

    freddylist fl (
        .clock                  (clock),
        .reset                  (reset),
        .phys_reg_completing    (phys_reg_completing),
        .completing_valid       (completing_valid), 
        .phys_reg_retiring      (phys_reg_retiring),
        .num_retiring_valid     (num_retiring_valid),
        .free_list_restore      (free_list_restore),
        .restore_flag           (restore_flag),
        .updated_free_list      (updated_free_list),
        // .num_dispatched         (num_dispatched),
        .phys_regs_to_use       (phys_regs_to_use),
        .free_list              (free_list),
        .complete_list          (complete_list)
    );


    /*-------------Branch Stack--------------------*/

    branchstack dut (
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

    //////////////////////////////////////////////////
    //                                              //
    //                  COMPLETE                    //
    //                                              //
    //////////////////////////////////////////////////

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
        .complete_list_exposed,         // Coming from freddylist, to find out which rob_output is actually completed and ready to retire
        .phys_regs_retiring,             // Send to freddylist, which physical registers are being retired

    // ------------- TO CPU -------------- //
        .committed_insts,

    /*---------------- FROM/TO REGFILE ---------------------------*/
        .retire_phys_regs_reading,
        .retire_read_data
    );

    //////////////////////////////////////////////////
    //                                              //
    //               Pipeline Outputs               //
    //                                              //
    //////////////////////////////////////////////////

    // Output the committed instruction to the testbench for counting
    assign committed_insts[0] = wb_packet;

endmodule // pipeline

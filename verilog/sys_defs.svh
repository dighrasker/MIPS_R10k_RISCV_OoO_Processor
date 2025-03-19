/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file defines macros and data structures used   //
//                 throughout the processor.                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////
`define DEBUG //Comment out when synthesizing

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define N 2
`define B_MASK_WIDTH 4
`define NUM_B_MASK_BITS $clog2(`B_MASK_WIDTH + 1)
`define CDB_SZ `N // This MUST match your superscalar width
`define NUM_SCALAR_BITS $clog2(`N+1) // Number of bits to represent [0, NUM_SCALAR_BITS]
`define PC_STEP 12

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_BRANCH 1
`define NUM_FU_ALU `N
`define NUM_FU_MULT `N
`define NUM_FU_LDST 1
`define NUM_FU_LOAD 0
`define NUM_FU_STORE 0
`define NUM_FU_TOTAL `NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_BRANCH +`NUM_FU_LDST

// sizes
`define FB_SZ 32
`define FB_SZ_BITS $clog2(`FB_SZ)
`define ROB_SZ 32
`define ROB_SZ_BITS $clog2(`ROB_SZ)
`define ROB_NUM_ENTRIES_BITS $clog2(`ROB_SZ + 1)
`define RS_SZ 32
`define RS_SZ_BITS $clog2(`RS_SZ)
`define RS_NUM_ENTRIES_BITS $clog2(`RS_SZ + 1)
`define ARCH_REG_SZ_R10K (32)
`define PHYS_REG_SZ_P6 32
`define PHYS_REG_SZ_R10K (`ARCH_REG_SZ_R10K + `ROB_SZ)
`define PHYS_REG_NUM_ENTRIES_BITS $clog2(`PHYS_REG_SZ_R10K + 1)
`define CDB_ARBITER_SZ `RS_SZ + `NUM_FU_MULT + `NUM_FU_LDST


// EDITED HERE
`define ROB_ENTRY_ID_BITS $clog2(`ROB_SZ)
`define PHYS_REG_ID_BITS $clog2(`PHYS_REG_SZ_R10K)
`define B_MASK_ID_BITS $clog2(`B_MASK_WIDTH)
`define ARCH_REG_ID_BITS $clog2(32) // Assuming # arch reg = 32
`define FU_ID_BITS $clog2(`NUM_FU_TOTAL)

typedef logic [`ROB_ENTRY_ID_BITS-1:0]      ROB_ENTRY_ID;
typedef logic [`PHYS_REG_ID_BITS-1:0]       PHYS_REG_IDX;
typedef logic [`ARCH_REG_ID_BITS-1:0]       ARCH_REG_IDX;
typedef logic [6:0]                         OPCODE;
typedef logic [`B_MASK_WIDTH-1:0]           B_MASK;
typedef logic [`B_MASK_WIDTH-1:0]           B_MASK_MASK;
typedef logic [2:0]                         BRANCH_FUNC;
typedef logic [`FU_ID_BITS-1:0]             FU_IDX;

typedef enum logic [1:0] {
    ALU   = 2'h0,
    MULT   = 2'h1,
    BU   = 2'h2,
    LDST = 2'h3
} FU_TYPE;

// EDITED END

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ xx

// number of mult stages (2, 4) (you likely don't need 8)
`define MULT_STAGES 8

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// word and register sizes
typedef logic [31:0] ADDR;
typedef logic [31:0] DATA;
typedef logic [19:0] IMM;
typedef logic [4:0] REG_IDX;

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
// TODO: uncomment this line once you've implemented your cache
//`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
//`define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// memory tags represent a unique id for outstanding mem transactions
// 0 is a sentinel value and is not a valid tag
`define NUM_MEM_TAGS 15
typedef logic [3:0] MEM_TAG;

// icache definitions
`define ICACHE_LINES 32
`define ICACHE_LINE_BITS $clog2(`ICACHE_LINES)

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)

// A memory or cache block
typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
    logic      [63:0] dbbl_level;
} MEM_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    MEM_NONE   = 2'h0,
    MEM_LOAD   = 2'h1,
    MEM_STORE  = 2'h2
} MEM_COMMAND;

// icache tag struct
typedef struct packed {
    logic [12-`ICACHE_LINE_BITS:0] tags;
    logic                          valid;
} ICACHE_TAG;

///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code
typedef enum logic [3:0] {
    ALU_ADD     = 4'h0,
    ALU_SUB     = 4'h1,
    ALU_SLT     = 4'h2,
    ALU_SLTU    = 4'h3,
    ALU_AND     = 4'h4,
    ALU_OR      = 4'h5,
    ALU_XOR     = 4'h6,
    ALU_SLL     = 4'h7,
    ALU_SRL     = 4'h8,
    ALU_SRA     = 4'h9
} ALU_FUNC;

// MULT funct3 code
// we don't include division or rem options
typedef enum logic [2:0] {
    M_MUL,
    M_MULH,
    M_MULHSU,
    M_MULHU
} MULT_FUNC;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST  inst;
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST inst;
    ADDR PC;
    ADDR NPC; // PC + 4

    DATA rs1_value; // reg A value
    DATA rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    REG_IDX  dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC alu_func;      // ALU function select (ALU_xxx *)
    logic    mult;          // Is inst a multiply instruction?
    logic    rd_mem;        // Does inst read memory?
    logic    wr_mem;        // Does inst write memory?
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
    logic    halt;          // Is this a halt?
    logic    illegal;       // Is this instruction illegal?
    logic    csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic    valid;
} ID_EX_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    DATA alu_result;
    ADDR NPC;

    logic    take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    DATA     rs2_value;
    logic    rd_mem;
    logic    wr_mem;
    REG_IDX  dest_reg_idx;
    logic    halt;
    logic    illegal;
    logic    csr_op;
    logic    rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE mem_size;
    logic    valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    DATA    result;
    ADDR    NPC;
    REG_IDX dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic   take_branch;
    logic   halt;    // not used by wb stage
    logic   illegal; // not used by wb stage
    logic   valid;
} MEM_WB_PACKET;

/**
 * Commit Packet:
 * This is an output of the processor and used in the testbench for counting
 * committed instructions
 *
 * It also acts as a "WB_PACKET", and can be reused in the final project with
 * some slight changes
 */
typedef struct packed {
    ADDR    NPC;
    DATA    data; 
    ARCH_REG_IDX reg_idx;
    logic   halt;
    logic   illegal;
    logic   valid;
} COMMIT_PACKET;

// EDIED HERE

typedef struct packed {
    ADDR            NPC;
    logic           illegal;
    logic           halt;
    PHYS_REG_IDX    T_new; // Use as unique rob id
    PHYS_REG_IDX    T_old;
    ARCH_REG_IDX    arch_reg;
} ROB_PACKET;


typedef struct packed{
    INST           inst;
    logic          valid; // when low, ignore inst. Output will look like a NOP
    logic          taken;
    ADDR           PC;
    ADDR           NPC;
    ALU_OPA_SELECT opa_select;
    ALU_OPB_SELECT opb_select;
    logic          has_dest; // if there is a destination register
    ALU_FUNC       alu_func;
    logic          mult; 
    MULT_FUNC      mult_func;
    BRANCH_FUNC    branch_func;
    logic          rd_mem; 
    logic          wr_mem; 
    logic          cond_branch; 
    logic          uncond_branch;
    logic          csr_op; // used for CSR operations, we only use this as a cheap way to get the return code out
    logic          halt;   // non-zero on a halt
    logic          illegal; // non-zero on an illegal instruction
    FU_TYPE        FU_type;
} DECODE_PACKET;

//TODO: CHANGE FOR RS
typedef struct packed {  
    DECODE_PACKET  decoded_signals;
    
    //Added during dispatch
    PHYS_REG_IDX   T_new; // Use as unique RS id ???
    PHYS_REG_IDX   Source1;
    logic          Source1_ready;
    PHYS_REG_IDX   Source2;
    logic          Source2_ready;
    B_MASK         b_mask;
    B_MASK_MASK    b_mask_mask;
} RS_PACKET;

typedef struct packed {
    ADDR                               recovery_PC;
    logic           [`ROB_SZ_BITS-1:0] rob_tail;
    logic      [`PHYS_REG_SZ_R10K-1:0] free_list;
    PHYS_REG_IDX [`ARCH_REG_SZ_R10K:0] map_table;
    B_MASK                             b_m;
    // lsq_tail
    // branch prediction repair
} BS_ENTRY_PACKET;

typedef struct packed {
    // ADDR            PC;
    ROB_PACKET         [`N-1:0] rob_inputs; // Use as unique rob id
    logic       [$clog2(`ROB_SZ)-1:0] head;
    logic          [`ROB_SZ_BITS-1:0] rob_tail;
    logic      [`NUM_SCALAR_BITS-1:0] rob_spots;
    logic      [`NUM_SCALAR_BITS-1:0] rob_outputs_valid;
    ROB_PACKET          [`N-1:0] rob_outputs;
    logic [`ROB_NUM_ENTRIES_BITS-1:0] rob_num_entries;
} ROB_DEBUG;

typedef struct packed {
    logic [`RS_SZ-1:0] rs_valid;
    logic [`RS_SZ-1:0] rs_reqs;
} RS_DEBUG;

typedef struct packed {
    BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack;
    BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] next_branch_stack;
    B_MASK b_mask_reg;
} BS_DEBUG;

// TODO: UPDATE FU PACKETS

typedef struct packed {
    INST            inst;
    logic           valid;
    ADDR            PC;
    ADDR            NPC; // PC + 4
    ALU_OPA_SELECT  opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT  opb_select; // ALU opb mux select (ALU_OPB_xxx *)
    DATA            source_reg_1;
    DATA            source_reg_2;
    PHYS_REG_IDX    dest_reg_idx;
    ALU_FUNC        alu_func;
} ALU_PACKET;

const ALU_PACKET NOP_ALU_PACKET = '{
    inst:          `NOP,   // Assuming 0 represents a NOP instruction
    valid:         '0,
    PC:            '0,   // No valid program counter
    NPC:           '0,   // No valid next PC
    opa_select:    OPA_IS_RS1, // Assuming ALU_OPA_ZERO means no operation
    opb_select:    OPB_IS_RS2, // Assuming ALU_OPB_ZERO means no operation
    source_reg_1:  '0,   // No valid source register
    source_reg_2:  '0,   // No valid source register
    dest_reg_idx:  '0,   // No valid destination register
    alu_func:       0
};

typedef struct packed {
    logic           valid;
    DATA            source_reg_1;
    DATA            source_reg_2;
    PHYS_REG_IDX    dest_reg_idx;
    B_MASK          bm;
    MULT_FUNC       mult_func;   
} MULT_PACKET;

typedef struct packed {
    logic            valid;
    logic [63:0]     prev_sum;
    logic [63:0]     mplier;
    logic [63:0]     mcand;
    PHYS_REG_IDX     dest_reg_idx;
    B_MASK           bm;
    MULT_FUNC        func;
} INTERNAL_MULT_PACKET;

const MULT_PACKET NOP_MULT_PACKET = '{
    valid:         '0,
    source_reg_1:  '0,   // No valid source register
    source_reg_2:  '0,   // No valid source register
    dest_reg_idx:  '0,   // No valid destination register
    bm:            '0,   // No valid branch mask
    mult_func:      0   
};

typedef struct packed {
    INST            inst;
    logic           valid;
    ADDR            PC;
    ADDR            NPC; // PC + 4
    logic           conditional;
    ALU_OPA_SELECT  opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT  opb_select; // ALU opb mux select (ALU_OPB_xxx *)
    DATA            source_reg_1;
    DATA            source_reg_2;
    PHYS_REG_IDX    dest_reg_idx;       // not used but might be good for identification purposes
    logic           taken;
    BRANCH_FUNC     branch_func;    // comparator used for branch
    B_MASK_MASK     bmm;            // this branch's corresponding mask
} BRANCH_PACKET;

const BRANCH_PACKET NOP_BRANCH_PACKET = '{
    inst:         `NOP,
    valid:        '0,
    PC:           '0,
    NPC:          '0, // PC + 4
    conditional:   0,
    opa_select:    OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
    opb_select:    OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
    source_reg_1: '0,
    source_reg_2: '0,
    dest_reg_idx: '0,       // not used but might be good for identification purposes
    taken:        '0,
    branch_func:  '0,    // comparator used for branch
    bmm:          '0            // this branch's corresponding mask
};

typedef struct packed {
    DATA            source_reg_1;
    DATA            source_reg_2;
    PHYS_REG_IDX    dest_reg_idx;
    B_MASK          bm;
} LDST_PACKET;

typedef struct packed {
    INST            inst;
    ADDR            PC;
    logic           taken;
} FETCH_PACKET;

typedef struct packed {
    PHYS_REG_IDX  completing_reg;
    logic         valid;
} CDB_ETB_PACKET;

typedef struct packed {
    DATA          result;
    PHYS_REG_IDX  completing_reg;
    logic         valid;
} CDB_REG_PACKET;

typedef struct packed {
    ADDR          target_PC;
    B_MASK        bmm;
    logic         bm_mispred;
    logic         taken;
    logic         valid;
} BRANCH_REG_PACKET;

typedef struct packed {
    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] map_table;
    PHYS_REG_IDX [`ARCH_REG_SZ_R10K-1:0] next_map_table;
    FU_TYPE                     [`N-1:0] fu_type;
} DISPATCH_DEBUG;

`endif // __SYS_DEFS_SVH__
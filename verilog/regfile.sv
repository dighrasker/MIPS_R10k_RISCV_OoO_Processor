/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

// P4 TODO: update this with the new parameters from sys_defs
// namely: PHYS_REG_SZ_P6 or PHYS_REG_SZ_R10K

module regfile (
    input         clock, // system clock
    input         reset,
    
    /*---------------- FROM/TO RETIRE ---------------------------*/
    input PHYS_REG_IDX [`N-1:0] retire_phys_regs_reading,
    // input              [`N-1:0] retire_read_en,
    output DATA        [`N-1:0] retire_read_data,

    /*---------------- FROM/TO ISSUE ---------------------------*/
    input PHYS_REG_IDX [`NUM_FU_ALU-1:0] issue_alu_phys_regs_reading_1,
    input PHYS_REG_IDX [`NUM_FU_ALU-1:0] issue_alu_phys_regs_reading_2,
    output DATA        [`NUM_FU_ALU-1:0] issue_alu_read_data_1,
    output DATA        [`NUM_FU_ALU-1:0] issue_alu_read_data_2,

    input PHYS_REG_IDX [`NUM_FU_BRANCH-1:0] issue_branch_phys_regs_reading_1,
    input PHYS_REG_IDX [`NUM_FU_BRANCH-1:0] issue_branch_phys_regs_reading_2,
    output DATA        [`NUM_FU_BRANCH-1:0] issue_branch_read_data_1,
    output DATA        [`NUM_FU_BRANCH-1:0] issue_branch_read_data_2,

    input PHYS_REG_IDX [`NUM_FU_MULT-1:0] issue_mult_phys_regs_reading_1,
    input PHYS_REG_IDX [`NUM_FU_MULT-1:0] issue_mult_phys_regs_reading_2,
    output DATA        [`NUM_FU_MULT-1:0] issue_mult_read_data_1,
    output DATA        [`NUM_FU_MULT-1:0] issue_mult_read_data_2,

    // TODO: ldst
    
    // note: no system reset, register values must be written before they can be read
    input PHYS_REG_IDX [`N-1:0] phys_regs_completing,
    input              [`N-1:0] write_en, //phys regs valid
    input DATA         [`N-1:0] write_data, //cdb results

);

    // Intermediate data before accounting for register 0
    DATA  rdata2, rdata1;
    // Don't read or write when dealing with register 0
    logic re2, re1;
    logic we;

    //actual data structure
    DATA [`PHYS_REG_SZ_R10K-1:0] reg_file;

    // Read for Retire
    for (int i = 0; i < `N; ++i) begin
        assign retire_read_data[i] = reg_file[retire_phys_regs_reading[i]];
    end

    // Read for Issue
    for(int i = 0; i < `NUM_FU_ALU; ++i) begin
        assign issue_alu_read_data_1[i] = reg_file[issue_alu_phys_regs_reading_1[i]];
        assign issue_alu_read_data_2[i] = reg_file[issue_alu_phys_regs_reading_2[i]];
    end

    for(int i = 0; i < `NUM_FU_BRANCH; ++i) begin
        assign issue_branch_read_data_1[i] = reg_file[issue_branch_phys_regs_reading_1[i]];
        assign issue_branch_read_data_2[i] = reg_file[issue_branch_phys_regs_reading_2[i]];
    end

    for(int i = 0; i < `NUM_FU_MULT; ++i) begin
        assign issue_mult_read_data_1[i] = reg_file[issue_mult_phys_regs_reading_1[i]];
        assign issue_mult_read_data_2[i] = reg_file[issue_mult_phys_regs_reading_2[i]];
    end

    always_ff begin
        if(reset) begin
            reg_file <= '0;
        end else begin
            for(int i = 0; i < `N; ++i) begin
                if(write_en[i]) begin
                    reg_file[phys_regs_completing[i]] <= write_data[i];
                end
            end
        end
    end


    // Read port 1
    always_comb begin
        if (read_idx_1 == `ZERO_REG) begin
            read_out_1 = '0;
            re1        = 1'b0;
        end else begin
            read_out_1 = rdata1;
            re1       = 1'b1;
        end
    end

    // Read port 2
    always_comb begin
        if (read_idx_2 == `ZERO_REG) begin
            read_out_2 = '0;
            re2        = 1'b0;
        end else begin
            read_out_2 = rdata2;
            re2       = 1'b1;
        end
    end

    // Write port
    // Can't write to zero register
    assign we = write_en && (write_idx != `ZERO_REG);

endmodule // regfile

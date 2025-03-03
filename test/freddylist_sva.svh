// SystemVerilog Assertions (SVA) for use with our FIFO module
// This file is included by the testbench to separate our main module checking code
// SVA are relatively new to 470, feel free to use them in the final project if you like

`include "verilog/sys_defs.svh"

module FreddyList_sva #(
) (
    input   clock,
    input   reset,
    // ------------- FROM CDB -------------- //
    input  PHYS_REG_IDX           [`N-1:0] phys_reg_completing,    // phys reg indexes that are being completed (T_new)
    input  logic                  [`N-1:0] completing_valid,       // bit vector of N showing which phys_reg_completing is valid
    // ------------- FROM RETIRE -------------- //
    input  PHYS_REG_IDX           [`N-1:0] phys_reg_retiring,      // phy reg indexes that are being retired (T_old)
    input  logic    [`NUM_SCALAR_BITS-1:0] num_retiring_valid,     // number of retiring phys reg (T_old)
    // ------------- FROM BRANCH STACK -------------- //
    input  logic   [`PHYS_REG_SZ_R10K-1:0] free_list_restore,      // snapshot of freelist at mispredicted branch
    input  logic                           restore_flag,           // branch mispredict flag
    // ------------- FROM DISPATCH -------------- //
    input  logic   [`PHYS_REG_SZ_R10K-1:0] updated_free_list,      // freelist from dispatch
    // input  logic    [`NUM_SCALAR_BITS-1:0] num_dispatched,
    // ------------- TO DISPATCH -------------- //
    input  PHYS_REG_IDX           [`N-1:0] phys_regs_to_use,       // physical register indices for dispatch to use
    // output logic    [`NUM_SCALAR_BITS-1:0] free_list_spots,        // how many physical registers are free
    input  logic   [`PHYS_REG_SZ_R10K-1:0] free_list,              // bitvector of the phys reg that are complete
    // ------------- TO ISSUE -------------- //
    input  logic   [`PHYS_REG_SZ_R10K-1:0] complete_list           // bitvector of the phys reg that are complete

);

    logic only_updated;
    logic   [`PHYS_REG_SZ_R10K-1:0] prev_complete_list;

    assign only_updated = ~restore_flag & (num_retiring_valid == 0);


    task exit_on_error;
        begin
            $display("\n\033[31m@@@ Failed at time %4d\033[0m\n", $time);
            $finish;
        end
    endtask
    
    always @(posedge clock) begin

    // Check for only_updated, free_list = updated_free_list
        assert (reset || ~only_updated || (updated_free_list == free_list))
            else begin
                $error("Mismatch on free_list and updated_list: expected %b, got %b", 
                    updated_free_list,     free_list);
                $finish;
            end

    // Check for num_retiring_valid and updated_free_list => free_list
        for (int i = 0; i < num_retiring_valid; i++) begin
            assert (reset || free_list[phys_reg_retiring[i]])
                else begin
                    $error("Free_list didn't free retiring register %d", 
                        phys_reg_retiring[i]);
                    $finish;
                end
        end

        // Check restore
        for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            logic skip_flag = 0;
            for (int j = 0; j < num_retiring_valid; j++) begin
                if (i == phys_reg_retiring[j]) begin
                    skip_flag = 1;
                end
            end
            
            assert (reset || ~restore_flag || free_list[i] == free_list_restore[i] || skip_flag)
                else begin
                    $error("Free_list didn't restore correctly");
                    $finish;
                end 
        end

        // Check completing phys reg
        for (int i = 0; i < `N; i++) begin
            if (completing_valid[i]) begin
                assert (reset || complete_list[phys_reg_completing[i]])
                    else begin
                        $error("Complete_list didn't complete completing register %d", 
                            phys_reg_completing[i]);
                        $finish;
                    end
            end
        end

        // Check non-completing phys reg after updating completing phys reg
        for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            logic skip_flag = 0;
            for (int j = 0; j < `N; j++) begin
                if (completing_valid[j] && phys_reg_completing[j] == i) begin
                    skip_flag = 1;
                end
            end
            if (~prev_complete_list[i]) begin
                assert (reset || ~complete_list[i] || skip_flag)
                    else begin
                        $error("Complete_list didn't properly maintain previous state");
                        $finish;
                    end
            end
        end

        prev_complete_list = complete_list;
        
    end

endmodule


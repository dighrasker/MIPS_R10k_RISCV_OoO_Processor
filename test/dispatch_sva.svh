// SystemVerilog Assertions (SVA) for use with our FIFO module
// This file is included by the testbench to separate our main module checking code
// SVA are relatively new to 470, feel free to use them in the final project if you like

`include "verilog/sys_defs.svh"

module Dispatch_sva #(
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
    input   BS_ENTRY_PACKET [`B_MASK_WIDTH-1:0] branch_stack_entries,
    input   B_MASK                              next_b_mask,

    // ------------ TO/FROM ROB ------------- //
    input   logic            [`ROB_SZ_BITS-1:0] rob_tail,
    input   logic        [`NUM_SCALAR_BITS-1:0] rob_spots,
    input   ROB_ENTRY_PACKET           [`N-1:0] rob_entries,

    // ------------ TO/FROM RS ------------- //
    input   RS_PACKET                  [`N-1:0] rs_entries,
    input   logic        [`NUM_SCALAR_BITS-1:0] rs_spots,

    // ------------ TO/FROM FREDDY LIST ------------- //
    input   logic        [`NUM_SCALAR_BITS-1:0] num_regs_available,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] next_complete_list,
    input   PHYS_REG_IDX               [`N-1:0] regs_to_use,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] free_list_copy,
    input   logic       [`PHYS_REG_SZ_R10K-1:0] updated_free_list,
    
    // ------------ FROM ISSUE? ------------- //
    input   logic       [`NUM_SCALAR_BITS-1:0] num_issuing,

    // ------------ TO ALL DATA STRUCTURES ------------- //
    input   logic       [`NUM_SCALAR_BITS-1:0] num_dispatched
);

    B_MASK_MASK  b_mm_resolve_prev;       
    logic        b_mm_mispred_prev;
    logic [`B_MASK_WIDTH-1:0] b_mask_temp;
    logic [`RS_NUM_ENTRIES_BITS-1:0] rs_spots_c;
    assign rs_spots_c = ($countones(rs_debug.rs_reqs) > `N) ? `N : $countones(rs_debug.rs_reqs);

    always_ff @(posedge clock) begin
        if (reset) begin
            b_mm_resolve_prev <= '0;         
            b_mm_mispred_prev <= 0;
        end else begin
            b_mm_resolve_prev <= b_mm_resolve;
            b_mm_mispred_prev <= b_mm_mispred;
        end
    end
    
    clocking cb @(posedge clock);
        property squashing(i);
            (b_mm_mispred && rs_debug.rs_valid[i] && (RS_data[i].b_mask & b_mm_resolve)) |-> (RS_valid_next[i] == 0);
        endproperty

        property cammingSrc1(i, j);
            (rs_debug.rs_valid[i] && CDB_valid[j] && (CDB_tags[j] == RS_data[i].Source1)) |=> (RS_data[i].Source1_ready);
        endproperty

        property cammingSrc2(i, j);
            (rs_debug.rs_valid[i] && CDB_valid[j] && (CDB_tags[j] == RS_data[i].Source2)) |=> (RS_data[i].Source2_ready);
        endproperty
    endclocking

    always @(posedge clock) begin
        //Check that rs_spots is properly calculated
        assert(reset || rs_spots == rs_spots_c)
            else begin
                $error("RS_spots (%0d) not equal to number of invalid entries (%0d).", 
                rs_spots, rs_spots_c);
                $finish;
            end

        //testing b_mask values after resolving (no mispred)
        //should be checking RS_data[i].b_mask
        for (int i = 0; i < `RS_SZ; ++ i) begin // for each RS entry
            if(rs_debug.rs_valid[i]) begin
                assert(reset || !(RS_data[i].b_mask & b_mm_resolve_prev))
                    else begin
                        $error("RS entry #%0d did not properly set b_mask idx to zero - Current B_mask(%0d) - Prev B_mask_mask(%0d).", 
                        i, RS_data[i].b_mask, b_mm_resolve_prev);
                        $finish;
                    end
            end
        end
        assert(reset || num_dispatched <= rs_spots)
            else begin
                $error("invalid number dispatching(%0d), greater than rs_spots(%0d)",
                num_dispatched, rs_spots);
                $finish;
            end
        assert(reset || num_dispatched <= `N)
            else begin
                $error("invalid number dispatching(%0d), greater than N(%0d)",
                num_dispatched, `N);
                $finish;
            end
    end

    generate
        genvar i;
            for(i = 0; i < `RS_SZ; ++i) begin
                assert property (cb.squashing(i))
                    else begin
                        $error("RS entry #%0d did not properly squash when it should have - Current B_mask(%0d) - b_mm_resolve(%0d).", 
                            i, RS_data[i].b_mask, b_mm_resolve_prev);
                        $finish;
                    end
            end
    endgenerate
    generate
        genvar k, j;
            for(k = 0; k < `RS_SZ; ++k) begin
                for(j = 0; j < `N; ++j) begin
                    assert property (cb.cammingSrc1(k, j))
                        else begin
                            $error("RS entry #%0d did not properly match the cdb to src 1 when it should have - Current cdb idx(%0d) - RS entry src 1(%0d).", 
                            k, CDB_tags[j], RS_data[k].Source1);
                            $finish;
                        end
                    assert property (cb.cammingSrc2(k, j))
                        else begin
                            $error("RS entry #%0d did not properly match the cdb to src 2 when it should have - Current cdb idx(%0d) - RS entry src 2(%0d).", 
                            k, CDB_tags[j], RS_data[k].Source2);
                            $finish;
                        end
                end
            end
    endgenerate

endmodule


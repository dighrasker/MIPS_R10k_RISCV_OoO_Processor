module FreeList #(
    parameter LENGTH = `PHYS_REG_SZ_R10K,
    parameter LENGTH_BITS = `PHYS_REG_ID_BITS
) (
    input  logic                    clock,
    input  logic                    reset,

    // -------- FROM RETIRE --------- //
    input  PHYS_REG_IDX_BIG    [`N-1:0] inputs_retiring;
    
    // ------- TO/FROM DISPATCH -------- //
    input  logic [$clog2(`N+1)-1:0] num_requested;
    output logic [$clog2(`N+1)-1:0] num_available;
    output PHYS_REG_IDX    [`N-1:0] regs_to_use;
);

    //Free List outputs:
    //num available = current avail plus num retiring from R
    //free regs = current free list orred with retiring ones from R?
    //^This requires specific indices to be outputted from Retire
    //We have the option to either send in N reg indices or send in a 32 bit one hot vector
    

    logic [LENGTH-1:0] free, next_free;

    logic [$clog2(`PHYS_REG_SZ_R10K+1)-1:0] curr_avail, next_curr_avail;

    always_comb begin
        next_curr_avail = $countones(valid_frees) + curr_avail - num_requested;
        num_available = ($countones(valid_frees) + curr_avail <= `N) ? $countones(valid_frees) + curr_avail : `N;
        next_free = free;//??
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            free <= '1;
            curr_avail <= '1;
        end else begin
            free <= next_free;
            curr_avail <= next_curr_avail;
        end
    end

endmodule
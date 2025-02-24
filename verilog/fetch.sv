// Simple FIFO with parametrizable depth and width

module Fetch #(
    parameter DEPTH = `ROB_SZ,
    localparam DEPTH_BITS = $clog2(DEPTH),
    localparam NUM_ENTRIES_BITS = $clog2(DEPTH + 1)
) (
    input   logic                        clock, 
    input   logic                        reset,

    // ------------ TO/FROM DISPATCH ------------- //
    input   ROB_ENTRY_PACKET     [`N-1:0] i_buffer_inputs,    // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    input   logic  [`NUM_SCALAR_BITS-1:0] inputs_valid,  // To distinguish invalid instructions being passed in from Dispatch (A number, NOT one hot)
    output  ROB_EXIT_PACKET      [`N-1:0] i_buffer_outputs,   // For retire to check eligibility
    output  logic  [`NUM_SCALAR_BITS-1:0] outputs_valid, // If not all N rob entries are valid entries they should not be considered

    // ------------- TO/FROM RETIRE -------------- //
    input   logic  [`NUM_SCALAR_BITS-1:0] num_retiring,  // Retire module tells the ROB how many entries can be cleared
    output  logic  [`NUM_SCALAR_BITS-1:0] spots,         //number of spots available, saturated at N
    
);

    localparam DEPTH_BITS = $clog2(DEPTH);

    typedef enum {
        READ,
        WRITE
    } op_t;

    op_t op, next_op;
    logic [DEPTH_BITS-1:0] head, next_head;
    logic [DEPTH_BITS-1:0] tail, next_tail;
    logic cur_wr_valid, cur_rd_valid;
    logic empty;

    assign full            = head == tail && op == WRITE;
    assign empty           = head == tail && op == READ;
    assign wr_valid        = !reset && wr_en && (!full || rd_en);
    assign rd_valid        = !reset && rd_en && !empty;
    assign next_head       = (head + rd_valid) % DEPTH;
    assign next_tail       = (tail + wr_valid) % DEPTH;
    assign spots           = full ? 0 : DEPTH - ((tail - head) % DEPTH) > MAX_CNT ? MAX_CNT : DEPTH - ((tail - head) % DEPTH);
    
    // If you're using one-hot head and tail pointers, feel free to use your own
    // 2D flop array instead
    memDP #(
        .WIDTH     (WIDTH),
        .DEPTH     (DEPTH),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    fifo_mem (
        .clock (clock),
        .reset (reset),
        .re (rd_valid),
        .raddr (head),
        .rdata (rd_data),
        .we (wr_valid),
        .waddr (tail),
        .wdata (wr_data)
    );

    always_comb begin
        next_op = op;
        if (wr_valid && !rd_valid) begin
            next_op = WRITE;
        end else if (!wr_valid && rd_valid) begin
            next_op = READ;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            head <= 0;
            tail <= 0;
            op <= READ;
        end else begin
            head <= next_head;
            tail <= next_tail;
            op <= next_op;
        end
    end


endmodule

// Simple FIFO with parametrizable depth and width

module FIFO #(
    parameter DEPTH = 16,
    parameter WIDTH = 32,
    parameter MAX_CNT = 3,
    localparam CNT_BITS = $clog2(MAX_CNT+1)
) (
    input                       clock, 
    input                       reset,
    input                       wr_en,
    input                       rd_en,
    input           [WIDTH-1:0] wr_data,
    output logic                wr_valid,
    output logic                rd_valid,
    output logic    [WIDTH-1:0] rd_data,
    output logic [CNT_BITS-1:0] spots,
    output logic                full
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

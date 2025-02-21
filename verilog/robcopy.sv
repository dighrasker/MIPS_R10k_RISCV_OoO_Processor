
// Simple FIFO with parametrizable depth and width

module FIFO #(
    parameter DEPTH = 16,
    parameter WIDTH = 32,
    parameter MAX_CNT = 3,
    localparam CNT_BITS = $clog2(MAX_CNT+1)
    localparam 
) (
    input                           clock, 
    input                           reset,
    input [`N-1:0] ROB_ENTRY_PACKET rob_entries, // Write data
    output logic                    wr_valid,
    output logic                    rd_valid,
    output logic    [WIDTH-1:0]     rd_data,
    output [`N-1:0] ROB_EXIT_PACKET rob_outputs,
    output logic                    full
);

    typedef enum {
        READ,
        WRITE,
    } op_t;

    logic [$clog2(DEPTH)-1:0] head, next_head; 
    logic [$clog2(DEPTH + 1)-1:0] entries, next_entries; 
    logic [$clog2(DEPTH)-1:0] tail, next_tail;
    logic wr_acc_en, rd_acc_en;

    assign wr_acc_en = wr_en && (entries != DEPTH || rd_en);
    assign rd_acc_en = rd_en && (entries != 0);

    // If you're using one-hot head and tail pointers, feel free to use your own
    // 2D flop array instead
    memDP #(
        .WIDTH     (WIDTH),
        .DEPTH     (DEPTH),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    fifo_mem (
        // LAB 5 TODO: complete the port wiring for this module - DONE
        .clock(clock),
        .reset(reset),
        .re(rd_acc_en),
        .raddr(head),
        .rdata(rd_data),
        .we(wr_acc_en),
        .waddr(tail),
        .wdata(wr_data)

    );

    // LAB5 TODO: Use one of three ways to track if full/empty:
    //  1. (easiest) Keep a count of the number of entries
    //  2. (easy)    Make your memory 1 entry larger so head never equals tail
    //  2. (medium)  Use a valid bit for each entry
    //  3. (hardest) Use head == tail and keep a state of empty vs. full in always_ff
    
    assign full = (entries == DEPTH);

    // LAB5 TODO: Determine a way to calculate spots
    assign spots = ((DEPTH - MAX_CNT) > entries) ? MAX_CNT : (DEPTH - entries);


    always_comb begin
        // LAB5 TODO: Add logic for the next state
        // (also feel free to use assign statements)
        wr_valid = 0;
        rd_valid = 0;
        next_head = head;
        next_tail = tail;
        next_entries = entries;

        if(wr_acc_en)begin
            next_tail = (tail + 1)%DEPTH;
            next_entries = entries + 1;
            wr_valid = 1;
        end
        if(rd_acc_en)begin
            next_head = (head + 1)%DEPTH;
            next_entries = (entries - 1);
            rd_valid = 1;
        end

        if(wr_acc_en && rd_acc_en) begin
            next_entries = entries;
        end

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            // LAB5 TODO: Initialize state variables
            head <= 0;
            tail <= 0;
            entries <= 0;
        end else begin
            // LAB5 TODO: Update on each cycle
            head <= next_head;
            tail <= next_tail;
            entries <= next_entries;
        end
    end

endmodule
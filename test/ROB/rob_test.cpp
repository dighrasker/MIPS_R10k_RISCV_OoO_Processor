#include "queue"
// #include ""

using namespace std;

/*
    INPUT AND OUTPUT FOR ROB
    input   logic                        clock, 
    input   logic                        reset,
    input   ROB_ENTRY_PACKET    [`N-1:0] rob_inputs, // New instructions from Dispatch, MUST BE IN ORDER FROM OLDEST TO NEWEST INSTRUCTIONS
    input   logic  [NUM_SCALAR_BITS-1:0] num_valid, // To distinguish invalid instructions being passed in from Dispatch
    output  ROB_RETIRE_PACKET   [`N-1:0] rob_outputs, // For retire to check eligibility
    output  logic               [`N-1:0] outputs_valid, // If not all N rob entries are valid entries they should not be considered
    input   logic  [NUM_SCALAR_BITS-1:0] num_retiring, // Retire module tells the ROB how many entries can be cleared
    output  logic [NUM_ENTRIES_BITS-1:0] spots;


struct ROB_ENTRY_PACKET {
    int T; // Use as unique rob id
    int T_old;
    int Arch_reg;
};

struct ROB_EXIT_PACKET {
    int T;
    int T_old;
    int Arch_reg; 
};*/



struct ROB_ENTRIES {
    int T;
    int T_old;
    int Arch_reg; 
};


int main(int argc, char* argv) {
    //potenially make a queue of rob_entry structs as opposed to ints?
    
    queue<ROB_ENTRIES> rob;

    /* THIS DOES NOT WORK*/
     // Push different ROB_ENTRIES into the queue
    for (int i = 0; i < 5; ++i) {
        ROB_ENTRIES entry = {i, i * 2, i + 10};  // Assign different values
        rob.push(entry);
        std::cout << "Pushed: T=" << entry.T << ", T_old=" << entry.T_old 
                  << ", Arch_reg=" << entry.Arch_reg << std::endl;
    }

    // Pop and display each entry
    while (!rob.empty()) {
        ROB_ENTRIES entry = rob.front();
        rob.pop();
        std::cout << "Popped: T=" << entry.T << ", T_old=" << entry.T_old 
                  << ", Arch_reg=" << entry.Arch_reg << std::endl;
    }


    return 0;
    
}
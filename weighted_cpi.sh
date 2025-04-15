echo "Finding overall weighted CPI"

#!/bin/bash
# compare_cpi.sh
#
# This script computes a weighted average CPI for all C programs only.
# It expects to find C source files in the "programs/" directory (with a .c extension)
# and corresponding CPI files in the "output/" directory named as [program].cpi.
#
# Each .cpi file should contain a line like:
#   @@@  39072 cycles / 26397 instrs = 1.480168 CPI
# The weighted average CPI is computed as:
#   weighted_cpi = total_cycles / total_instrs

# Initialize totals
total_cycles=0
total_instrs=0

# Loop over each C source file in the programs directory
for source_file in programs/*.c; do
    # Extract the program name without directory or extension
    program=$(basename "$source_file" .c)
    cpi_file="output/${program}.cpi"

    # Check if the corresponding CPI file exists
    if [ ! -f "$cpi_file" ]; then
        echo "CPI file for $program not found. Skipping."
        continue
    fi

    # Extract the line containing cycles (expecting it to include the word "cycles")
    line=$(grep "cycles" "$cpi_file")
    
    # Extract the cycle and instruction counts using awk.
    # The expected format is:
    #   @@@  39072 cycles / 26397 instrs = 1.480168 CPI
    # where:
    #   $2 is cycles, $5 is instructions.
    cycles=$(echo "$line" | awk '{print $2}')
    instrs=$(echo "$line" | awk '{print $5}')

    # Update the running totals
    total_cycles=$(( total_cycles + cycles ))
    total_instrs=$(( total_instrs + instrs ))
done

# Check that total instructions is nonzero to avoid division by zero.
if [ "$total_instrs" -eq 0 ]; then
    echo "Error: Total instructions is zero. Cannot compute weighted CPI."
    exit 1
fi

# Compute the weighted average CPI with floating-point division (6 decimal places)
weighted_cpi=$(echo "scale=6; $total_cycles / $total_instrs" | bc -l)

# Output the totals and the computed weighted CPI.
echo "Total cycles:        $total_cycles"
echo "Total instructions:  $total_instrs"
echo "Weighted Average CPI: $weighted_cpi"


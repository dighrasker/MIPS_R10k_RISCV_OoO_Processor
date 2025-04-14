program="$1"
echo "Comparing ground truth output to new processor for program: $program"
cd ~/eecs470/Final_Project
echo "Running $program"
make $program.out
# &> /dev/null
echo "Comparing writeback output for $program"
wb_diff_output=$(diff output/$program.wb correct_out_o1/$program.wb)
if [ -z "$wb_diff_output" ]; then
    echo "Files are identical"
else
    echo "Files are different"
    # echo "$wb_diff_output"
fi
echo "Comparing memory output for $program"
mem_diff_output=$(diff <(grep "^@@@" output/$program.out) <(grep "^@@@" correct_out_o1/$program.out))
if [ -z "$mem_diff_output" ]; then
    echo "Files are identical"
else
    echo "Files are different"
    # echo "$mem_diff_output"
fi

if [ -z "$wb_diff_output" ] && [ -z "$mem_diff_output" ]; then
    echo -e "\e[32mPassed\e[0m"
else    
    echo -e "\e[31mFailed\e[0m"
fi
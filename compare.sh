echo "Comparing ground truth outputs to new processor"

echo_color() {
        # check if in a terminal and in a compliant shell
        # use tput setaf to set the ANSI Foreground color based on the number 0-7:
        # 0:black, 1:red, 2:green, 3:yellow, 4:blue, 5:magenta, 6:cyan, 7:white
        # other numbers are valid, but not specified in the man page
        if [ -t 0 ]; then tput setaf $1; fi;
        # echo the message in this color
        echo "${@:2:$#}"
        # reset the terminal color
        if [ -t 0 ]; then tput sgr0; fi
}

for source_file in programs/*.c; do
        if [ "$source_file" = "programs/crt.s" ]
        then
                continue
        fi
        passed=1
        program=$(echo "$source_file" | cut -d '.' -f1 | cut -d '/' -f 2)
        echo "Running $program"
        make $program.out -B &> /dev/null

        echo "Comparing writeback output for $program"
        diff output/$program.wb correct_out_o2/$program.wb

        if [ $? = 1 ]
        then
                passed=0
        fi

        echo "Comparing memory output for $program"
        diff <(grep "@@@" output/$program.out) <(grep "@@@" correct_out_o2/$program.out)

        if [ $? = 1 ]
        then
                passed=0
        fi

        if [ $passed = 1 ]
        then
                echo_color 2 Passed
        else
                echo_color 1 Failed
        fi
done
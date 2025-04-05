.section .text
.globl _start

_start:
    li t0, 0       # Counter (t0) initialized to 0
    li t2, 2
    li t3, 2
    li t1, 10      # Loop limit (t1 = 10)

loop:
    addi t0, t0, 1 # Increment counter
    addi t2, t2, 1
    addi t3, t3, 1
    bne t0, t1, loop # Branch if t0 is not equal to t1

end:
    # Exit (for systems that support it)
    li a6, 10      # syscall for exit
    li a7, 10      # syscall for exit
    wfi
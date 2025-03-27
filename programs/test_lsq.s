    li x1, 0xC8
    li x2, 0x0
start:
    sw x2, 0(x1)
    sw x1, 0(x1)
    lw x2, 0(x1)
    lw x1, 0(x1)

    addi x1, x1, -1
    bne  x0, x1, start
    wfi
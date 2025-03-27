    li x1, 0xC8
start:
    addi x2, x0, 0
    addi x3, x2, 0
    addi x4, x3, 0
    addi x5, x4, 0
    addi x6, x5, 0
    addi x7, x6, 0
    addi x8, x7, 0
    addi x9, x8, 0
    addi x10, x9, 0
    addi x11, x10, 0
    addi x12, x11, 0
    addi x13, x12, 0
    addi x14, x13, 0
    addi x15, x14, 0
    addi x16, x15, 0
    addi x1, x1, -1
    bne  x0, x1, start
    wfi
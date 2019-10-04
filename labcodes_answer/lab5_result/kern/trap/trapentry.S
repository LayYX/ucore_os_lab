#include <memlayout.h>

# vectors.S sends all traps here.
.text
# int 0x80 中断处理例程
# 1. 在栈里构建trapframe
# 2. 设置ds为内核的数据段
# 3. 调用trap
.globl __alltraps
__alltraps:
    # push registers to build a trap frame
    # therefore make the stack look like a struct trapframe
    # 将所有的寄存器入栈，构建一个位于栈顶的 trapframe
    pushl %ds
    pushl %es
    pushl %fs
    pushl %gs
    pushal

    # load GD_KDATA into %ds and %es to set up data segments for kernel
    # GD_KDATA 是内存数据段的段选择子
    movl $GD_KDATA, %eax
    # 将段选择子放入对应的寄存器中
    movw %ax, %ds
    movw %ax, %es

    # push %esp to pass a pointer to the trapframe as an argument to trap()
    # 此时寄存器都已经压入到栈中，esp指向了trapframe的起始位置
    # 将 esp 放入栈顶，即将trapframe的地址放到栈顶
    pushl %esp

    # call trap(tf), where tf=%esp
    call trap

    # pop the pushed stack pointer
    popl %esp

    # return falls through to trapret...
.globl __trapret
__trapret:
    # restore registers from stack
    popal

    # restore %ds, %es, %fs and %gs
    popl %gs
    popl %fs
    popl %es
    popl %ds

    # get rid of the trap number and error code
    addl $0x8, %esp
    iret

.globl forkrets
forkrets:
    # set stack to this new process's trapframe
    movl 4(%esp), %esp
    jmp __trapret

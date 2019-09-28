#include <mmu.h>
#include <memlayout.h>

#KERNBASE 0xC0000000
#KMEMSIZE 0x38000000
#KERNTOP (KERNBASE + KMEMSIZE)
#PGSHIFT 12

# 真实地址为 x - 0xC0000000
#define REALLOC(x) (x - KERNBASE)

.text
.globl kern_entry

# lib2 将内核入口迁移到这里
kern_entry:
    # load pa of boot pgdir
    # 计算页表基址
    movl $REALLOC(__boot_pgdir), %eax
    # 设置页表地址到cr3寄存器
    movl %eax, %cr3

    # enable paging
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0


    # update eip
    # now, eip = 0x1.....
    # 这是已经建立好页表映射，将next的虚拟内存地址放置到eax寄存器中
    # 并进行绝对跳转，这时eip指向的就是程序链接时的虚拟地址
    # 而不是高位置零后的物理地址
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    # 绝对地址跳转
    jmp *%eax
next:

    # unmap va 0 ~ 4M, it's temporary mapping
    # 将 __boot_pgdir 页目录的首项置零，移除低位内存的映射
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # set ebp, esp
    # 栈底指针偏移置零
    movl $0x0, %ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
    # now kernel stack is ready , call the first C function
    call kern_init

# should never get here
spin:
    jmp spin
# 定义从能被 PGSIZE 整除的地址开始的数据
.data
.align PGSIZE
    .globl bootstack
bootstack:
    # 8KB的连续地址空间
    .space KSTACKSIZE
    .globl bootstacktop
# 地址是从低向高增长，所以现在是栈顶
bootstacktop:

# kernel builtin pgdir
# an initial page directory (Page Directory Table, PDT)
# These page directory table and page table can be reused!
.section .data.pgdir
# 保存地址以能够被 PGSIZE 整除的地址开始
.align PGSIZE

# 创建临时页目录
__boot_pgdir:
.globl __boot_pgdir
    # 页表第一项指向临时页表 __boot_pt1 的内存地址
    # 这是因为此时程序指针 eip 指向的是低位的物理内存地址
    # 开启页表后如果不为低位建立页表，会导致 eip 找不到对应的指令
    # 所以需要建立临时页表，并在 eip 被设为对应的虚拟地址后移除
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)

    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # pad to PDE of KERNBASE
    # map va KERNBASE + (0 ~ 4M) to pa 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # pad to PGSIZE

.set i, 0

# 创建临时页表
__boot_pt1:
.rept 1024 
    # 创建1024个一级页表项：二级页表偏移量和标志位
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr

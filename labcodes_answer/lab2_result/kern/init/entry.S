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
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:

    # unmap va 0 ~ 4M, it's temporary mapping
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # set ebp, esp
    movl $0x0, %ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
    # now kernel stack is ready , call the first C function
    call kern_init

# should never get here
spin:
    jmp spin

.data
.align PGSIZE
    .globl bootstack
bootstack:
    .space KSTACKSIZE
    .globl bootstacktop
bootstacktop:

# kernel builtin pgdir
# an initial page directory (Page Directory Table, PDT)
# These page directory table and page table can be reused!
.section .data.pgdir
.align PGSIZE

# 创建临时页目录
__boot_pgdir:
.globl __boot_pgdir
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    # 填充4096-
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

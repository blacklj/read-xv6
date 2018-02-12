# The xv6 kernel starts executing in this file. This file is linked with
# the kernel C code, so it can refer to kernel symbols such as main().
# The boot block (bootasm.S and bootmain.c) jumps to entry below.

# Multiboot header, for multiboot boot loaders like GNU Grub.
# http://www.gnu.org/software/grub/manual/multiboot/multiboot.html
#
# Using GRUB 2, you can boot xv6 from a file stored in a
# Linux file system by copying kernel or kernelmemfs to /boot
# and then adding this menu entry:
#
# menuentry "xv6" {
# 	insmod ext2
# 	set root='(hd0,msdos1)'
# 	set kernel='/boot/kernel'
# 	echo "Loading ${kernel}..."
# 	multiboot ${kernel} ${kernel}
# 	boot
# }

#include "asm.h"
#include "memlayout.h"
#include "mmu.h"
#include "param.h"

# Multiboot header.  Data to direct multiboot loader.
.p2align 2
.text
.globl multiboot_header
multiboot_header:
  #define magic 0x1badb002
  #define flags 0
  .long magic
  .long flags
  .long (-magic-flags)

# By convention, the _start symbol specifies the ELF entry point.
# Since we haven't set up virtual memory yet, our entry point is
# the physical address of 'entry'.
.globl _start
_start = V2P_WO(entry)

# Entering xv6 on boot processor, with paging off.
# 开启分页机制之后，来计算一下虚拟地址0x80100000映射的物理地址，如下：
#   0x80100000 = 1000 0000 00|01 0000 0000 0000 0000 0000
#	  0x80100000 高 10 位 = 1000 0000 00 = 512
#	  0x80100000 后 22 位 = 01 0000 0000 0000 0000 0000 = 1048576
#	  索引 512 对应  entrypgdir[ 0x80000000 >> 22 ] 即基地址为 0x0
#	  换算的物理地址 = 0 + 1048576 = 1048576 = 0x100000
#	  即内核代码段所在内存物理地址 0x100000
.globl entry
entry:
  # Turn on page size extension for 4Mbyte pages
  movl    %cr4, %eax
  orl     $(CR4_PSE), %eax
  movl    %eax, %cr4
  # Set page directory
  movl    $(V2P_WO(entrypgdir)), %eax 	  # 页表的虚拟地址在entrypgdir中
  movl    %eax, %cr3          # cr3寄存器中保存着一级页表所在的内存物理地址
  # Turn on paging.
  movl    %cr0, %eax
  orl     $(CR0_PG|CR0_WP), %eax
  movl    %eax, %cr0

 	# 设置内核栈顶位置，并跳转到main执行

  # Set up the stack pointer.
  movl $(stack + KSTACKSIZE), %esp  # 将栈顶指针设置在内核栈的高地址

  # Jump to main(), and switch to executing at
  # high addresses. The indirect call is needed because
  # the assembler produces a PC-relative instruction
  # for a direct jump.
  mov $main, %eax
  jmp *%eax

.comm stack, KSTACKSIZE # 在bss段开辟KSTACKSIZE大小的内核栈

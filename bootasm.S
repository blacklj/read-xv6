#include "asm.h"
#include "memlayout.h"
#include "mmu.h"

# Start the first CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.code16                       # Assemble for 16-bit mode
.globl start
start:
  cli                         # BIOS enabled interrupts; disable

  # Zero data segment registers DS, ES, and SS.
  xorw    %ax,%ax             # Set %ax to zero
  movw    %ax,%ds             # -> Data Segment
  movw    %ax,%es             # -> Extra Segment
  movw    %ax,%ss             # -> Stack Segment

  # Physical address line A20 is tied to zero so that the first PCs 
  # with 2 MB would run software that assumed 1 MB.  Undo that.
  # 通过键盘控制器端口的方法打开A20地址，下面都是针对804x键盘控制器端口进行操作
  # 0x64: 从该端口执行in读取操作，读取8位的状态寄存器，其中第2位表示输入缓冲是否有
  #       数据，这里通过测试键盘控制器是否忙碌来决定是否执行out写操作。发送0xd1代
  #       表向键盘控制器的P2端口写入数据，写入的数据通过0x60端口传入。
  # P2:   8位端口，第2位是A20的开关，通过0x60端口将0xdf写入到P2时，会将A20置位
seta20.1:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.1                # 测试0x64状态寄存器的第2位，如果有数据，则等待

  movb    $0xd1,%al               # 0xd1 -> port 0x64
  outb    %al,$0x64               # 0xd1代表向804x控制器的P2写数据

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2                # 同上

  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60               # 将0xdf(11011111)写入P2，意味着打开A20

  # Switch from real to protected mode.  Use a bootstrap GDT that makes
  # virtual addresses map directly to physical addresses so that the
  # effective memory map doesn't change during the transition.
  lgdt    gdtdesc         # 加载GDT，即将GDT告诉CPU

  # cr0为32位控制寄存器，和保护模式相关
  # |31|------30~1------|0|
  # |PG|--------0-------|PE|
  # PG: 开启分页模式； PE：开启保护模式
  # CR0_PE是在mmu.h文件中定义的32位用于控制cr0
  # CR0_PE：0x00000001
  # 至此，开启了保护模式，但没有开启分页模式
  movl    %cr0, %eax      # 无法直接操作cr0寄存器，先保存cr0寄存器的值，
  orl     $CR0_PE, %eax   # 通过与CR0_PE或运算置1，最好将值保存到cr0寄存器
  movl    %eax, %cr0

//PAGEBREAK!
  # Complete the transition to 32-bit protected mode by using a long jmp
  # to reload %cs and %eip.  The segment descriptors are set up with no
  # translation, so that the mapping is still the identity mapping.
  # 到这里已经进入保护模式，这里的代码跳转基于分段式的跳转：ljmp 段选择子, 段内偏移量
  # 在GDT中代码段下标是1，所以这里的段选择子是：1<<3 = 0000 0000 0000 1000
  # 在16位段选择子中前13位是GDT段表下标，这里是1表示代码段。而我们的代码段是从0开始到
  # 4G结尾的，所以这里偏移量不用做转换，还是原偏移即可。
  ljmp    $(SEG_KCODE<<3), $start32

.code32  # Tell assembler to generate 32-bit code now.
start32:
  # Set up the protected-mode data segment registers
  # 数据段在 GDT 中的下标是 2，所以这里数据段的段选择子是 2 << 3 = 0000 0000 0001 0000
  movw    $(SEG_KDATA<<3), %ax    # Our data segment selector
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %ss                # -> SS: Stack Segment
  movw    $0, %ax                 # Zero segments not ready for use
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS

  # Set up the stack pointer and call into C.
  movl    $start, %esp            # 栈顶被设置为 0x7C00 处
  call    bootmain

  # If bootmain returns (it shouldn't), trigger a Bochs
  # breakpoint if running under Bochs, then loop.
  movw    $0x8a00, %ax            # 0x8a00 -> port 0x8a00
  movw    %ax, %dx
  outw    %ax, %dx
  movw    $0x8ae0, %ax            # 0x8ae0 -> port 0x8a00
  outw    %ax, %dx
spin:
  jmp     spin

# Bootstrap GDT
  # 每个GDT表项为8字节
  # -------------------------------------------------------------------------------------------
  # 31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16 |15|14|13|12|11|10|9 |8|7|6|5|4|3|2|1|0
  # -------------------------------------------------------------------------------------------
  #   base address(31~24)  |G |DB|XX|AA|Limit(16~19)|P | DPL |S |E |ED|RW|A|base address(16~23)
  # -------------------------------------------------------------------------------------------
  #             base address(0~15)                  |               Limit(0~15)
  # -------------------------------------------------------------------------------------------
  # 标记位解释：
  # P:   0 本段不在内存中
  # DPL: 访问该段内存所需权限等级 00~11
  # S:   1 代表数据段、代码段或堆栈段；0 代表系统段，如中断门或调用门
  # E:   1 代表代码段，可执行标记；0 代表数据段
  # ED:  1 代表遵守特权级；0 代表忽略特权级
  # RW:  如果是数据段(E=0)，则 1 代表可写入；0 代表只读
  #      如果是代码段(E=1)，则 1 代表可读取；0 代表不可读取
  # A:   1 代表该段内存访问过； 0 代表没有被访问过
  # G:   1 表示20位段界限的单位是4KB，最大长度为4G
  #      0 表示20位段界限的单位是1字节，最大长度为1M
  # DB:  1 表示地址和操作数是32位，0 表示地址和操作数位16位
  # XX:  保留位，为0
  # AA:  给系统提供的保留位

  # 代码段 GDT 的布局：
  #   0xffff,0x0000,0x00,0x9a,0xcf,0x00
  #
  # |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
  # |-------------------------------------------------------------------------------------|
  # |         0x00          | 1| 1| 0| 0|     f     | 1|0   0| 1| 1  0 1 0|     0x00      |
  # |-------------------------------------------------------------------------------------|
  # |               0x0000                          |          0xffff                     |
  # |-------------------------------------------------------------------------------------|
  #
  # 数据段 GDT 的布局：
  #   0xffff,0x0000,0x00,0x92,0xcf,0x00
  #
  # |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
  # |-------------------------------------------------------------------------------------|
  # |         0x00          | 1| 1| 0| 0|     f     | 1|0   0| 1| 0  0 1 0|     0x00      |
  # |-------------------------------------------------------------------------------------|
  # |               0x0000                          |          0xffff                     |
  # |-------------------------------------------------------------------------------------|

.p2align 2                                # force 4 byte alignment
gdt:
  SEG_NULLASM                             # null seg
  SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)   # code seg
  SEG_ASM(STA_W, 0x0, 0xffffffff)         # data seg

gdtdesc:
  .word   (gdtdesc - gdt - 1)             # sizeof(gdt) - 1
  .long   gdt                             # address gdt

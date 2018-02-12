// Format of an ELF executable file

#define ELF_MAGIC 0x464C457FU  // "\x7FELF" in little endian

// File header
struct elfhdr {
  uint magic;  // must equal ELF_MAGIC 表明该文件是一个elf格式文件
  uchar elf[12];    // 12个字节，每字节含义如下：
                    //   0: 1 = 32位程序； 2 = 64位程序
                    //   1: 数据编码方式， 0 = 无效； 1 = 小端模式； 2 = 大端模式
                    //   2: 版本，固定为 0x1
                    //   3: 目标操作系统架构
                    //   4: 目标操作系统版本
                    //   5~11: 固定为 0
  ushort type;      // 2字节，表明该文件类型，含义如下：
                    //   0x0: 未知目标文件格式
                    //   0x1: 可重定位文件
                    //   0x2: 可执行文件
                    //   0x3: 共享目标文件
                    //   0x4: 转储文件
                    //   0xff00: 特定处理器文件
                    //   0xffff
  ushort machine;
  uint version;
  uint entry;
  uint phoff;
  uint shoff;
  uint flags;
  ushort ehsize;
  ushort phentsize;
  ushort phnum;
  ushort shentsize;
  ushort shnum;
  ushort shstrndx;
};

// Program section header
struct proghdr {
  uint type;
  uint off;
  uint vaddr;
  uint paddr;
  uint filesz;
  uint memsz;
  uint flags;
  uint align;
};

// Values for Proghdr type
#define ELF_PROG_LOAD           1

// Flag bits for Proghdr flags
#define ELF_PROG_FLAG_EXEC      1
#define ELF_PROG_FLAG_WRITE     2
#define ELF_PROG_FLAG_READ      4

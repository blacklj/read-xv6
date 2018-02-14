# Context switch
#
#   void swtch(struct context **old, struct context *new);
#
# Save the current registers on the stack, creating
# a struct context, and save its address in *old.
# Switch stacks to new and pop previously-saved registers.

.globl swtch
swtch:
  # 进程堆栈如下：
  #          +----------------+
  #          | context *new   |
  #  edx --> +----------------+
  #          | context **old  |
  #  eax --> +----------------+
  #          | eip            |
  #  esp --> +----------------+
  movl 4(%esp), %eax
  movl 8(%esp), %edx

  # Save old callee-save registers
  #            +----------------+
  #            | context *new   |
  #  edx -->   +----------------+
  #            | context **old  |
  #  eax -->   +----------------+
  #          / | eip            |
  #          | +----------------+
  #          | | ebp            |
  #          | +----------------+
  #  context | | ebx            |
  #          | +----------------+
  #          | | esi            |
  #          | +----------------+
  #          \ | edi            |
  #  esp -->   +----------------+
  pushl %ebp
  pushl %ebx
  pushl %esi
  pushl %edi

  # Switch stacks
  movl %esp, (%eax)  # *old = old_proc->context = esp
  movl %edx, %esp    # esp = new_proc->context

  # Load new callee-save registers
  popl %edi
  popl %esi
  popl %ebx
  popl %ebp
  ret

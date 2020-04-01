# 这份代码不怎么需要修改，所以只是添加一些自己阅读的注释
# 
LATCH 		= 11930
SCRN_SEL	= 0x18
TSS0_SEL	= 0x20
LDT0_SEL	= 0x28
TSS1_SEL	= 0X30
LDT1_SEL	= 0x38

.global startup_32
.text
startup_32:
    movl $0x10, %eax
    mov %ax, %ds
    lss init_stack, %esp

# 重新初始化IDT和GDT
    call setup_idt
    call setup_gdt
# 初始化完IDT和GDT后从新初始化寄存器，注意这时候寄存器中的值已经要是选择子了
    movl $0x10, %eax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    lss init_stack, %esp
# 设置8253芯片，设置成10ms进行一次时间中断处理
    movb $0x36, %al
    movl $0x43, %edx
    outb %al, %dx
    movl $LATCH, %eax
    movl $0x40, %edx
    outb %al, %dx
    movb %ah, %al
    outb %al, %dx

    movl $0x00080000, %eax
# 设置时间中断（0x08）
    movw $timer_interrupt, %ax
    movw $0x8E00, %dx
    movl $0x08, %ecx
    lea idt(, %ecx, 8), %esi
    movl %eax, (%esi)
    movl %edx, 4(%esi)
# 设置系统调用中断（0x80）
    movw $system_interrupt, %ax
    movw $0xef00, %dx
    movl $0x80, %ecx
    lea idt(, %ecx, 8), %esi
    movl %eax, (%esi)
    movl %edx, 4(%esi)

# 开启时间中断
#	movl $0x21, %edx
#	inb %dx, %al
#	andb $0xfe, %al
#	outb %al, %dx

# 屏蔽掉时间中断（测试时发现，在这里终止时间中断看来比较晚了）
#   movl $0x21, %edx
#   inb %dx, %al
#   or $0x01, %al
#   outb %al, %dx

# 进入到任务0，这是用户态，所以要在堆栈中人工建立中断返回的场景
    pushfl
    andl $0xffffbfff, (%esp)
    popfl
    movl $TSS0_SEL, %eax
    ltr %ax
    movl $LDT0_SEL, %eax
    lldt %ax
    movl $0, current
    sti
    pushl $0x17
    pushl $init_stack
    pushfl
    pushl $0x0f
    pushl $task0
    iret


setup_gdt:
    lgdt lgdt_opcode
    ret

setup_idt:
    lea ignore_int, %edx
    movl $0x00080000, %eax
    movw %dx, %ax
    movw $0x8E00, %dx
    lea idt, %edi
    mov $256, %ecx
rp_sidt:
    movl %eax, (%edi)
    movl %edx, 4(%edi)
    addl $8, %edi
    dec %ecx
    jne rp_sidt
    lidt lidt_opcode
    ret


write_char:
    push %gs
    pushl %ebx
    mov $SCRN_SEL, %ebx
    mov %bx, %gs
    movl scr_loc, %ebx
    shl $1, %ebx
    movb %al, %gs:(%ebx)
    shr $1, %ebx
    incl %ebx
    cmpl $2000, %ebx
    jb 1f
    movl $0, %ebx
1:	movl %ebx, scr_loc
    popl %ebx
    pop %gs
    ret


.align 2
ignore_int:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %ax, %ds
    movl $67, %eax
    call write_char
    popl %eax
    pop %ds
    iret


.align 2
timer_interrupt:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %ax, %ds
    movb $0x20, %al
    outb %al, $0x20
    movl $1, %eax
    cmpl %eax, current
    je 1f
    movl %eax, current
    ljmp $TSS1_SEL, $0
    jmp 2f
1:	movl $0, current
    ljmp $TSS0_SEL, $0
2:	popl %eax
    pop %ds
    iret

# 这里时间中断是直接跳到对应的TSS中。
# （P126）当使用call或jmp指令调度一个任务时，指令中的选择符就可以直接选择任务的TSS，也可以选择存放TSS选择符的任务门
# 当A程序在执行的时候，并中断切换到执行B，这时候A任务的TSS会先被保存，保存时eip就是ljmp这条语句的下一个，所以当下次切换回执行A的时候，会把A的TSS重新加载，这时候就会执行eip指向的语句，也就是ljmp下一条语句了。所以不会出现越执行堆栈越压越多，当然可能只有我这么想


.align 2
system_interrupt:
    push %ds
    pushl %edx
    pushl %ecx
    pushl %ebx
    pushl %eax
    movl $0x10, %edx
    mov %dx, %ds
    call write_char
    popl %eax
    popl %ebx
    popl %ecx
    popl %edx
    pop %ds
    iret

# -----------------------------------------------------------

current:.long 0
scr_loc:.long 0

.align 2
lidt_opcode:
    .word 256*8-1
    .long idt
lgdt_opcode:
    .word (end_gdt-gdt)-1	# so does gdt
    .long gdt

    .align 8
idt:	.fill 256, 8, 0	

gdt:
    .quad 0x0000000000000000
    .quad 0x00c09a00000007ff
    .quad 0x00c09200000007ff
    .quad 0x00c0920b80000002

    .word 0x0068, tss0, 0xe900, 0x0
    .word 0x0040, ldt0, 0xe200, 0x0
    .word 0x0068, tss1, 0xe900, 0x0
    .word 0x0040, ldt1, 0xe200, 0x0
end_gdt:
    .fill 128, 4, 0
init_stack:
    .long init_stack
    .word 0x10


.align 8
ldt0:
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff
    .quad 0x00c0f200000003ff

tss0:	.long 0
    .long krn_stk0, 0x10
    .long 0, 0, 0, 0, 0
    .long 0, 0, 0, 0, 0
    .long 0, 0, 0, 0, 0
    .long 0, 0, 0, 0, 0, 0
    .long LDT0_SEL, 0x8000000

    .fill 128, 4, 0
krn_stk0:
#	.long 0


.align 8
ldt1:
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff
    .quad 0x00c0f200000003ff

tss1:	.long 0
    .long krn_stk1, 0x10
    .long 0, 0, 0, 0, 0
    .long task1, 0x200	
    .long 0, 0, 0, 0	
    .long usr_stk1, 0, 0, 0
    .long 0x17, 0x0f, 0x17, 0x17, 0x17, 0x17
    .long LDT1_SEL, 0x8000000

    .fill 128, 4, 0
krn_stk1:


task0:
    movl $0x17, %eax
    movw %ax, %ds
    movb $65, %al
    int $0x80
    movl $0xfff, %ecx
1:	loop 1b
    jmp task0

task1:
    movl $0x17, %eax
    movw %ax, %ds
    movb $66, %al
    int $0x80
    movl $0xfff, %ecx
1:	loop 1b
    jmp task1

    .fill 128, 4, 0
usr_stk1:

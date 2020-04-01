.code16
.align 4
BOOTSEG=0x07c0
SYSSEG=0x1000
SYSLEN=17
.globl start
.text
start:
    ljmp $BOOTSEG, $go
go:
    mov %cs, %ax
    mov %ax, %ds
    mov %ax, %ss
    mov %ax, %es
    mov $0x0400, %sp
    
# 加载系统模块
load_system:
    mov $SYSSEG,        %ax
    mov %ax,            %es
    mov $0,             %bx
    mov $0x0000,        %dx
    mov $0x0002,        %cx
    mov $0x200+SYSLEN,  %ax
    int $0x13
    jnc ok_load

die:
    jmp die

ok_load:
# 这里移动的是system模块（大概4K）
    cli
    mov $SYSSEG, %ax
    mov %ax, %ds
    xor %ax, %ax
    mov %ax, %es
    mov $0x1000, %cx
    sub %si, %si
    sub %di, %di
    rep
    movsw

    mov $BOOTSEG, %ax
    mov %ax, %ds
# 加载idt和gdt
    lidt idt_48
    lgdt gdt_48
# 切换到保护模式
    mov $0x0001, %ax
    lmsw %ax
# 跳到GDT中的第二个段中，也就是flat code segment 
    ljmp $8, $0
    
gdt:
# 0
    .word 0, 0, 0, 0
    
# flat code segment 
    .word 0x07ff
    .word 0x0000
    .word 0x9a00
    .word 0x00c0
    
# flat data segment
    .word 0x07ff
    .word 0x0000
    .word 0x9200
    .word 0x00c0

idt_48:
    .word 0
    .word 0, 0
    
gdt_48:
    .word 0x7ff
    .word 0x7c00 + gdt, 0

.org 510
    .word 0xaa55
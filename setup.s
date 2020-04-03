# setup.s
.code16
.align 4

BOOTSEG=0x07c0
INITSEG=0x9000

SETUPSEG=0x9020
SETUPLEN=4 

SYSSEG=0x1000
SYSLEN=17

.globl start
.text
start:
	mov $INITSEG, %ax
	mov %ax, %ds
# 获取拓展内存的大小	
	mov $0x88, %ah
	int $0x15
	mov %ax, 2 

# 检测显示方式并取参数
	mov $0x12, %ah
	mov $0x10, %bl
	int $0x10
	mov %ax, 8
	mov %ax, 10
	mov %cx, 12

# 获取光标位置（行列）
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
	mov %dx, 0

# 取显卡当前的显示模式
	mov $0x0f, %ah
	int $0x10
	mov %bx, 4
	mov %ax, 6

# 取第一个硬盘的信息（复制硬盘参数）
#	xor %ax, %ax
#	mov %ax, %ds
#	lds 4

# 取第二个硬盘的信息（复制硬盘参数）


# 准备移动system模块，当然这里并没有读入system模块
	cli
	mov $0x0000, %ax
	cld
do_move:
	mov %ax, %es
	add $0x1000, %ax
	cmp $0x9000, %ax
	jz end_move
	mov %ax, %ds
	xor %di, %di
	xor %si, %si
	mov $0x8000, %cx
	rep
	movsw
	jmp do_move
	
end_move:
	mov $SETUPSEG, %ax
	mov %ax, %ds

# 加载idt和gdt
	lidt idt_48
	lgdt gdt_48

# 开启A20地址线
	call empty_8042
	mov $0xd1, %al
	out %al, $0x64
	call empty_8042
	mov $0xdf, %al
	out %al, $0x60
	call empty_8042
	
# 编程8259
	

# 切换到保护模式
	mov $0x0001, %ax
	lmsw %ax

# 切换到system模块
	ljmp $8, $0
	
# ------------------------------------------------------------------------------


empty_8042:
	.word 0x00eb, 0x00eb
	in $0x64, %al 
	test $2, %al 
	jnz empty_8042
	ret

gdt:
# 0
    .word 0, 0, 0, 0
# kernel code segment 
    .word 0x07ff
    .word 0x0000
    .word 0x9a00
    .word 0x00c0
# kernel data segment
    .word 0x07ff
    .word 0x0000
    .word 0x9200
    .word 0x00c0
idt_48:
    .word 0
    .word 0, 0
gdt_48:
    .word 0x800
    .word 512 + gdt, 0x9

.org 2048
# setup要求占4个扇区，但是我的代码减少了好多，所以这样填充一下可以避免很多麻烦


.code16
.align 4
BOOTSEG=0x07c0
INITSEG=0x9000

SETUPSEG=0x9020
SETUPLEN=4 

SYSSEG=0x1000
SYSSIZE=0x3000
ENDSEG=SYSSEG+SYSSIZE

.globl start
.text
start:

# 将0x7c00处的bootsect读入到内存0x90000处
    mov $BOOTSEG, %ax
    mov %ax, %ds
    mov $INITSEG, %ax
    mov %ax, %es
    mov $256, %cx
    xor %si, %si
    xor %di, %di
    rep
    movsw
# 跳到0x90000处继续执行bootsect
    ljmp $INITSEG, $go

# 这里只做最基础的功能，并不考虑其他的问题（如书中提到的BIOS识别的最大软盘扇区是7）
go:
    mov %cs, %ax
    mov $0xfef4, %dx
    mov %ax, %ds
    mov %ax, %es 
    mov %ax, %ss
    mov %dx, %sp


# 将sectup读入到内存的0x90200
load_setup:
    xor %dx, %dx
    mov $0x0002, %cx
    mov $0x0200, %bx
    mov $0x0200+SETUPLEN, %ax
    int $0x13
    jnc ok_load_setup
# 读取setup失败
    xor %dx, %dx
    int $0x13
    jmp load_setup

ok_load_setup:
#读取每磁道的扇区数，保存在sectors中
    xor %dl, %dl
    mov $0x08, %ah
    int $0x13
    xor %ch, %ch
    mov %cx, sectors
# 恢复es寄存器
    mov $INITSEG, %ax
    mov %ax, %es
# 读取光标位置，保存在dx（dh行号，dl列号）
	mov $0x03, %ah
	xor %bh, %bh
	int $0x10
# 紧接着打印“Loading”字符串	
	mov $9, %cx
	mov $0x0007, %bx
	mov $msg1, %bp
	mov $0x1301, %ax
	int $0x10


# 读取system模块到0x10000处
	mov $SYSSEG, %ax
	mov %ax, %es
	call read_it
	call kill_motor
	
	# mov root_dev, %ax
	# or %ax, %ax
	# jne root_defined
	

# root_defined:
	# seg %cs
	# mov ax, root_dev, 

	ljmp $SETUPSEG, $0



# --------------------------------------------------------------------------------
sread:
	.word 1 + SETUPLEN
head:
	.word 0
track:
	.word 0

read_it:
	mov %es, %ax
	test $0x0fff, %ax
die:
	jne die
	xor %bx, %bx
	
rp_read:
	mov %es, %ax
	cmp $ENDSEG, %ax
	jb ok1_read
	ret
ok1_read:
	mov %cs:sectors, %ax
	sub sread, %ax
	mov %ax, %cx
	shl $9, %cx
	add %bx, %cx
	jnc ok2_read
	je ok2_read

	xor %ax, %ax
	sub %bx, %ax
	shr $9, %ax

ok2_read:
	call read_track
	mov %ax, %cx
	add sread, %ax
	cmp %cs:sectors, %ax
	jne ok3_read
	mov $1, %ax
	sub head, %ax
	jne ok4_read
	incw track
	

ok4_read:
	mov %ax, head
	xor %ax, %ax

ok3_read:
	mov %ax, sread
	shl $9, %cx
	add %cx, %bx
	jnc rp_read
	mov %es, %ax
	add $0x10, %ah
	mov %ax, %es
	xor %bx, %bx
	jmp rp_read
	
read_track:
	pusha
	pusha
	mov $0xe2e, %ax
	mov $7, %bx
	int $0x10
	popa
	mov track, %dx
	mov sread, %cx
	inc %cx
	mov %dl, %ch
	mov head, %dx
	mov %dl, %dh
	and $0x0100, %dx
	mov $2, %ah
	int $0x13
	popa
	ret

kill_motor:
	push %dx
	mov $0x3f2, %dx
	xor %al, %al
	outb %al, %dx
	pop %dx
	ret
	
sectors:
	.word 0
	
msg1:
	.byte 13, 10
	.ascii "Loading"

.org 510
    .word 0xaa55

# 将Linux0.00代码改用现在的64位操作系统下的环境重写了
AS =as
LD =ld
ASFLAGS=--32
LDFLAGS=-m elf_i386 -s -x -Ttext 0
# --32 是指生成的目标文件是32位的
# -m elf_i386 我们系统是64位，编译生成的指令集是x86-64的，但我们这个系统是跑在BOCHS上的，是32位的，所以要指定LD的模拟器指令集为i386
# -s,--strip-all 忽略来自输出文件的所有符号信息
# -x,--discard-al 删除所有本地符号，
# -s和-x是由于我们是要一个可以运行的代码，直接烧成系统，所以那些符号信息都不要
# -M,--print-map 显示链接映射，用于诊断目的
# -Ttext 0 使用指定的地址0作为text段的起始点，​不加这个选项，默认ld会给代码内所有的偏移加上0x08048000。


OBJS=boot.o setup.o head.o
OTHERS=boot setup system system.map system.head
Image=boot.img

all: Image

Image: boot.o setup.o system
	objcopy -O binary boot.o boot
	objcopy -O binary setup.o setup
	objcopy -O binary system system.head
	cat setup >> boot
	cat system.head >> boot
	mv boot $(Image)
	#dd bs=512 if=boot of=$(Image) seek=0
	#dd bs=512 if=/dev/zero of=tmp.img count=2521
	#cat tmp.img >> $(Image)

	#dd bs=512 if=/dev/zero of=tmp.img count=2880
	#dd bs=512 if=boot of=$(Image) count=1
	#cat setup >> $(Image)
	#cat system.head >> $(Image)
	#dd bs=512 if=tmp.img of=$(Image) skip=2 seek=2 count=2778

# dd skip=xxx是备份时对if后面的原文件跳过多少块开始备份
# dd seek=xxx时备份时对of后面的目标文件跳过多少块再开始写

# 原来的Makefile这块是使用（在源文件上稍作修改，以适应变量名）
# + dd bs=32 if=boot of=$(Image) skip=1
# + dd bs=512 if=system of=$(Image) skip=2 seek=1
# 但是在这里不可以这么做了，因为因为编译用的工具不同了，所以生成的文件结构也不相同了

# 这里生成的.o文件是这样的结构 52B + 512B + 736B 前52B是ELF的头，可以通过`readelf -a head.o`查看其中每个字节对应的内容，通过`readelf -a`这条命令我们也可以看到.text这个段是512字节，后面的.rel.text，.data，.bss，.shstrtab，.symtab，.strtab我们也没有写，只要.text这512字节就好了，所以用`objcopy -O binary`将这512字节拷出来。同理对于head.o这个文件也是差不多的道理

setup.o: setup.s
	$(AS) $(ASFLAGS) -o $@ $<

boot.o: boot.s
	$(AS) $(ASFLAGS) -o $@ $<

head.o: head.s
	$(AS) $(ASFLAGS) -o $@ $<

system: head.o
	$(LD) $(LDFLAGS) -e startup_32 -o $@ $<

clean:
	rm -f $(Image) $(OBJS) $(OTHERS)



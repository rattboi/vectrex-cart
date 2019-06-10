# This uses asm6809 from
# http://www.6809.org.uk/asm6809/dl/2.3/
AS = asm6809
VECX = ../vecx/vecx

default: emu

multicart.bin: multicart.asm
	$(AS)  -B -o $@ $^

emu: multicart.bin
	$(VECX) multicart.bin

copy: multicart.bin
	sudo mount /dev/sde1 /mnt
	sudo cp multicart.bin /mnt
	sudo umount /mnt

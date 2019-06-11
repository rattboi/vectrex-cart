# This uses asm6809 from
# http://www.6809.org.uk/asm6809/dl/2.3/
AS = asm6809

default: docker

docker-build: Dockerfile
	docker build . -t asm6809

docker: 
	docker run --rm -v `pwd`:/build -u `id -u ${USER}`:`id -g ${USER}` asm6809 make multicart.bin

multicart.bin: multicart.asm
	$(AS)  -B -o $@ $^

copy: multicart.bin
	sudo mount /dev/sde1 /mnt
	sudo cp multicart.bin /mnt
	sudo umount /mnt

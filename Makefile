.PHONY: all

all: clean SynagogeOS.qcow2 run

run: 
	qemu-system-x86_64 -drive file=SynagogeOS.qcow2,format=qcow2 -boot d -rtc base="2024-10-11"

SynagogeOS.bin:
	nasm -fbin synagogeos.asm -o SynagogeOS.bin

SynagogeOS.qcow2: SynagogeOS.bin
	qemu-img create -f qcow2 SynagogeOS.qcow2 1G	
	qemu-img create -f qcow2 SynagogeOStemp.raw 1G	
	dd if=SynagogeOS.bin of=SynagogeOStemp.raw bs=512 count=200 conv=notrunc
	qemu-img convert -f raw -O qcow2 SynagogeOStemp.raw SynagogeOS.qcow2

clean:
	rm -f *.bin
	rm -f *.raw
	rm -f *.qcow2

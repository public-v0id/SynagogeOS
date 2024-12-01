section .text

readsector:			;Принимает в bx адрес буфера, номер цилиндра в ch, номер сектора в cl, номер диска в dl и номер головки в dh
	push ax
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, 0x01		;Читаем 1 сектор
	int 0x13		;Чтение сектора
	jc .printerr
	pop ax
	ret
.printerr:
	push bx
	mov bx, diskreaderror 
	call print_string
	call newline
	pop bx
	pop ax
	ret

writesector:			;Принимает в bx адрес буфера, номер цилинда в ch, номер сектора в cl, номер диска в dl и номер головки в dh
	push ax
	mov ah, 0x03
	mov al, 0x01
	int 0x13
	jc .printerr
	pop ax
	ret
.printerr:
	push dx
	mov dx, cx
	call print_hex
	pop dx
;	push bx
;	mov bx, diskwriteerror 
;	call print_string
	call newline
;	pop bx
	pop ax
	ret

section .bss
	curdisk resb 2		;Текущий диск

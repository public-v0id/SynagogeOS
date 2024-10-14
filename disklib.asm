readsector:			;Принимает в bx адрес буфера, номер цилиндра в ch, номер сектора в cl
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, 0x01		;Читаем 1 сектор
	mov dh, 0x00		;Сторона диска
	mov dl, 0x80		;Номер устройства (0, 0x81 - 1 и тд)
	int 0x13		;Чтение сектора
	jc .printerr
	ret
.printerr:
	push bx
	mov bx, diskreaderror 
	call print_string
	call newline
	ret

writesector:			;Принимает в bx адрес буфера, номер цилинда в ch, номер сектора в cl
	mov ah, 0x03
	mov al, 0x01
	mov dh, 0x00
	mov dl, 0x80
	int 0x13
	jc .printerr
	ret
.printerr:
	push bx
	mov bx, diskwriteerror 
	call print_string
	call newline
	ret

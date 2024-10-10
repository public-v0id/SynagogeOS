org 0x7c00			;Загрузчик выгружается в ОЗУ по адресу 0x7c00

%DEFINE cursor '>'
%DEFINE bufsize 255
jmp pre_boot

pre_boot:
	cli			;Запрет прерываний
	xor ax, ax
	mov ds, ax
	mov ds, ax
	mov ds, ax		;Зануление регистров
	mov sp, 0x7c00		;Инициализация стека
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, 0x05		;Читаем 7 секторов
	mov ch, 0x00		;Номер цилиндра
	mov cl, 0x02		;Начальный сектор. 1 сектор занимает загрузчик
	mov dh, 0x00		;Сторона диска
	mov dl, 0x80		;Номер устройства (0, 0x81 - 1 и тд)
	mov bx, 0x7e00		;Адрес загрузки данных
	int 0x13		;Чтение сектора
	jc read_err		;Обработка ошибки
	jmp 0x7e00		;Перейти к выполнению кода ОС

read_err:
	mov ah, 0x0e		;Номер функции вывода символа на экран
	mov al, 'R'
	int 0x10
	mov al, 'E'
	int 0x10
	mov al, 'A'
	int 0x10
	mov al, 'D'
	int 0x10
	mov al, ' '
	int 0x10
	mov al, 'E'
	int 0x10
	mov al, 'R'
	int 0x10
	mov al, 'R'
	int 0x10
	mov al, 'O'
	int 0x10
	mov al, 'R'
	int 0x10
	mov al, '!'
	int 0x10
	jmp $			;while(true)

times 510 - ($ - $$) db 0	;Длина текущего кода. Сегмент размером 512 байт, из них 2 байта - указатель на загрузочный сектор
dw 0xaa55			;Указатель на загрузочный сектор

jmp boot

boot:
	call set_videomode
	mov dx, 0x00F9
	call cls_col
	call .print_logo
	mov cx, 0x004C
	mov dx, 0x4B40
	call delay
	call cls
	call day_of_week
	cmp ax, 0
	je .reboot
	jmp inploop
.reboot:
	int 0x19
.print_logo:
	mov bx, logo
	call print_string
	ret
inploop:
	mov dx, cursor
	call print_char
	mov dx, bufsize
	mov bx, buffer
	call read_cmd
	call newline
	cmp ax, 0x0000
	je inperror
.checkcmd:
	xor si, si
.checkloop:
	mov dx, [com+si]
	cmp dx, 0x0
	je .unknowncmd
	call string_equals
	cmp ax, 0x1
	je .getresp
	add si, 2
	jmp .checkloop
.getresp:
	mov bx, resp
	add bx, si
	add bx, si
	jmp dword[bx]
.inperror:
	mov bx, inperror
	call print_string
	call newline
	jmp inploop
.unknowncmd:
	mov bx, unkcmd
	call print_string
	mov bx, buffer
	call print_string
	mov bx, unkcmd2
	call print_string
	jmp inploop
helpfunc:
	mov bx, helpresp
	call print_string
	jmp inploop

	
%INCLUDE "iolib.asm"
%INCLUDE "timelib.asm"
%INCLUDE "mathlib.asm"

logo db 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, "                                       /\                                       ", "                                      /  \                                      ", "                                _____/____\_____                                ", "                                \   /      \   /                                ", "                                 \ /        \ /                                 ", "                                  \          /                                  ", "                                 / \        / \                                 ", "                                /___\ _____/___\                                ", "                                     \    /                                     ", "                                      \  /                                      ", "                                       \/                                       ", "                     SHALOM FROM SYNAGOGE OS BY PUBLIC_V0ID                     ", 0x00
inperror db "INPUT ERROR!", 0x00
shabbat db "SHABBAT SHALOM!", 0x00
notshabbat db "Got to work today...", 0x00
buffer times bufsize+1 db 0x00
hex db "0123456789ABCDEF", 0x00
help db "help", 0x00
helpresp db "You can type:", 0x0A, 0x0D, "help to get help with cmd", 0x0A, 0x0D, 0
com dw help, 0x00
resp dd helpfunc, 0x00
unkcmd db "Sorry! Unknown command ", 0x22, 0
unkcmd2 db 0x22, "!", 0x0A, 0x0D, 0

times 3072 - ($ - $$) db 0

org 0x7c00			;Загрузчик выгружается в ОЗУ по адресу 0x7c00

%DEFINE cursor '>'
%DEFINE bufsize 255
%DEFINE filebufsize 511
%DEFINE startdir 0x000D
jmp pre_boot

pre_boot:
	cli			;Запрет прерываний
	xor ax, ax
	mov ds, ax
	mov ds, ax
	mov ds, ax		;Зануление регистров
	mov sp, 0x7c00		;Инициализация стека
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, 0x09		;Читаем 7 секторов
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
	mov dl, 0x80
	mov ah, 0x08
	int 0x13
	mov bx, filebuf
	mov cx, startdir-1
	call readsector
	mov dx, [bx]
	mov [newfilesec], dx
	mov bx, curdirbuf
	mov cx, startdir
	call readsector
	mov byte[seccount], cl
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
	mov bx, curdirbuf
	call printdir
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
	call command_equals
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
hexprint:
	push bx
	push cx
	push dx	
	xor dx, dx	
	xor cx, cx
.hexprintloop:
	cmp cx, ax
	je .end
	mov dl, byte[bx]
	call print_hex
	inc bx
	inc cx
	jmp .hexprintloop
.end:
	pop dx	
	pop cx
	pop bx
	ret

fhelp:
	mov bx, helpresp
	call print_string
	jmp inploop
freadsec:
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg
	cmp byte[si], 0x00
	je argerror
	mov bx, argbuf
	call hexstrtohex	;номер сектора
	mov cl, al
	mov bx, filebuf		;Адрес загрузки данных
	call readsector
	mov bx, readsuccess
	call print_string
	xor bx, bx
	xor dx, dx
.loop:
	mov dl, byte[filebuf+bx]
;	cmp dx, 0x0000
;	je .next
;	mov ax, dx
;	mov dx, bx
;	call print_hex
;	xor dx, dx
;	mov dx, ':'
;	call print_char
;	mov dx, ax
	call print_hex
;	call newline
.next:
	add bx, 1
	cmp bx, 512
	jne .loop
	call newline
	jmp inploop
fwtext:
	mov dx, 13		;Очистка буферов
	mov bx, argbuf
	call clear_buf
	mov bx, buffer		;Буфер ввода
	mov dx, 1
	mov si, argbuf
	call getarg		;Узнаем название файла
	cmp byte[si], 0x00
	je argerror
	mov dx, 512		
	mov bx, filebuf
	call clear_buf
	mov byte[bx], 0x00	;Текстовый файл
	mov si, argbuf
	mov bx, filebuf
	call setfilename	;В буфер нового файла пишется его название
	mov dx, 499
	mov bx, filebuf
	add bx, 13		;1 байт - флаги, 12 байт - название. Содержимое файла начинается с 13 байта
	call readtext		;Считываем данные с клавиатуры
	cmp ax, 0x0
	je .error
;	mov dx, cx
;	call print_hex
;	call newline
	mov cx, [newfilesec]	;Теперь в секторе newfilesec лежит сектор с файлом
	mov bx, filebuf
;	mov dx, cx
;	call print_hex
;	call newline
	call writesector	
	inc cx
	mov [newfilesec], cx
	jc .error		;Запись файла в сектор диска. Переходим к работе с директорией
.nextdirloop:
	cmp word[curdirbuf+14], 0x1E0
	jle .writetable
	cmp word[curdirbuf+510], 0x0000
	je .newdir
	mov bx, curdirbuf
	mov dx, word[curdirbuf+510]
	mov cx, dx
	mov [curdirsec], dx
;	call print_hex
;	call newline
	call readsector
	jmp .nextdirloop
.writetable:
	mov bx, curdirbuf	
	add bx, [curdirbuf+14]	;Находим место, куда можно поместить новый файл в таблице
	mov si, argbuf		;Записываем название файла
	call setfilename
	add bx, 14
	mov dx, [newfilesec]	;Указатель на расположение файла (newfilesec)
	dec dx
	mov word[bx], dx
	mov dx, [curdirbuf+14]	;Записываем место, куда можно будет поместить новый файл в таблице
	add dx, 0xF
	mov [curdirbuf+14], dx
.writecurdir:
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
	mov bx, curdirbuf
;	push dx
;	mov dx, cx
;	call print_hex
;	call newline
;	pop dx
	call writesector
	mov cx, startdir
	mov bx, curdirbuf
	call readsector			;Возвращаем в буфер директории стартовый адрес и переходим к работе со скрытым файлом
.writesecfile:
	mov bx, filebuf		;Очищаем буфер файла (будем редактировать скрытый файл с системной информацией, сектор B)
	mov dx, 512
	call clear_buf
	mov bx, filebuf		
	mov dx, [newfilesec]
	mov [bx], dx		
	mov cx, startdir-1
	call writesector
	call newline
	jmp inploop
.error:
	mov bx, diskwriteerror
	call print_string
	jmp inploop
.newdir:
	mov dx, word[newfilesec]
	mov word[curdirbuf+510], dx
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
;	push dx
;	mov dx, cx
;	call newline
;	call print_hex
;	call newline
;	pop dx
	mov bx, curdirbuf
	call writesector
	mov word[curdirsec], dx
	inc dx
	mov word[newfilesec], dx
	mov dx, 512		
	mov bx, curdirbuf
	call clear_buf
	mov word[curdirbuf+14], 0x000F
	mov bx, curdirbuf
	add bx, [curdirbuf+14]
	mov si, argbuf		;Записываем название файла
	call setfilename
	add bx, 14
	mov dx, [newfilesec]	;Указатель на расположение файла (newfilesec)
	sub dx, 2
	mov word[bx], dx
	mov dx, [curdirbuf+14]	;Записываем место, куда можно будет поместить новый файл в таблице
	add dx, 0xF
	mov [curdirbuf+14], dx
	jmp .writecurdir
argerror:
	mov bx, argnotfounderror
	call print_string
	jmp inploop
fread:
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg
	cmp byte[si], 0x00
	je argerror
	mov bx, curdirbuf
	add bx, 16
	mov dx, argbuf
	mov cx, 16
.searchloop:			;Поиск файла в каталоге
	push dx
	mov dx, bx
;	call print_hex
	pop dx
	cmp cx, 0x1F0
	jge .nextpage
	cmp byte[bx], 0
	je .notfound
	call string_equals
	cmp ax, 1
	je .end
	add bx, 15
	add cx, 15
	jmp .searchloop
.end:
	mov cx, word[bx+13]
	mov dx, cx
;	call print_hex
	mov bx, filebuf		;Адрес загрузки данных
	call readsector
	cmp byte[bx], 0x00
	jne .dirorex
	add bx, 13
	call print_string
	call newline
	mov bx, curdirbuf
	mov cx, startdir
	call readsector
	jmp inploop
.nextpage:
	mov bx, curdirbuf
	add bx, 510
	cmp word[bx], 0x0000
	je .notfound
	mov cx, word[bx]
;	mov dx, cx
;	call newline
;	call print_hex
;	call newline
	mov bx, curdirbuf
	call readsector
	add bx, 16
	mov dx, argbuf
	mov cx, 16
	jmp .searchloop
.notfound:
	mov bx, filenotfounderror
	call print_string
	mov bx, curdirbuf
	mov cx, startdir
	call readsector
	jmp inploop
.dirorex:
	mov bx, dirorexerror
	call print_string
	call newline
	jmp inploop
fdir:
	mov bx, curdirbuf
	inc bx
	call print_string
	call newline
	add bx, 15
	mov cx, 16
.loop:
	mov dx, cx
	cmp cx, 0x1E1
	jg .nextpage
	cmp byte[bx], 0
	je .end
	mov dx, cx
	call print_string
	call newline
	add bx, 15
	add cx, 15
	jmp .loop
.end:
	mov bx, curdirbuf
	mov cx, startdir
	call readsector
	jmp inploop
.nextpage:
	mov bx, curdirbuf
	add bx, 510
;	mov dx, word[bx]
;	call newline
;	call print_hex
;	call newline
;	call newline
	cmp word[bx], 0x0000
	je .end
	mov cx, word[bx]
	mov dx, cx
	mov bx, curdirbuf
	call readsector
	add bx, 16
	mov dx, argbuf
	mov cx, 16
	jmp .loop

	
%INCLUDE "iolib.asm"
%INCLUDE "timelib.asm"
%INCLUDE "mathlib.asm"
%INCLUDE "disklib.asm"
%INCLUDE "filelib.asm"
logo db 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, "                                       /\                                       ", "                                      /  \                                      ", "                                _____/____\_____                                ", "                                \   /      \   /                                ", "                                 \ /        \ /                                 ", "                                  \          /                                  ", "                                 / \        / \                                 ", "                                /___\ _____/___\                                ", "                                     \    /                                     ", "                                      \  /                                      ", "                                       \/                                       ", "                     SHALOM FROM SYNAGOGE OS BY PUBLIC_V0ID                     ", 0x00
inperror db "INPUT ERROR!", 0x00
shabbat db "SHABBAT SHALOM!", 0x00
notshabbat db "Got to work today...", 0x00
buffer times bufsize+1 db 0x00
argbuf times 13 db 0x00
hex db "0123456789ABCDEF", 0x00
help db "help", 0x00
readsec db "readsec", 0x00
wtext db "wtext", 0x00
read db "read", 0x00
dir db "dir", 0x00
helpresp db "You can type:", 0x0A, 0x0D, "help to get help with cmd", 0x0A, 0x0D, "readsec *sector number [1-FF]* to try reading sector", 0x0A, 0x0D, "wtext *filename* to create a text file and fill it", 0x0A, 0x0D, "read *filename* to read a file", 0x0A, 0x0D, "dir to read current directory", 0x0A, 0x0D, 0
com dw help, readsec, wtext, read, dir, 0x00
resp dd fhelp, freadsec, fwtext, fread, fdir, 0x00
unkcmd db "Sorry! Unknown command ", 0x22, 0
unkcmd2 db 0x22, "!", 0x0A, 0x0D, 0
readsuccess db "READ SUCCESSFUL!", 0x0A, 0x0D, 0
diskreaderror db "ERROR! Couldn't read data from disk", 0x0A, 0x0D, 0
diskwriteerror db "ERROR! Couldn't write data to disk", 0x0A, 0x0D, 0
argnotfounderror db "ERROR! Necessary argument not found!", 0x0A, 0x0D, 0
filenotfounderror db "ERROR! File not found!", 0x0A, 0x0D, 0
dirorexerror db "ERROR! Can't read directory or executable file!", 0x0A, 0x0D, 0
seccount db 0x00
curdirsec dw startdir
newfilesec dw 0x00
curdirbuf times 512 db 0x00
filebuf times 512 db 0x00
times 5632 - ($-$$) db 0
dw startdir+2
times 6144 - ($-$$) db 0
db 0x03, '.'			;каталог .
times 11 db 0x00
db 0x00, 0x0F, 0x00
times 494 db 0x00
dw 0x0000

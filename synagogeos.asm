org 0x7c00			;Загрузчик выгружается в ОЗУ по адресу 0x7c00

%DEFINE cursor '>'
%DEFINE bufsize 255
%DEFINE filebufsize 511
%DEFINE startdir 0x000C
%DEFINE directory 2
%DEFINE exec 1
%DEFINE readable 0
jmp pre_boot

pre_boot:
	cli			;Запрет прерываний
	xor ax, ax
	mov ds, ax
	mov ds, ax
	mov ds, ax		;Зануление регистров
	mov sp, 0x7c00		;Инициализация стека
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, 0xC		;Читаем 7 секторов
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
.wfile:
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
	mov byte[bx], 0b0001	;Текстовый файл
	mov si, argbuf
	mov bx, filebuf
	call setfilename	;В буфер нового файла пишется его название
	mov dx, 495		;В один сектор вмещается 495 символов
	lea bx, [filebuf+15]		;1 байт - флаги, 12 байт - название, 2 байта - указатель на предыдущий сектор файла. Содержимое файла начинается с 13 байта
	call readtext		;Считываем данные с клавиатуры
	call newline
	push ax
;	mov dx, cx
;	call print_hex
;	call newline
.searchfile:
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	je newsec
	mov [newfilesec], cx
oldsec:				;Перезаписываем старый сектор + вся сопутствующая логика
	mov bx, rewriting
	call print_string
	mov [curfilestsec], cx
	mov bx, filebuf
	call writesector	
	inc cx
	mov [newfilesec], cx
	jc dwerror		;Запись файла в сектор диска. Переходим к работе с директорией
	jmp writesecfile
fmkdir:
	mov dx, 13		;Очистка буферов
	mov bx, argbuf
	call clear_buf
	mov bx, buffer		;Буфер ввода
	mov dx, 1
	mov si, argbuf
	call getarg		;Узнаем название директории
	cmp byte[si], 0x00
	je argerror
.searchdir:
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	jne .exists
	mov dx, 512		
	mov bx, filebuf
	call clear_buf
	mov byte[bx], 0b0101	;Каталог
	mov si, argbuf
	mov bx, filebuf
	call setfilename	;В буфер новой директории пишется ее название
	mov byte[bx+14], 0x1E
	mov byte[bx+16], '.'
	mov byte[bx+17], '.'
	mov dx, [curdirstsec]
	mov word[bx+29], dx
	jmp newsec
.exists:
	mov bx, direxistserror
	call print_string
	jmp inploop
newsec:				;Новый файл пишется в новый сектор + вся сопутствующая логика
	mov cx, [newfilesec]	;Теперь в секторе newfilesec лежит сектор с файлом
	call findfreesec
	mov bx, filebuf
	call writesector	
	inc cx
	mov [newfilesec], cx
	jc dwerror		;Запись файла в сектор диска. Переходим к работе с директорией
.newnextdirloop:			;nextdirloop и запись каталога в случае, если файл записан в новый сектор (в конец каталога надо внести новые данные)
	cmp word[curdirbuf+14], 0x1E0
	jle .writetable
	cmp word[curdirbuf+510], 0x0000
	je .newdir
	mov bx, curdirbuf
	mov dx, word[curdirbuf+510]
	mov cx, dx
	mov [curdirsec], dx
	call readsector
	jmp .newnextdirloop
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
	jmp writecurdir
.newdir:
	mov dx, word[newfilesec]
	mov word[curdirbuf+510], dx
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
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
writecurdir:
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
	mov bx, curdirbuf
	call writesector
	mov cx, [curdirstsec]
	mov bx, curdirbuf
	call readsector			;Возвращаем в буфер директории стартовый адрес и переходим к работе со скрытым файлом
writesecfile:
	mov bx, filebuf		;Очищаем буфер файла (будем редактировать скрытый файл с системной информацией, сектор B)
	mov dx, 512
	call clear_buf
	mov bx, filebuf		
	mov dx, [newfilesec]
	mov [bx], dx		
	mov cx, startdir-1
	call writesector
	jmp inploop
dwerror:
	mov bx, diskwriteerror
	call print_string
	jmp inploop
argerror:
	mov bx, argnotfounderror
	call print_string
	jmp inploop
findfileordir:			;Поиск файла в каталоге, принимает в dx указатель на название файла, возвращает в cx указатель на файл (или 0, если файл не найден)
	push ax
	push bx
	push dx
	mov bx, curdirbuf
	add bx, 16
	mov cx, 16
.searchloop:
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
	pop dx
	pop bx
	pop ax
	ret
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
	pop dx
	pop bx
	pop ax
	xor cx, cx
	ret
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
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	je notfounderror
	mov bx, filebuf
	call readsector
	cmp byte[bx], 0b0001
	jne .dirorex
	add bx, 15
	call print_string
	call newline
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	call readsector
	jmp inploop
.dirorex:
	mov bx, dirorexerror
	call print_string
	jmp inploop
frun:
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg
	cmp byte[si], 0x00
	je argerror
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	je notfounderror
	mov bx, filebuf		;Адрес загрузки данных
	call readsector
	cmp byte[bx], 0x3
	jne .dirorrd
	add bx, 13
	add bx, word[bx]
	call bx
;	call bx
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	call readsector
	jmp inploop
.dirorrd:
	mov bx, dirorrderror
	call print_string
	jmp inploop

notfounderror:
	mov bx, filenotfounderror
	call print_string
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	call readsector
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
	mov cx, [curdirstsec]
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
fcd:
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg
	cmp byte[si], 0x00
	je argerror
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	je notfounderror
	mov [curdirstsec], cx
	mov [curdirsec], cx
	mov bx, filebuf
	call readsector
	mov dx, word[bx]
	cmp byte[bx], 0b0101
	jne .rdorex
	mov bx, curdirbuf
	call readsector
	jmp inploop
.rdorex:
	mov bx, rdorexerror
	call print_string
	jmp inploop
findfreesec:			;Принимает номер сектора в cx, возвращает в cx номер ближайшего доступного сектора
	push bx
.loop:
	mov bx, tmpbuf
	call readsector
	jc .error
	test byte[bx], 1
	je .found
	inc cx
	jmp .loop
.found:
	mov [newfilesec], cx
	pop bx
	ret
.error:
	mov bx, nosecerror
	call print_string
	pop bx
	xor cx, cx
	ret 
fbf:
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg
	cmp byte[si], 0x00
	je argerror
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	je notfounderror
	mov bx, filebuf
	call readsector
	call bfinter
	jmp inploop 


%INCLUDE "iolib.asm"
%INCLUDE "timelib.asm"
%INCLUDE "mathlib.asm"
%INCLUDE "disklib.asm"
%INCLUDE "filelib.asm"
%INCLUDE "bflib.asm"

section .bss
	buffer resb bufsize+1
	argbuf resb 13
	curdirbuf resb 512		;Текущий каталог
	filebuf resb 512		;Текущий файл
	tmpbuf resb 512

section .text
logo db 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, "                                       /\                                       ", "                                      /  \                                      ", "                                _____/____\_____                                ", "                                \   /      \   /                                ", "                                 \ /        \ /                                 ", "                                  \          /                                  ", "                                 / \        / \                                 ", "                                /___\ _____/___\                                ", "                                     \    /                                     ", "                                      \  /                                      ", "                                       \/                                       ", "                     SHALOM FROM SYNAGOGE OS BY PUBLIC_V0ID                     ", 0x00
inperror db "INPUT ERROR!", 0x00
shabbat db "SHABBAT SHALOM!", 0x00
notshabbat db "Got to work today...", 0x00
hex db "0123456789ABCDEF", 0x00
help db "help", 0x00
readsec db "readsec", 0x00
wtext db "wtext", 0x00
read db "read", 0x00
dir db "dir", 0x00
run db "run", 0x00
mkdir db "mkdir", 0x00
cd db "cd", 0x00
bf db "bf", 0x00
helpresp db "You can type:", 0x0A, 0x0D, "help to get help with cmd", 0x0A, 0x0D, "readsec *sector number [1-FF]* to try reading sector", 0x0A, 0x0D, "wtext *filename* to create a text file and fill it", 0x0A, 0x0D, "read *filename* to read a file", 0x0A, 0x0D, "dir to read current directory", 0x0A, 0x0D, "run *filename* to run an executable file", 0x0A, 0x0D, "mkdir *dirname* to create a directory", 0x0A, 0x0D, "cd *dirname* to change directory you're in", 0x0A, 0x0D, "bf *filename* to run a brainfuck program", 0x0A, 0x0D, 0
com dw help, readsec, wtext, read, dir, run, mkdir, cd, bf, 0x00
resp dd fhelp, freadsec, fwtext, fread, fdir, frun, fmkdir, fcd, fbf, 0x00
unkcmd db "Sorry! Unknown command ", 0x22, 0
unkcmd2 db 0x22, "!", 0x0A, 0x0D, 0
readsuccess db "READ SUCCESSFUL!", 0x0A, 0x0D, 0
diskreaderror db "ERROR! Couldn't read data from disk", 0x0A, 0x0D, 0
diskwriteerror db "ERROR! Couldn't write data to disk", 0x0A, 0x0D, 0
argnotfounderror db "ERROR! Necessary argument not found!", 0x0A, 0x0D, 0
filenotfounderror db "ERROR! File not found!", 0x0A, 0x0D, 0
direxistserror db "ERROR! Directory already exists!", 0x0A, 0x0D, 0
dirorexerror db "ERROR! Can't read or rewrite directory or executable file!", 0x0A, 0x0D, 0
dirorrderror db "ERROR! Can't execute directory or readable file!", 0x0A, 0x0D, 0
rdorexerror db "ERROR! Can't change directory to a file!", 0x0A, 0x0D, 0
nosecerror db "ERROR! No sectors available!", 0x0A, 0x0D, 0
rewriting db "Rewriting over an existing file!", 0x0A, 0x0D, 0
seccount db 0x00
curdirstsec dw startdir
curdirsec dw startdir
curfilestsec dw 0x0000
newfilesec dw 0x00
times (startdir-2)*512-($-$$) db 0
dw startdir+2
times (startdir-1)*512-($-$$) db 0
db 0b0101, '.'			;каталог .
times 11 db 0x00
db 0x00, 0x1E, 0x00
db 'HELLOWORLD', 0x00, 0x00, 0x00
dw startdir+1
times 479 db 0x00
dw 0x0000
db 0b0011, 'HELLOWORLD', 0x00, 0x00
startpoint dw helloworldstart-$
data db 'Hello, world! From Synagoge OS', 0x0A, 0x0D, 0x00
section .text
helloworldstart:
	push ax
	push bx
	push cx
	mov ah, 0x0E
	mov bx, filebuf
	add bx, 15
;	mov bx, unkcmd						;Придумать, как записать в bx указатель на локальные данные
	xor cx, cx
.loop:
	mov al, byte[bx]
	cmp al, 0
	je .end
	int 0x10
	inc cx
	inc bx
	jmp .loop
.end:
	pop cx
	pop bx
	pop ax
	ret


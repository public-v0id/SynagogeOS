org 0x7c00			;Загрузчик выгружается в ОЗУ по адресу 0x7c00

%DEFINE cursor '>'
%DEFINE bufsize 255
%DEFINE filebufsize 511
%DEFINE startdir 0x000F
%DEFINE directory 2
%DEFINE exec 1
%DEFINE readable 0
jmp pre_boot

pre_boot:			;Код загрузчика ОС
	cli			;Запрет прерываний
	xor ax, ax
	mov ds, ax
	mov ds, ax
	mov ds, ax		;Зануление регистров
	mov sp, 0x7c00		;Инициализация стека
	mov ah, 0x02		;0x02 - работа с жестким диском
	mov al, startdir	;Читаем сектора, на которые записана ОС (их столько число равно номеру сектора со стартовой директорией)
	mov ch, 0x00		;Номер цилиндра
	mov cl, 0x02		;Начальный сектор. 1 сектор занимает загрузчик
	mov dh, 0x00		;Сторона диска
	mov dl, 0x80		;Номер устройства (0, 0x81 - 1 и тд)
	mov bx, 0x7e00		;Адрес загрузки данных
	int 0x13		;Чтение сектора
	jc read_err		;Обработка ошибки
	jmp 0x7e00		;Перейти к выполнению кода ОС

read_err:			;Произошла ошибка считывания секторов при загрузке системы
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

jmp boot			;Переход к коду ОС

boot:				;Функция загрузки операционной системы
	call set_videomode	;Настройка видеовывода
	mov dx, 0x00F9
	call cls_col		;Очистка экрана
	call .print_logo	;Вывод логотипа системы
	mov word[basedir], startdir	
	mov word[meta], startdir-1
	mov word[curdisk], 0x80		;Заполнение указателей на текущую директорию, метаданные и текущий диск
	mov bx, filebuf			
	mov cx, word[meta]
	push dx
	mov dx, [curdisk]
	call readsector			;Сектор с метаданными выписывается в буфер файлов
	pop dx
	mov dx, [bx+2]			
	cmp dx, 10
	jl .noboot			;Если у пользователя меньше 10 шекелей, система не заходит дальше вывода логотипа и требований пароля
	sub dx, 10			;Иначе у пользователя снимают шекели
	mov [bx+2], dx
	push dx
	mov dx, word[curdisk]
	call writesector		;И записывают информацию об этом в метаданные
	pop dx
	mov [curmoney], dx
	mov dx, [bx]
	mov [newfilesec], dx		;Выписываются количество денег у пользователя и указатель на первый незанятый сектор диска
	mov bx, curdirbuf		
	mov cx, word[basedir]
	push dx
	mov dx, word[curdisk]
	call readsector			;Считывается сектор со стартовой директорией диска
	pop dx
	mov byte[seccount], cl
	mov cx, 0x004C
	mov dx, 0x4B40
	call delay			;Включается "таймер", по истечение которого, заставка закончится
	call cls
	call day_of_week		;Высчитывается сегодняшний день недели
	cmp ax, 0			
	je .reboot			;Если это суббота (вышел 0), то система отправляется на перезагрузку
	jmp inploop
.reboot:
	int 0x19
.noboot:
	mov bx, booterror
	call print_string
.nobootloop:
	mov dx, 32
	mov bx, passwordbuf
	call read_cmd
	call newline
	cmp ax, 0x0000
	je inperror
	mov dx, password
	call string_equals
	cmp ax, 0x1
	jne .nobootwrong
	call rightpassword
	jmp boot
.nobootwrong:
	mov bx, passworderror
	call print_string
	jmp .nobootloop
.print_logo:
	mov bx, logo
	call print_string
	ret
inploop:				;Основной цикл системы - цикл ввода-вывода команд 
	mov bx, curdirbuf
	call printdir
	mov dx, cursor
	call print_char			;Выводим название текущей директории и символ курсора
	mov dx, bufsize
	mov bx, buffer
	call read_cmd			;Считываем команду в специальный буфер ввода
	call newline
	cmp ax, 0x0000			;Если команда превысила лимит символов, выводим ошибку
	je inperror
.checkcmd:				;Проверка, правильно ли введена команда
	xor si, si
.checkloop:				;Проход по массиву указателей на команды (соответствующие им строки)
	mov dx, [com+si]
	cmp dx, 0x0
	je .unknowncmd			;Если ничего не нашлось - выводим ошибку
	call command_equals
	cmp ax, 0x1
	je .getresp
	add si, 2
	jmp .checkloop
.getresp:
	mov bx, resp
	add bx, si
	add bx, si
	jmp dword[bx]			;Команда нашлась - переходим по адресу из массива указателей на функции с тем же отступом, что и в массиве указателей на строки
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
hexprint:				;Вывод массива данных в шестнадцатиричном формате
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

fhelp:					;Команда help выводит строку из памяти
	mov dx, 5
	call checkmoney
	mov bx, helpresp
	call print_string
	jmp inploop
freadsec:				;Команда readsec считывает с диска сектор данных и выводит его содержимое в шестнадцатиричном формате
	mov dx, 20
	call checkmoney
	mov bx, argbuf
	mov dx, 13
	call clear_buf
	mov si, argbuf
	mov bx, buffer
	mov dx, 1
	call getarg			;Получение аргумента номер 1 (номер сектора)
	cmp byte[si], 0x00
	je argerror
	mov bx, argbuf
	call hexstrtohex	;Номер сектора
	mov cl, al
	mov bx, filebuf		;Адрес загрузки данных
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	mov bx, readsuccess
	call print_string
	xor bx, bx
	xor dx, dx
.loop:
	mov dl, byte[filebuf+bx]
	call print_hex
.next:
	add bx, 1
	cmp bx, 512
	jne .loop
	call newline
	jmp inploop
fwtext:					;Команда wtext осуществляет запись текстового файла
	mov dx, 30
	call checkmoney
.wfile:
	mov word[curfileprevsec], 0x0000
	mov dx, 13		;Очистка буферов
	mov bx, argbuf
	call clear_buf	
	mov bx, buffer		;Буфер ввода
	mov dx, 1
	mov si, argbuf
	call getarg		;Узнаем название файла
	cmp byte[si], 0x00
	je argerror
	mov dx, argbuf
	call findfileordir
	cmp cx, 0
	jne .fileexists
	mov dx, 512		
	mov bx, filebuf
	call clear_buf
	mov byte[bx], 0b0001	;Текстовый файл
	mov si, argbuf
	mov bx, filebuf
	call setfilename	;В буфер нового файла пишется его название
.readdata:
	mov dx, 494		;В один сектор вмещается 495 символов
	lea bx, [filebuf+15]		;1 байт - флаги, 12 байт - название, 2 байта - указатель на предыдущий сектор файла. Содержимое файла начинается с 13 байта
	call readtext		;Считываем данные с клавиатуры
	push ax
	mov ah, 0x01
	call writedata
	pop ax
	cmp ax, 0
	je .readdata
	call newline
	jmp inploop
.fileexists:
	mov bx, fileexistserror
	call print_string
	jmp inploop
fmkdir:
	mov dx, 20
	call checkmoney
	mov dx, 13		;Очистка буферов
	mov bx, argbuf
	call clear_buf
	mov bx, buffer		;Буфер ввода
	mov dx, 1
	mov si, argbuf
	call getarg		;Узнаем название директории
	cmp byte[si], 0x00
	je argerror
	mov word[curfileprevsec], 0x0000
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
	mov ah, 0x05
	call writedata
	jmp inploop
.exists:
	mov bx, direxistserror
	call print_string
	jmp inploop
writedata:			;Запись данных, определяет, нужно ли выделять новый сектор, записывает файл/директорию, а также метаинформацию
	mov cx, [curfileprevsec]
	mov dx, cx
	cmp cx, 0
	je .newsec		;Этот сектор - первый сектор файла
	mov bx, prevfilebuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
.newsec:				;Новый файл пишется в новый сектор + вся сопутствующая логика
	mov cx, [newfilesec]	;Теперь в секторе newfilesec лежит сектор с файлом
	call findfreesec
	mov bx, filebuf
	mov byte[bx], ah
	push dx
	mov dx, cx
	mov dx, word[curdisk]
	call writesector
	pop dx	
	mov [curfileprevsec], cx
	cmp dx, 0
	je .firstsec
	mov word[prevfilebuf+510], cx
	mov cx, dx
	mov bx, prevfilebuf
	push dx
	mov dx, word[curdisk]
	call writesector
	pop dx
	mov cx, word[curfileprevsec]
	inc cx
	mov [newfilesec], cx
	jmp .writesecfile
.firstsec:
	inc cx
	mov [newfilesec], cx
	jc .dwerror		;Запись файла в сектор диска. Переходим к работе с директорией
.newnextdirloop:			;nextdirloop и запись каталога в случае, если файл записан в новый сектор (в конец каталога надо внести новые данные)
	mov dx, word[curdirbuf+14]
	cmp word[curdirbuf+14], 0x1E0
	jle .writetable
	cmp word[curdirbuf+510], 0x0000
	je .newdir
	mov bx, curdirbuf
	mov dx, word[curdirbuf+510]
	mov cx, dx
	mov [curdirsec], dx
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
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
	jmp .writecurdir
.newdir:
	mov dx, word[newfilesec]
	mov word[curdirbuf+510], dx
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
	mov bx, curdirbuf
	push dx
	mov dx, word[curdisk]
	call writesector
	pop dx
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
.writecurdir:
	mov cx, word[curdirsec]		;Записываем сектор с текущей директорией
	mov bx, curdirbuf
	push dx
	mov dx, cx
	mov dx, word[curdisk]
	call writesector
	pop dx
	mov cx, [curdirstsec]
	mov bx, curdirbuf
	push dx
	mov dx, word[curdisk]
	call readsector			;Возвращаем в буфер директории стартовый адрес и переходим к работе со скрытым файлом
	pop dx
.writesecfile:
	mov bx, filebuf		;Открываем метаданные
	mov dx, word[curdisk]
	mov cx, word[meta]
	call readsector
	mov bx, filebuf		
	mov dx, [newfilesec]
	mov [bx], dx		
	mov cx, word[meta]
	push dx
	mov dx, word[curdisk]
	call writesector
	pop dx
	ret
.dwerror:
	mov bx, diskwriteerror
	call print_string
	ret
argerror:				;Не найден нужный аргумент
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
	mov bx, curdirbuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
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
fread:					;Команда read читает текстовый файл
	mov dx, 25
	call checkmoney
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
	je notfounderror		;Если файл не был найден - выводит ошибку
	mov bx, filebuf
.readandoutloop:
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	cmp byte[bx], 0b0001
	jne .dirorex			;Если первый байт - не 1, то это либо исполняемый файл, либо каталог
	add bx, 15
	call print_string
	mov bx, filebuf
	cmp word[bx+510], 0x0000
	je .end
	mov cx, word[bx+510]		;Если в конце сектора есть указатель на следующий - то переходим к нему
	jmp .readandoutloop
.end:
	call newline
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	jmp inploop
.dirorex:
	mov bx, dirorexerror
	call print_string
	jmp inploop	
frun:					;Команда run запускает исполняемый файл
	mov dx, 40
	call checkmoney
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
	mov bx, filebuf		;Содержимое файла считывается в filebuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	cmp byte[bx], 0x3	;Если в начале файла не тройка - то это либо директория, либо тектовый файл
	jne .dirorrd
	add bx, 13		;После типа файла и его названия лежит указатель на то, через сколько бит начинается секция .text
	add bx, word[bx]
	call bx			;Переходим к исполнению файла
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
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
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	jmp inploop
fdir:				;Команда dir выводит содержимое текущего каталога
	mov dx, 10
	call checkmoney
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
	add bx, 15		;Запись об одном файле в каталоге занимет 15 байт
	add cx, 15
	jmp .loop
.end:
	mov bx, curdirbuf
	mov cx, [curdirstsec]
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	jmp inploop
.nextpage:			;Переход к новому сектору каталога
	mov bx, curdirbuf
	add bx, 510
	cmp word[bx], 0x0000
	je .end
	mov cx, curdirbuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	add bx, 16
	mov dx, argbuf
	mov cx, 16
	jmp .loop
fcd:				;Команда cd меняет текущий каталог на один из тех, что находится в текущем (глубина - 1 уровень)
	mov dx, 10
	call checkmoney
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
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	mov dx, word[bx]
	cmp byte[bx], 0b0101
	jne .rdorex
	mov bx, curdirbuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	jmp inploop
.rdorex:
	mov bx, rdorexerror
	call print_string
	jmp inploop
findfreesec:			;Принимает номер сектора в cx, возвращает в cx номер ближайшего доступного сектора
	push bx
.loop:
	mov bx, tmpbuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
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
fbf:				;Команда bf запускает встроенный интерпретатор языка BrainFuck, исполняет код, записанный в текстовый файл
	mov dx, 50
	call checkmoney
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
	call bfclr
.iterloop:
	mov bx, filebuf
	push dx
	mov dx, word[curdisk]
	call readsector
	pop dx
	call bfinter
	mov cx, word[bx+510]
	cmp cx, 0x0000
	jne .iterloop
	jmp inploop 
checkmoney:				;Принимает в dx стоимость операции
	push ax
	push bx
	push cx
	push dx
	mov ax, dx
	mov bx, filebuf
	mov cx, startdir-1
	mov dx, 0x80
	call readsector
	mov dx, [bx+2]
	cmp dx, ax
	jl .error
	sub dx, ax
	mov [curmoney], dx
	mov word[bx+2], dx
	mov dx, 0x80
	call writesector
	pop dx
	pop cx
	pop bx
	pop ax
	ret
.error:
	mov bx, nomoneyerror
	call print_string
	jmp .passwordloop
.passwordloop:
	mov dx, 32
	mov bx, passwordbuf
	call read_cmd
	call newline
	cmp ax, 0x0000
	je inperror
	mov dx, password
	call string_equals
	cmp ax, 0x1
	jne .wrongpassword
	pop dx
	pop cx
	pop bx
	pop ax
	call rightpassword
	ret
.wrongpassword:
	mov bx, passworderror
	call print_string
	jmp .passwordloop
rightpassword:				;Начисление денег в случае правильного пароля
	push bx
	push cx
	push dx
	mov dx, word[curmoney]
	add dx, 100
	mov word[curmoney], dx
	mov bx, filebuf
	mov cx, startdir-1
	push dx
	mov dx, 0x80
	call readsector
	pop dx
	mov [bx+2], dx
	push dx
	mov dx, word[curdisk]
	call writesector 
	pop dx
	pop dx
	pop cx
	pop bx
	ret
printbuf:				;Вспомогательная функция вывода буффера
	push si
	push dx
	xor si, si
	xor dx, dx
.loop:
	mov dl, byte[bx+si]
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
	add si, 1
	cmp si, 512
	jne .loop
	pop dx
	pop si
	ret
fchdsk:					;Функция chdsk меняет текущий диск на указанный в качестве аргумента
	mov dx, 30
	call checkmoney
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
	mov word[curdisk], ax
	cmp ax, 0x80
	je .maindsk
	mov word[basedir], 0x2
	mov word[meta], 0x1
	mov word[curdirsec], 0x2
	mov word[curdirstsec], 0x2
	jmp .loadstartdir
.maindsk:				;0x80 - основной жесткий диск
	mov word[basedir], startdir
	mov word[meta], startdir-1
	mov word[curdirsec], startdir
	mov word[curdirstsec], startdir
.loadstartdir:
	mov dx, word[curdisk]
	mov bx, curdirbuf
	mov cx, word[meta]
	call readsector
	push dx
	mov dl, byte[bx]
	mov [newfilesec], dl
	pop dx
	mov cx, word[basedir]
	call readsector
	jmp inploop
fformat:				;Функция format форматирует диск под работу с SynagogeOS
	mov dx, 30
	call checkmoney
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
	mov dx, 512
	mov bx, filebuf
	call clear_buf
	mov dx, ax
	mov cx, 1
	mov word[bx], 0x0002
	call writesector
	inc cx
	mov byte[bx], 0x5
	mov byte[bx+1], 'A'
	mov byte[bx+2], ':'
	mov byte[bx+14], 0x0F
	call writesector
	push dx
	mov dx, 512
	call clear_buf
	pop dx
.deleteloop:
	inc cx
	cmp cl, 0x12
	jg .nextcyl
	cmp cx, 2880
	jg .end
	call writesector
	jmp .deleteloop
.end:
	jmp inploop
.nextcyl:
	mov cl, 0x00
	inc ch
	jmp .deleteloop

%INCLUDE "iolib.asm"
%INCLUDE "timelib.asm"
%INCLUDE "mathlib.asm"
%INCLUDE "disklib.asm"
%INCLUDE "filelib.asm"
%INCLUDE "bflib.asm"

section .bss
	passwordbuf resb 32
	buffer resb bufsize+1
	argbuf resb 13
	curdirbuf resb 512		;Текущий каталог
	filebuf resb 512		;Текущий файл
	prevfilebuf resb 512
	tmpbuf resb 512
	curmoney resb 2
	seccount resb 1
	curfileprevsec resb 2		;Начальный сектор текущего файла
	curfilecursec resb 2		;Текущий сектор текущего файла
	newfilesec resb 2		;Сектор, куда пишутся данные
	basedir resb 2			;Номер сектора, где начинается базовая директория
	meta resb 2			;Номер сектора, где лежат метаданные диска

section .text
password db "golovadaideneg", 0
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
chdsk db "chdsk", 0x00
format db "format", 0x00
helpresp db "You can type:", 0x0A, 0x0D, "help to get help with cmd", 0x0A, 0x0D, "readsec *sector number [1-FF]* to try reading sector", 0x0A, 0x0D, "wtext *filename* to create a text file and fill it", 0x0A, 0x0D, "read *filename* to read a file", 0x0A, 0x0D, "dir to read current directory", 0x0A, 0x0D, "run *filename* to run an executable file", 0x0A, 0x0D, "mkdir *dirname* to create a directory", 0x0A, 0x0D, "cd *dirname* to change directory you're in", 0x0A, 0x0D, "bf *filename* to run a brainfuck program", 0x0A, 0x0D, "chdsk *disk hexagonal number* to change disk", 0x0A, 0x0D, "format *disk hexagonal number* to format disk", 0x0A, 0x0D, 0
com dw help, readsec, wtext, read, dir, run, mkdir, cd, bf, chdsk, format, 0x00
resp dd fhelp, freadsec, fwtext, fread, fdir, frun, fmkdir, fcd, fbf, fchdsk, fformat, 0x00
unkcmd db "Sorry! Unknown command ", 0x22, 0
unkcmd2 db 0x22, "!", 0x0A, 0x0D, 0
readsuccess db "READ SUCCESSFUL!", 0x0A, 0x0D, 0
diskreaderror db "ERROR! Couldn't read data from disk", 0x0A, 0x0D, 0
diskwriteerror db "ERROR! Couldn't write data to disk", 0x0A, 0x0D, 0
argnotfounderror db "ERROR! Necessary argument not found!", 0x0A, 0x0D, 0
filenotfounderror db "ERROR! File not found!", 0x0A, 0x0D, 0
fileexistserror db "ERROR! File already exists!", 0x0A, 0x0D, 0
direxistserror db "ERROR! Directory already exists!", 0x0A, 0x0D, 0
dirorexerror db "ERROR! Can't read or rewrite directory or executable file!", 0x0A, 0x0D, 0
dirorrderror db "ERROR! Can't execute directory or readable file!", 0x0A, 0x0D, 0
rdorexerror db "ERROR! Can't change directory to a file!", 0x0A, 0x0D, 0
nosecerror db "ERROR! No sectors available!", 0x0A, 0x0D, 0
booterror db "ERROR! Couldn't boot! Maybe you're out of money! Try typing a password to get some!", 0x0A, 0x0D, 0
nomoneyerror db "ERROR! Can't run command! Maybe you're out of money! Try typing a password to get some (or type 'no' to skip password entering)", 0x0A, 0x0D, 0
passworderror db "Invalid password!", 0x0A, 0x0D, 0
rewriting db "Rewriting over an existing file!", 0x0A, 0x0D, 0
curdirstsec dw startdir
curdirsec dw startdir
times (startdir-2)*512-($-$$) db 0
dw startdir+2
dw 0x100
times (startdir-1)*512-($-$$) db 0
db 0b0101, "C:"			;Стартовый каталог диска C
times 11 db 0x00
db 0x1E, 0x00
db 'HELLOWORLD', 0x00, 0x00, 0x00
dw startdir+1
times 479 db 0x00
dw 0x0000
db 0b0011, 'HELLOWORLD', 0x00, 0x00
startpoint dw helloworldstart-$
data db 'Hello, world! From Synagoge OS', 0x0A, 0x0D, 0x00
helloworldstart:
	push ax
	push bx
	push cx
	mov ah, 0x0E
	mov bx, filebuf
	add bx, 15
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


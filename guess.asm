
SYS_EXIT  equ 1
SYS_READ  equ 3
SYS_WRITE equ 4
STDIN     equ 0
STDOUT    equ 1

section .text	
	global _start
_start:



	; Get random number for easy level

call __prompt_1 ;ask the user to choice a level of difficulty
call __userInput
call __checkInput ;check the input of the user
call _generate_random ; random number must be fetched before entering a level
																			;EASY LEVEL
 ;checks if the number of tries has reached limited
_modup:
	add eax, maxrand
	jmp __easy_level

_moddown:
	sub eax, maxrand

__easy_level:

	cmp eax, maxrand
	jg _moddown
	cmp eax, 1 ; Is it lower than 1?
	jl _modup

	mov [randint], eax

	;call __write
	;mov ebx, 1
	;mov ecx, randint
	;mov edx, 4
	;call __syscall

	; Write hello message
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, hello
	mov edx, hello_len
	call __syscall

_loop:

	; Write prompt input guess

	mov eax, [tries]
	mov ebx, 1 ; Optimization warning: May change. Do not use if tries > 9. Use standard __itoa instead.
	mov ecx, 10 ; Optimized
	call __itoa_knowndigits
	
	mov ecx, eax
	mov edx, ebx
	
	call __write
	mov ebx, 1 ; Stdout
	call __syscall
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, prompt
	mov edx, prompt_len
	call __syscall
	
	; Read input

	call __read
	mov ebx, 0 ; Stdin
	mov ecx, inputbuf
	mov edx, inputbuf_len
	call __syscall

	; Convert into integer

	mov ecx, eax
	sub ecx, 1 ; Get rid of extra newline
	
	cmp ecx, 1 ; Is the length of the number less than 1? (invalid)
	jl _reenter

	mov ebx, ecx

	mov eax, 0 ; Initalize eax
	jmp _loopconvert_nomul
;;;;
_loopconvert:

	imul eax, 10 ; Multiply by 10
	
_loopconvert_nomul:

	mov edx, ebx
	sub edx, ecx
	
	push eax
	
	mov ah, [inputbuf+edx]
	
	sub ah, 48 ; ASCII digits offset
	
	cmp ah, 0 ; Less than 0?
	jl _again
	cmp ah, 9 ; More than 9?
	jg _again

	movzx edx, ah
	
	pop eax
	add eax, edx

	loop _loopconvert
	
	jmp _convertok

_reenter:

	; Write message

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, reenter
	mov edx, reenter_len
	call __syscall

	; Repeat enter

	jmp _loop
	
_toohigh:

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toohigh
	mov edx, toohigh_len
	call __syscall

	jmp _again

_toolow:
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toolow
	mov edx, toolow_len
	call __syscall

_again:

	cmp dword [tries], 1 ; Is this the last try?
	jle _lose

	sub dword [tries], 1 ; Minus one try.
	
	jmp _loop

_lose:

	; You lose

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose
	mov edx, youlose_len
	call __syscall

	mov eax, [randint]
	call __itoa

	mov ecx, eax
	mov edx, ebx
	call __write
	mov ebx, 1 ; Stdout
	call __syscall

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose2
	mov edx, youlose2_len
	call __syscall

	mov ebx, 2 ; Exit code for OK, lose.

	jmp _exit

_convertok:

	; Compare input

	cmp eax, [randint]
	jg _toohigh
	jl _toolow

	; You win

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youwin
	mov edx, youwin_len
	call __syscall

	mov ebx, 1 ; Exit code for OK, win.

_exit:

	push ebx

	; Print normal goodbye

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, goodbye
	mov edx, goodbye_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Report OK.

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, _ok
	mov edx, _ok_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Exit

	call __exit
	pop ebx
	call __syscall
	
; Procedures

__itoa_init:

	; push eax
	; push ebx
	; We do not have to preserve as it will contain
	; A return value

	pop dword [_itoabuf]

	push ecx
	push edx

	push dword [_itoabuf]
	
	ret

__itoa: ; Accept eax (i), return eax (a), ebx (l)

	call __itoa_init

	mov ecx, 10 ; Start with 10 (first 2-digit)
	mov ebx, 1 ; If less than 10, it has 1 digit.

__itoa_loop:

	cmp eax, ecx
	jl __itoa_loopend

	imul ecx, 10 ; Then go to 100, 1000...
	add ebx, 1 ; Then go to 2, 3...
	jmp __itoa_loop

__itoa_knowndigits: ; Accept eax (i), ebx (d), ecx (m), return eax (a), ebx (l)

	call __itoa_init

__itoa_loopend:

	; Prepare for loop
	; edx now contains m
	; ecx is now ready to count.
	; eax already has i
	; ebx already has d.

	mov edx, ecx
	mov ecx, ebx
	
	push ebx

__itoa_loop2:

	push eax

	; Divide m by 10 into m

	mov eax, edx
	mov edx, 0 ; Exponent is 0
	mov ebx, 10 ; Divide by 10

	idiv ebx
	mov ebx, eax ; New m
	
	; Divide number by new m into (1)

	mov eax, [esp] ; Number
	mov edx, 0 ; Exponent is 0
	idiv ebx ; (1)

	; Store into buffer

	mov edx, [esp+4] ; Each dword has 4 bytes
	sub edx, ecx
	
	add eax, 48 ; Offset (1) as ASCII number
	
	mov [_itoabuf+edx], eax

	sub eax, 48 ; Un-offset (1) to prepare for next step

	; Multiply (1) by m into (1)

	imul eax, ebx

	; Subtract number by (1) into number
	
	mov edx, ebx ; Restore new-m back to edx as m
	
	pop ebx ; Number
	sub ebx, eax ; New number
	mov eax, ebx	

	loop __itoa_loop2

	; Return buffer array address and
	; Pop preserved ebx as length

	mov eax, _itoabuf
	pop ebx

	; Pop preserved registers and restore

	pop edx
	pop ecx	

	ret
;;;;
													; MEDIUM LEVEL





;checks if the number of tries has reached limited
_modup_2:
	add eax, maxrand2
	jmp __medium_level

_moddown_2:
	sub eax, maxrand2

__medium_level:
	;generate random number for medium level
	call _generate_random
	cmp eax, maxrand2
	jg _moddown_2
	cmp eax, 1 ; Is it lower than 1?
	jl _modup_2

	mov [randint], eax

	;call __write
	;mov ebx, 1
	;mov ecx, randint
	;mov edx, 4
	;call __syscall

	; Write hello message
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, hello_2
	mov edx, hello_len_2
	call __syscall

;create diff loop
;diff _again


_loop_2:

	; Write prompt input guess

	mov eax, [tries2]
	mov ebx, 1 ; Optimization warning: May change. Do not use if tries > 9. Use standard __itoa instead.
	mov ecx, 10 ; Optimized
	call __itoa_knowndigits_2
	
	mov ecx, eax
	mov edx, ebx
	
	call __write
	mov ebx, 1 ; Stdout
	call __syscall
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, prompt_2
	mov edx, prompt_len_2
	call __syscall
	
	; Read input

	call __read
	mov ebx, 0 ; Stdin
	mov ecx, inputbuf_2
	mov edx, inputbuf_len_2
	call __syscall

	; Convert into integer

	mov ecx, eax
	sub ecx, 1 ; Get rid of extra newline
	
	cmp ecx, 1 ; Is the length of the number less than 1? (invalid)
	jl _reenter

	mov ebx, ecx

	mov eax, 0 ; Initalize eax
	jmp _loopconvert_nomul_2
;;;;

;-----

_loopconvert_2:

	imul eax, 10 ; Multiply by 10
	
_loopconvert_nomul_2:

	mov edx, ebx
	sub edx, ecx
	
	push eax
	
	mov ah, [inputbuf_2+edx]
	
	sub ah, 48 ; ASCII digits offset
	
	cmp ah, 0 ; Less than 0?
	jl _again_2
	cmp ah, 9 ; More than 9?
	jg _again_2

	movzx edx, ah
	
	pop eax
	add eax, edx

	loop _loopconvert_2
	
	jmp _convertok_2

;possible change
_reenter_2:

	; Write message

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, reenter
	mov edx, reenter_len
	call __syscall

	; Repeat enter

	jmp _loop_2
	
_toohigh_2:

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toohigh
	mov edx, toohigh_len
	call __syscall

	jmp _again_2

_toolow_2:
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toolow
	mov edx, toolow_len
	call __syscall

_again_2:

	cmp dword [tries2], 1 ; Is this the last try?
	jle _lose_2

	sub dword [tries2], 1 ; Minus one try.
	
	jmp _loop_2

_lose_2:

	; You lose

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose
	mov edx, youlose_len
	call __syscall

	mov eax, [randint]
	call __itoa_2

	mov ecx, eax
	mov edx, ebx
	call __write
	mov ebx, 1 ; Stdout
	call __syscall

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose2
	mov edx, youlose2_len
	call __syscall

	mov ebx, 2 ; Exit code for OK, lose.

	jmp _exit

_convertok_2:

	; Compare input

	cmp eax, [randint]
	jg _toohigh_2
	jl _toolow_2

	; You win

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youwin
	mov edx, youwin_len
	call __syscall

	mov ebx, 1 ; Exit code for OK, win.
;

_exit_2:

	push ebx

	; Print normal goodbye

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, goodbye
	mov edx, goodbye_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Report OK.

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, _ok
	mov edx, _ok_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Exit

	call __exit
	pop ebx
	call __syscall
	
	
; Procedures

__itoa_init_2:

	; push eax
	; push ebx
	; We do not have to preserve as it will contain
	; A return value

	pop dword [_itoabuf_2]

	push ecx
	push edx

	push dword [_itoabuf_2]
	
	ret

__itoa_2: ; Accept eax (i), return eax (a), ebx (l)

	call __itoa_init_2

	mov ecx, 10 ; Start with 10 (first 2-digit) 'if altered answer is seen as 0 but 10'
	mov ebx, 1 ; If less than 10, it has 1 digit.

__itoa_loop_2:

	cmp eax, ecx
	jl __itoa_loopend_2

	imul ecx, 10 ; Then go to 100, 1000... 'if set to 100 answer is 10 but seen as 00'
	add ebx, 1 ; Then go to 2, 3... 'if set to 10 the answer becomes 00000... but meaning 10'
	jmp __itoa_loop_2

__itoa_knowndigits_2: ; Accept eax (i), ebx (d), ecx (m), return eax (a), ebx (l)

	call __itoa_init_2

__itoa_loopend_2:

	; Prepare for loop
	; edx now contains m
	; ecx is now ready to count.
	; eax already has i
	; ebx already has d.

	mov edx, ecx
	mov ecx, ebx
	
	push ebx

__itoa_loop2_2:

	push eax

	; Divide m by 10 into m

	mov eax, edx
	mov edx, 0 ; Exponent is 0
	mov ebx, 10 ; Divide by 10 ;if div the answer will be 00 but meaning 10

	idiv ebx
	mov ebx, eax ; New m
	
	; Divide number by new m into (1)

	mov eax, [esp] ; Number
	mov edx, 0 ; Exponent is 0
	idiv ebx ; (1)

	; Store into buffer

	mov edx, [esp+4] ; Each dword has 4 bytes
	sub edx, ecx
	
	add eax, 48 ; Offset (1) as ASCII number
	
	mov [_itoabuf_2+edx], eax

	sub eax, 48 ; Un-offset (1) to prepare for next step

	; Multiply (1) by m into (1)

	imul eax, ebx

	; Subtract number by (1) into number
	
	mov edx, ebx ; Restore new-m back to edx as m
	
	pop ebx ; Number
	sub ebx, eax ; New number
	mov eax, ebx	

	loop __itoa_loop2_2

	; Return buffer array address and
	; Pop preserved ebx as length

	mov eax, _itoabuf_2
	pop ebx

	; Pop preserved registers and restore

	pop edx
	pop ecx	

	ret
;;;;
;END OF LEVEL 2

																			;;HARD LEVEL

;checks if the number of tries has reached limited
_modup_3:
	add eax, maxrand3
	jmp __hard_level

_moddown_3:
	sub eax, maxrand3

__hard_level:
	;generate random number for medium level
	call _generate_random
	cmp eax, maxrand3
	jg _moddown_3
	cmp eax, 1 ; Is it lower than 1?
	jl _modup_3

	mov [randint], eax

	;call __write
	;mov ebx, 1
	;mov ecx, randint
	;mov edx, 4
	;call __syscall

	; Write hello message
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, hello_3
	mov edx, hello_len_3
	call __syscall

;create diff loop
;diff _again


_loop_3:

	; Write prompt input guess

	mov eax, [tries3] ; tell the user how much tries left
	mov ebx, 1 ; Optimization warning: May change. Do not use if tries > 9. Use standard __itoa instead.
	mov ecx, 10 ; Optimized
	call __itoa_knowndigits_3
	
	mov ecx, eax
	mov edx, ebx
	
	call __write
	mov ebx, 1 ; Stdout
	call __syscall
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, prompt_3
	mov edx, prompt_len_3
	call __syscall
	
	; Read input

	call __read
	mov ebx, 0 ; Stdin
	mov ecx, inputbuf_3
	mov edx, inputbuf_len_3
	call __syscall

	; Convert into integer

	mov ecx, eax
	sub ecx, 1 ; Get rid of extra newline
	
	cmp ecx, 1 ; Is the length of the number less than 1? (invalid)
	jl _reenter

	mov ebx, ecx

	mov eax, 0 ; Initalize eax
	jmp _loopconvert_nomul_3
;;;;

;-----

_loopconvert_3:

	imul eax, 10 ; Multiply by 10
	
_loopconvert_nomul_3:

	mov edx, ebx
	sub edx, ecx
	
	push eax
	
	mov ah, [inputbuf_3+edx]
	
	sub ah, 48 ; ASCII digits offset
	
	cmp ah, 0 ; Less than 0?
	jl _again_3
	cmp ah, 9 ; More than 9?
	jg _again_3

	movzx edx, ah
	
	pop eax
	add eax, edx

	loop _loopconvert_3
	
	jmp _convertok_3

;possible change
_reenter_3:

	; Write message

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, reenter
	mov edx, reenter_len
	call __syscall

	; Repeat enter

	jmp _loop_3
	
_toohigh_3:

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toohigh
	mov edx, toohigh_len
	call __syscall

	jmp _again_3

_toolow_3:
	
	call __write
	mov ebx, 1 ; Stdout
	mov ecx, toolow
	mov edx, toolow_len
	call __syscall

_again_3:

	cmp dword [tries3], 1 ; Is this the last try?
	jle _lose_3

	sub dword [tries3], 1 ; Minus one try.
	
	jmp _loop_3

_lose_3:

	; You lose

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose
	mov edx, youlose_len
	call __syscall

	mov eax, [randint]
	call __itoa_3

	mov ecx, eax
	mov edx, ebx
	call __write
	mov ebx, 1 ; Stdout
	call __syscall

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youlose2
	mov edx, youlose2_len
	call __syscall

	mov ebx, 2 ; Exit code for OK, lose.

	jmp _exit

_convertok_3:

	; Compare input

	cmp eax, [randint]
	jg _toohigh_3
	jl _toolow_3

	; You win

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, youwin
	mov edx, youwin_len
	call __syscall

	mov ebx, 1 ; Exit code for OK, win.
;

_exit_3:

	push ebx

	; Print normal goodbye

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, goodbye
	mov edx, goodbye_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Report OK.

	call __write
	mov ebx, 1 ; Stdout
	mov ecx, _ok
	mov edx, _ok_len
	call __syscall
	mov ebx, 2 ; Stderr
	call __syscall

	; Exit

	call __exit
	pop ebx
	call __syscall
	
	
; Procedures

__itoa_init_3:

	; push eax
	; push ebx
	; We do not have to preserve as it will contain
	; A return value

	pop dword [_itoabuf_3]

	push ecx
	push edx

	push dword [_itoabuf_3]
	
	ret

__itoa_3: ; Accept eax (i), return eax (a), ebx (l)

	call __itoa_init_3

	mov ecx, 10 ; Start with 10 (first 2-digit) 'if altered answer is seen as 0 but 10'
	mov ebx, 1 ; If less than 10, it has 1 digit.

__itoa_loop_3:

	cmp eax, ecx
	jl __itoa_loopend_3

	imul ecx, 10 ; Then go to 100, 1000... 'if set to 100 answer is 10 but seen as 00'
	add ebx, 1 ; Then go to 2, 3... 'if set to 10 the answer becomes 00000... but meaning 10'
	jmp __itoa_loop_3

__itoa_knowndigits_3: ; Accept eax (i), ebx (d), ecx (m), return eax (a), ebx (l)

	call __itoa_init_3

__itoa_loopend_3:

	; Prepare for loop
	; edx now contains m
	; ecx is now ready to count.
	; eax already has i
	; ebx already has d.

	mov edx, ecx
	mov ecx, ebx
	
	push ebx

__itoa_loop2_3:

	push eax

	; Divide m by 10 into m

	mov eax, edx
	mov edx, 0 ; Exponent is 0
	mov ebx, 10 ; Divide by 10 ;if div the answer will be 00 but meaning 10

	idiv ebx
	mov ebx, eax ; New m
	
	; Divide number by new m into (1)

	mov eax, [esp] ; Number
	mov edx, 0 ; Exponent is 0
	idiv ebx ; (1)

	; Store into buffer

	mov edx, [esp+4] ; Each dword has 4 bytes
	sub edx, ecx
	
	add eax, 48 ; Offset (1) as ASCII number
	
	mov [_itoabuf_3+edx], eax

	sub eax, 48 ; Un-offset (1) to prepare for next step

	; Multiply (1) by m into (1)

	imul eax, ebx

	; Subtract number by (1) into number
	
	mov edx, ebx ; Restore new-m back to edx as m
	
	pop ebx ; Number
	sub ebx, eax ; New number
	mov eax, ebx	

	loop __itoa_loop2_3

	; Return buffer array address and
	; Pop preserved ebx as length

	mov eax, _itoabuf_3
	pop ebx

	; Pop preserved registers and restore

	pop edx
	pop ecx	

	ret
;;;;
;;END OF LEVEL 3

;__error:
__exit:
	
	mov eax, 1 ; Exit syscall
	ret

__read:

	mov eax, 3 ; Read syscall
	ret

__write:
	
	mov eax, 4 ; Write syscall
	ret

__open:

	mov eax, 5 ; Open syscall
	ret

__close:

	mov eax, 6 ; Close syscall
	ret

__syscall:

	int 0x80 ; Interupt kernel
	ret

	; Get random number
_generate_random:
	call __open
	mov ebx, _dev_random
	mov ecx, 0 ; RDONLY
	call __syscall

	mov ebx, eax
	push eax
	call __read
	mov ecx, randint
	mov edx, 4 ; 4 bytes of random; 32-bit
	call __syscall
	
	call __close
	pop ebx
	call __syscall

	mov eax, [randint]
	ret
	;the random number needs to be fetched before starting the levels

;take user input
__prompt_1:
mov eax,4
mov ebx,1
mov ecx,userprompt
mov edx,userprompt_len
int 0x80
;
;
mov eax,4
mov ebx,1
mov ecx,choice_1
mov edx,choice_1_len
int 0x80
;
mov eax,4
mov ebx,1
mov ecx,choice_2
mov edx,choice_2_len
int 0x80
;
mov eax,4
mov ebx,1
mov ecx,choice_3
mov edx,choice_3_len
int 0x80
ret

__userInput:
mov eax,3 ;syscall_read
mov ebx,0 ;stdin
mov ecx,userChoice ;buffer to be stored in userChoice
mov edx,2
int 0x80

__checkInput:
cmp byte[userChoice],'1'
je __easy_level
cmp byte[userChoice],'2'
je __medium_level
cmp byte[userChoice],'3'
je __hard_level

;define an error loop to check if user input is invalid


; Data declaration

section .data
	;userprompt about level of difficulty strings
	userprompt db 0xa,"Welcome to our guessing game!" ,0xa ,0xa ,"please choose a level of difficulty",0xa,0xa
	userprompt_len equ $-userprompt

	choice_1 db "1.For Easy Press 1",0xa,0xa
	choice_1_len equ $-choice_1

	choice_2 db "2.For Medium Press 2",0xa,0xa
	choice_2_len equ $-choice_2
	
	choice_3 db "3.For Hard Press 3",0xa,0xa
	choice_3_len equ $-choice_3
	;;

	_dev_random db "/dev/random", 0xa

	;easylevel tries
	maxrand equ 100
	tries dd 6

	;medium level tries
	maxrand2 equ 500
	tries2 dd 4

	;hard level tries
	maxrand3 equ 1000
	tries3 dd 2

	;medium
	prompt_2 db  " tries left. Input number (1-500): ",0xa,0xa
	prompt_len_2 equ $-prompt_2

	hello_2 db 0xa, 0xa, "I am now thinking of a number. What is it?", 0xa,0xa, "Take a guess, from one to five hundred.", 0xa, 0xa
	hello_len_2 equ $-hello_2
	;

	;hard level prompts
	prompt_3 db  " tries left. Input number (1-1000): ",0xa,0xa
	prompt_len_3 equ $-prompt_3

	hello_3 db 0xa, 0xa, "I am now thinking of a number. What is it?", 0xa,0xa, "Take a guess, from one to one thousand.", 0xa, 0xa
	hello_len_3 equ $-hello_3
;
	prompt db  " tries left. Input number (1-100): ",0xa,0xa
	prompt_len equ $-prompt

	hello db 0xa, 0xa, "I am now thinking of a number. What is it?", 0xa,0xa, "Take a guess, from one to one hundred.", 0xa, 0xa
	hello_len equ $-hello

	reenter db "? REENTER", 0xa, "Invalid unsigned integer. Please re-enter your input.", 0xa
	reenter_len equ $-reenter

	toohigh db "That was too high!", 0xa, 0xa
	toohigh_len equ $-toohigh

	toolow db "That was too low!", 0xa, 0xa
	toolow_len equ $-toolow

	youwin db 0x7, 0xa, "#^$&^@%#^@#! That was correct! You win!", 0xa, 0xa
	youwin_len equ $-youwin

	youlose db "You have no more tries left! You lose!", 0xa, "The answer was "
	youlose_len equ $-youlose

	youlose2 db "! Mwahahah!", 0xa, 0xa
	youlose2_len equ $-youlose2

	goodbye db "Goodbye.", 0xa
	goodbye_len equ $-goodbye

	_ok db "Exit OK. There were no errors.", 0xa, 0xa
	_ok_len equ $-_ok

section .bss

	userChoice resb 1

	randint resw 2
	downsize resw 2
	
	_itoabuf resb 1024

	inputbuf resb 1024
	inputbuf_len equ 1024

;medium level
	downsize_2 resw 2
	
	_itoabuf_2 resb 1024

	inputbuf_2 resb 1024
	inputbuf_len_2 equ 1024

;medium level
	downsize_3 resw 2
	
	_itoabuf_3 resb 1024

	inputbuf_3 resb 1024
	inputbuf_len_3 equ 1024


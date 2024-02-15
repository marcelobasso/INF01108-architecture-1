
	.model small
	.stack

	.data
		; constantes e strings
		CR			equ		13					; Carriage Return (Enter)
		LF			equ		10  				; Line Feed ('\n')
		SPACE		equ		' '
		HYPHEN		equ		'-'
		DEFAULT_TENSION	equ		127
		FLAG_I			DB 		'i'			
		DEFAULT_IN		DB		'a.in', 0
		I_ERROR			DB		'Opcao [-i] sem parametro', LF, 0
		FLAG_O			DB 		'o'			
		DEFAULT_OUT		DB		'a.out', 0
		O_ERROR			DB		'Opcao [-o] sem parametro', LF, 0
		FLAG_V			DB 		'v'
		DEFAULT_TENSION_STR		DB 	'127', 0
		V_ERROR			DB		'Opcao [-v] sem parametro', LF, 0
		V_ERROR_2		DB		'Parametro da opcao [-v] deve ser 127 ou 220', LF, 0
		
		; buffers
		CMDLINE			DB 	240 DUP (?) 	; usado na funcao GetCMDLine
		BufferWRWORD	DB  80 	DUP (?)		; usado na funcao WriteWord
	
		; variables
		cmdline_size	DW	0
		file_in			DB	80	DUP (?)		; string: arquivo de entrada
		file_out		DB	80 	DUP (?)		; string: arquivo de saida
		tension_str		DB  80	DUP (?) 	; string: valor de tensao
		tension_int		DB 	0				; int: tensao convertida
		flag_error		DB 	0				; int: indica se há erro nas flags
		
	.code
	.startup
		call	GetCMDLine					; le linha do CMD	
		mov		cmdline_size, ax
		
		mov		flag_error, 0
		call	ValidateFlags
		cmp		flag_error, 1
		jz		fim
	
		lea		bx, file_in
		call	WriteString
		
		lea		bx, file_out
		call    WriteString
		
		lea		bx, tension_str
		call	WriteString
	
	fim:
	.exit

;--------------------------------------------------------------------
; FUNÇÕES AUXILIARES
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; ValidateFlags: verifica se as flags são válida na linha de comando
; Entrada:
; Saida: ax = 0: entradas válidas
;		 ax = 1: uma ou mais flags inválidas
;--------------------------------------------------------------------
ValidateFlags	proc	near
		lea		ax, FLAG_I			; procura flag i
		lea 	cx, file_in
		lea		dx, I_ERROR
		lea		bp, DEFAULT_IN
		call 	ValidateFlag
		
		lea		ax, FLAG_O			; procura flag o
		lea 	cx, file_out
		lea		dx, O_ERROR
		lea		bp, DEFAULT_OUT
		call 	ValidateFlag
		
		lea		ax, FLAG_V			; procura flag v
		lea 	cx, tension_str
		lea		dx, V_ERROR
		lea		bp, DEFAULT_TENSION_STR
		call 	ValidateFlag
		
		ret
ValidateFlags	endp

;--------------------------------------------------------------------
; ValidateFlag: verifica se uma flag é válida na linha de comando.
; entra: ax: flag a ser encontrada
;		 bp: Valor padrao a ser settado caso nao houver flag
;		 dx: Mensagem de erro
;		 cx: ponteiro para variavel a ser settada
; retorna:
;		 flag_error = 1: se houver opcao sem parametro
;--------------------------------------------------------------------
ValidateFlag	proc	near
		push	bp					; empilha parametros
		push	cx
		push	dx
		call	FindFlag
		pop		dx					; desempilha parametros
		pop		cx
		pop		bp
		
		cmp		ax, 0				; verifica retorno da FindFlag
		jz		flag_ok
		
		cmp		ax, 1
		jz		flag_sem_param
	
		mov		bx, bp				; seta valor padrao caso nao houver a flag (ax = 2)
		mov		bp, cx
		call	Strcpy
		jmp		flag_ok
		
	flag_sem_param:
		mov 	bx, dx				; printa mensagem de erro passada pelo dx
		call	WriteString
		mov		flag_error, 1
		
	flag_ok:
		ret
ValidateFlag	endp

;--------------------------------------------------------------------
; FindFlag: procura uma flag no buffer CMDLINE e seta seu valor na
;			variavel indicada.
; entra: ax: flag a ser encontrada
;		 bx: Usada internamente como ponteiro para CMDLINE
;		 cx: ponteiro para variavel a ser settada caso houver entrada
; retorna:
;		 ax = 0: achou a flag e settou valor
;		 ax = 1: erro (flag sem parametro), 
;		 ax = 2: nao achou a flag
;--------------------------------------------------------------------
FindFlag	proc	near
		lea		bx, CMDLINE
		mov		dh, 0
	
	FF_1:
		mov		dl, [bx]		; While (*S!='\0') {
		cmp		dl, 0
		jnz		FF_2
		mov		ax, 2			; Caso nao encontrou a flag, retorna 2
		ret
		
	FF_2:
		cmp		dl, SPACE		; procura a sequencia " -FLAG " onde flag pode ser i, o ou v
		jnz		FF_3
		
		call 	GetNextChar
		cmp		dl, HYPHEN
		jnz		FF_3
		
		call	GetNextChar
		mov		bp, ax
		cmp		dl, [bp]
		jnz		FF_3
		
		call	GetNextChar
		cmp		dl, 0
		jz		FF_error
		cmp		dl, SPACE
		jnz		FF_3
		
		; --- encontrou a flag desejada ---
		call	GetNextChar 		; verifica flag sem parametro (retorna 1)
		cmp		dl, 0
		jz		FF_error
		cmp		dl, HYPHEN
		jz		FF_error
		cmp		dl, LF
		jz 		FF_error
		cmp		dl, CR
		jz		FF_error
		cmp		dl, SPACE
		jz		FF_error
		jmp		FF_found
		
	FF_error:
		mov		ax, 1				; retorna 1 indicando que flag nao tem parametro
		ret
		
	FF_found:
		mov		bp, cx				; caso nenhum erro ocorreu, setta valor na variavel indicada
		call	Strcpy
		mov		ax, 0				; retorna 0 indicando sucesso
		ret
		
	FF_3:	
		inc		bx
		jmp		FF_1

FindFlag 	endp

;--------------------------------------------------------------------
; GetNextChar: dl <- [++bx]
; Entra: bx: ponteiro para string a ser percorrida
; Retorna: dl: char lido
;--------------------------------------------------------------------
GetNextChar	proc	near
	inc		bx
	mov		dl,	[bx]
	ret
GetNextChar	endp

;--------------------------------------------------------------------
; Strcpy: dados dois ponteiros de string, copia uma para a outra
;		  até encontrar um espaço, ignorando espaços iniciais.
; Entrada: bx: string origem
;		   bp: string destino
;--------------------------------------------------------------------
Strcpy		proc 	near
	CP_repeat:
		mov 	al, [bx]    	; Load character from source string
		cmp 	al, SPACE      	; Compare with space character
		jne 	CP_1			; If not a space, exit loop
		inc 	bx           	; Move to the next character
		jmp 	CP_repeat       ; Repeat until non-space character is found

	CP_1:
		mov		al, [bx] 		; copia ate encontra espaco, final da string, CR ou LF
		cmp		al, 0
		jz		CP_end
		cmp		al, SPACE
		jz		CP_end
		cmp		al, CR
		jz		CP_end
		cmp		al, LF
		jz		CP_end

	CP_2:		
		mov		ax, [bx]
		mov		[bp], ax
		inc		bp
		inc		bx
		jmp		CP_1
		
	CP_end:
		mov		[bp], 0
		ret

Strcpy		endp

;--------------------------------------------------------------------
;Função: Escreve o valor de AX na tela
;--------------------------------------------------------------------
WriteWord	proc	near
		lea		bx, BufferWRWORD
		call	HexToDecAscii
		
		lea		bx, BufferWRWORD
		call	WriteString
		
		ret
WriteWord	endp


;--------------------------------------------------------------------
; Função: Escrever um string na tela
; Entra: DS:BX -> Ponteiro para o string
;--------------------------------------------------------------------
WriteString	proc	near

WS_2:
		mov		dl, [bx]		; While (*S!='\0') {
		cmp		dl, 0
		jnz		WS_1
		ret

WS_1:
		mov		ah, 2		; 	Int21(2)
		int		21H

		inc		bx			; 	++S
		jmp		WS_2		; }

WriteString	endp

;--------------------------------------------------------------------
; Função: copiar o string digitado na linha de comando para um buffer 
;         no segmento de dados do programa (tamanho em AX)
; Entra: 
;--------------------------------------------------------------------
GetCMDLine	proc	near
	push ds ; Salva as informações de segmentos
	push es

	mov ax, ds ; Troca DS com ES para poder usa o REP MOVSB
	mov bx, es
	mov ds, bx
	mov es, ax
	mov si, 80h ; Obtém o tamanho do string da linha de comando e coloca em CX
	mov ch, 0
	mov cl, [si]
	mov ax, cx ; Salva o tamanho do string em AX, para uso futuro
	mov si, 81h ; Inicializa o ponteiro de origem
	lea di, CMDLINE ; Inicializa o ponteiro de destino
	rep movsb
	pop es ; retorna as informações dos registradores de segmentos 
	pop ds
	
GetCMDLine endp

;
;--------------------------------------------------------------------
;Função: Converte um valor HEXA para ASCII-DECIMAL
;Entra:  (A) -> AX -> Valor "Hex" a ser convertido
;        (S) -> DS:BX -> Ponteiro para o string de destino
;--------------------------------------------------------------------
HexToDecAscii	proc near

		mov	cx,0			;N = 0;
H2DA_2:
		or	ax,ax			;while (A!=0) {
		jnz	H2DA_0
		or	cx,cx
		jnz	H2DA_1

H2DA_0:
		mov	dx,0			;A = A / 10
		mov	si,10			;dl = A % 10 + '0'
		div	si
		add	dl,'0'

		mov	si,cx			;S[N] = dl
		mov	[bx+si],dl

		inc	cx				;++N
		jmp	H2DA_2

H2DA_1:
		mov	si,cx			;S[N] = '\0'
		mov	byte ptr[bx+si],0

		mov	si,bx			;i = 0

		add	bx,cx			;j = N-1
		dec	bx

			sar	cx,1			;N = N / 2

H2DA_4:
		or	cx,cx			;while (N!=0) {
		jz	H2DA_3


		mov	al,[si]			;S[i] <-> S[j]
		mov	ah,[bx]
		mov	[si],ah
		mov	[bx],al

		dec	cx				;	--N

		inc	si				;	++i

		dec	bx				;	--j
		jmp	H2DA_4

H2DA_3:
		ret

HexToDecAscii	endp

BreakLine	proc	near
	mov		dl, LF
	mov		ah, 2
	int		21h
	ret
BreakLine	endp
		
;--------------------------------------------------------------------
	end
;--------------------------------------------------------------------
	
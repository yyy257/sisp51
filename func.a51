SendString:
	; sends null-terminated string over UART
	; DPTR points to string in code memory
	; receiver must be locked!
	; after execution DPTR points to null char

	; load the char
		clr A
		movc A, @A+DPTR
		jz EndSendStr ; end on null	
		; send the char
		mov SBUF, A
WaitSendStr:
			jnb TI, WaitSendStr
		clr TI
		inc DPTR
	sjmp SendString ; loop - load next char
EndSendStr:
	ret

GetAddress19:
	acall GetCharEcho
	orl A, #11111000b
	; P1.0-P1.2 are A16-A18
	mov P1, A
	acall GetHexByte
	mov DPH, A
	acall GetHexByte
	mov DPL, A
NewLine:
	mov A, #0Dh
	acall SendChar
	mov A, #0Ah
	sjmp SendChar

GetCharEcho:
	acall GetChar
SendChar:
	; sends character in A
	; receiver must be locked
	mov SBUF, A
WaitSendChar:
		jnb TI, WaitSendChar
	clr TI
	ret

GetChar:
	; waits for a character over UART
	; returns character in A
	setb REN						 ; unlock receiver
WAIT_UART:
		jnb RI, WAIT_UART	 ; poll until there's a char
	clr RI						   ; clear flag after receiving
	clr REN						   ; lock receiver
	mov A, SBUF				   ; put char in A
	ret

GetHexByte:
	; gets byte (2 hex digits in ASCII) over UART
	; returns hex in A
	mov R0, #0
	acall GetHexNibble
	clr C
	rlc A
	rlc A
	rlc A
	rlc A				; shift nibble to the left
	mov R0, A
GetHexNibble:
	acall GetCharEcho
	add A, #-'0'
	; this cjne is only for the cmp
	; like cmp on other CPUs
	cjne A, #9+1, GetHexNibbleCmp ; clear C flag if not 0-9
GetHexNibbleCmp:
	jc GetHexNibbleDec
	anl A, #11011111b ; ensure uppercase
	add A, #-7	; adjust if A-F not 0-9
GetHexNibbleDec:
	orl A, R0		; combine nibbles if previous is stored in R0
	ret

SendHexByte:
	; sends byte in A as 2 hex digits over UART
	mov R0, A	
	anl A, #0F0h
	rr A
	rr A
	rr A
	rr A
	acall SendHexNibble
	mov A, R0
	anl A, #0Fh
SendHexNibble:
	add A, #'0'
	cjne A, #'9'+1, SendHexNibbleCmp ; set C flag if 0-9
SendHexNibbleCmp:
	jc SendHexNibbleDec
	add A, #7	; adjust A-F
SendHexNibbleDec:
	ajmp SendChar ; tail call

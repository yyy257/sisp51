	START CODE 0000H ;start address of user programs
	MAIN EQU 0050H   ;code is here after interrupt vectors
	AUXR DATA 8Eh
	AUXR1 DATA 0A2h
	;EXTRAM EQU 8Eh.1

	ORG START
	SJMP MAIN

	; unused space for interrupt vectors

	ORG MAIN
	; init stack pointer
	mov SP, #7Fh
	; enable external memory buses
	; and set internal XRAM to 1024 bytes
	orl AUXR, #00001110b
	; init UART
	mov SCON, #01000000b ; UART mode 1 - 8-bit chars
										   ; set freq with timer
	orl TMOD, #00100000b ; timer T1 8-bit mode
											 ; T1 counts, resetting from TH1
	orl PCON, #80h       ; SMOD = 1
	mov TH1, #0FAh			 ; 9600 baud
	setb TR1						 ; start T1

ReceiveCmd:
	; output greeting message over UART
	clr REN							 ; lock receiver
	mov DPTR, #GreetingStr
	acall SendString

	; get command over UART
	acall GetCharEcho
	clr ACC.5				 ; make character always uppercase

	; interpret command
	cjne A, #'R', NotRead
		; read bytes from the programmed memory

		; prompt user for byte count
		mov DPTR, #ReadCountPromptStr
		acall SendString
		; get byte count
		acall GetHexByte
		mov R1, A ; use R1 as loop counter
		
		; prompt user for address
		mov DPTR, #ReadAddrPromptStr
		acall SendString
		; get 19-bit address in DPTR (5 hex digits)
		acall GetAddress19

		; read the bytes and print them
		acall NewLine
ReadMemLoop:
			movx A, @DPTR
			acall SendHexByte
			mov A, #' '
			acall SendChar
			inc DPTR
		djnz R1, ReadMemLoop
	sjmp ReceiveCmd
NotRead:
	cjne A, #'E', NotErase
		; erase a sector

		; prompt user for address
		mov DPTR, #EraseAddrPromptStr
		acall SendString
		acall GetAddress19

		; ask user if he wants to continue
		inc AUXR1 ; swap DPTR
		mov DPTR, #AreYouSureStr
		acall SendString
		inc AUXR1 ; swap DPTR
		acall GetCharEcho
		clr ACC.5				 ; make character always uppercase
		cjne A, #'Y', ReceiveCmd

		; send erase sequence
		mov R5, P1	
		mov P1, #11111000b
		inc AUXR1 ; swap DPTR
		mov DPTR, #5555h
		mov A, #0AAh
		movx @DPTR, A
		mov DPTR, #2AAAh
		mov A, #55h
		movx @DPTR, A
		mov DPTR, #5555h
		mov A, #80h
		movx @DPTR, A
		mov DPTR, #5555h
		mov A, #0AAh
		movx @DPTR, A
		mov DPTR, #2AAAh
		mov A, #55h
		movx @DPTR, A
		inc AUXR1 ; swap DPTR
		mov P1, R5
		mov A, #30h
		movx @DPTR, A
		
		; inform about finishing
		mov DPTR, #EraseFinishStr
		acall SendString
ReceiveCmdNear:	
	ajmp ReceiveCmd
NotErase:
	cjne A, #'W', WrongCmd
		; program bytes into memory

		; prompt user for address
		mov DPTR, #WriteAddrPromptStr
		acall SendString
		acall GetAddress19
		mov R6, DPH
		mov R7, DPL
		
		; ask user if he wants to continue
		mov DPTR, #AreYouSureStr
		acall SendString
		acall GetCharEcho
		clr ACC.5				 ; make character always uppercase
		cjne A, #'Y', ReceiveCmdNear
		
		; prompt for sending data
		mov DPTR, #SendDataPromptStr
		acall SendString

		; get 1024 bytes of data
		;clr AUXR.1  ; enable internal XRAM to store data
		anl AUXR, #11111101b
		mov DPTR, #0
		mov R2, #4	; 4*256 = 1024
	GetDataLoop1:
			mov R3, #0 ; init with 0 to loop 256 times
	GetDataLoop2:
				acall GetChar
				movx @DPTR, A
				inc DPTR	
			djnz R3, GetDataLoop2
		djnz R2, GetDataLoop1	

		; inform about receiving
		mov DPTR, #DataReceivedStr
		acall SendString

		; write the bytes
		mov DPTR, #0
		mov R2, #4
	WriteDataLoop1:
			mov R3, #0
	WriteDataLoop2:
				; load byte from internal XRAM
				anl AUXR, #11111101b
				movx A, @DPTR
				inc DPTR
				inc AUXR1 ; swap DPTR
				; don't write if byte is 0xFF
				inc A
				jz WriteDataIncDPTR
				dec A
				mov R4, A
				; write the byte
				;setb AUXR.1	; switch to external memory (flash)
				orl AUXR, #00000010b
				mov R5, P1	
				mov P1, #11111000b
				mov DPTR, #5555h
				mov A, #0AAh
				movx @DPTR, A
				mov DPTR, #2AAAh
				mov A, #55h
				movx @DPTR, A
				mov DPTR, #5555h
				mov A, #0A0h
				movx @DPTR, A
				mov P1, R5
				mov DPH, R6
				mov DPL, R7
				mov A, R4
				movx @DPTR, A
	WriteDataIncDPTR:
				mov DPH, R6
				mov DPL, R7
				inc DPTR
				mov R6, DPH
				mov R7, DPL
				
				inc AUXR1 ; swap DPTR
			djnz R3, WriteDataLoop2
		djnz R2, WriteDataLoop1	
		
		; inform about finishing
		mov DPTR, #WriteFinishStr
		acall SendString
	ajmp ReceiveCmd
			
WrongCmd:
		mov DPTR, #WrongCmdStr
		acall SendString
	ajmp ReceiveCmd

$INCLUDE(func.a51)

GreetingStr:
	db 0Dh, 0Ah
	db "sisp51 v1.0", 0Dh, 0Ah
	db "Commands:", 0Dh, 0Ah
	db "E - erase sector", 0Dh, 0Ah
	db "W - write sector", 0Dh, 0Ah
	db "R - read memory", 0Dh, 0Ah
PromptStr:
	db ">", 0
ReadAddrPromptStr:
	db 0Dh, 0Ah
	db "Enter address to read (5 hex digits): ", 0
ReadCountPromptStr:
	db 0Dh, 0Ah
	db "How many bytes to read (2 hex digits): ", 0
WriteAddrPromptStr:
	db 0Dh, 0Ah
	db "Enter address to begin writing (5 hex digits): ", 0
AreYouSureStr:
	db 0Dh, 0Ah
	db "Are you sure (Y/N)? ", 0
WrongCmdStr:
	db 0Dh, 0Ah, "Bad command.", 0Dh, 0Ah, 0
SendDataPromptStr:
	db 0Dh, 0Ah, "Please send exactly 1024 bytes of data to write.", 0Dh, 0Ah, 0
DataReceivedStr:
	db "Data received, writing...", 0
WriteFinishStr:
	db 0Dh, 0Ah, "Written 1024 bytes.", 0
EraseAddrPromptStr:
	db 0Dh, 0Ah
	db "Enter address of 4096 byte sector to erase (5 hex digits): ", 0
EraseFinishStr:
	db 0Dh, 0Ah, "Sector erased.", 0
	END

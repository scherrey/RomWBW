;
;==================================================================================================
; SIO DRIVER (SERIAL PORT)
;==================================================================================================
;
;  SETUP PARAMETER WORD:
;  +-------+---+-------------------+ +---+---+-----------+---+-------+
;  |       |RTS| ENCODED BAUD RATE | |DTR|XON|  PARITY   |STP| 8/7/6 |
;  +-------+---+---+---------------+ ----+---+-----------+---+-------+
;    F   E   D   C   B   A   9   8     7   6   5   4   3   2   1   0
;       -- MSB (D REGISTER) --           -- LSB (E REGISTER) --
;
; FOR THE ECB-ZILOG-PERIPHERALS BOARD, INFORMATION ON JUMPER SETTINGS 
; AND BAUD RATES CAN BE FOUND HERE:
; https://www.retrobrewcomputers.org/doku.php?id=boards:ecb:zilog-peripherals:clock-divider
; 
; SIO PORT A (COM1:) and SIO PORT B (COM2:) ARE MAPPED TO DEVICE UC1: AND UL1: IN CP/M.
;
SIO_BUFSZ	.EQU	32			; RECEIVE RING BUFFER SIZE
;
SIO_NONE	.EQU	0
SIO_SIO		.EQU	1
;
SIO_RTSON	.EQU	$EA
SIO_RTSOFF	.EQU	$E8
;
#IF (SIO0MODE == SIOMODE_RC)
SIO0A_CMD	.EQU	SIO0BASE + $00	
SIO0A_DAT	.EQU	SIO0BASE + $01
SIO0B_CMD	.EQU	SIO0BASE + $02
SIO0B_DAT	.EQU	SIO0BASE + $03
#ENDIF	
;	
#IF (SIO0MODE == SIOMODE_SMB)
SIO0A_CMD	.EQU	SIO0BASE + $02
SIO0A_DAT	.EQU	SIO0BASE + $00
SIO0B_CMD	.EQU	SIO0BASE + $03
SIO0B_DAT	.EQU	SIO0BASE + $01
#ENDIF
;
#IF (SIO0MODE == SIOMODE_ZP)		
SIO0A_CMD	.EQU	SIO0BASE + $06
SIO0A_DAT	.EQU	SIO0BASE + $04 
SIO0B_CMD	.EQU	SIO0BASE + $07
SIO0B_DAT	.EQU	SIO0BASE + $05
#ENDIF
;
#IF (SIO0MODE == SIOMODE_EZZ80)
SIO0A_CMD	.EQU	SIO1BASE + $01	
SIO0A_DAT	.EQU	SIO1BASE + $00
SIO0B_CMD	.EQU	SIO1BASE + $03
SIO0B_DAT	.EQU	SIO1BASE + $02
#ENDIF
;
#IF (SIOCNT >= 2)
;
#IF (SIO1MODE == SIOMODE_RC)
SIO1A_CMD	.EQU	SIO1BASE + $00	
SIO1A_DAT	.EQU	SIO1BASE + $01
SIO1B_CMD	.EQU	SIO1BASE + $02
SIO1B_DAT	.EQU	SIO1BASE + $03
#ENDIF	
;	
#IF (SIO1MODE == SIOMODE_SMB)
SIO1A_CMD	.EQU	SIO1BASE + $02
SIO1A_DAT	.EQU	SIO1BASE + $00
SIO1B_CMD	.EQU	SIO1BASE + $03
SIO1B_DAT	.EQU	SIO1BASE + $01
#ENDIF
;
#IF (SIO1MODE == SIOMODE_ZP)		
SIO1A_CMD	.EQU	SIO1BASE + $06
SIO1A_DAT	.EQU	SIO1BASE + $04 
SIO1B_CMD	.EQU	SIO1BASE + $07
SIO1B_DAT	.EQU	SIO1BASE + $05
#ENDIF
;
#IF (SIO1MODE == SIOMODE_EZZ80)
SIO1A_CMD	.EQU	SIO1BASE + $01	
SIO1A_DAT	.EQU	SIO1BASE + $00
SIO1B_CMD	.EQU	SIO1BASE + $03
SIO1B_DAT	.EQU	SIO1BASE + $02
#ENDIF
;
#ENDIF
;
; CONDITIONALS THAT DETERMINE THE ENCODED VALUE OF THE BAUD RATE
;
#INCLUDE "siobaud.inc"	
;
SIO_PREINIT:
;
; SETUP THE DISPATCH TABLE ENTRIES
; NOTE: INTS WILL BE DISABLED WHEN PREINIT IS CALLED AND THEY MUST REMIAIN
; DISABLED.
;
	CALL	SIO_PROBE		; PROBE FOR CHIPS
;
	LD	B,SIO_CFGCNT		; LOOP CONTROL
	XOR	A			; ZERO TO ACCUM
	LD	(SIO_DEV),A		; CURRENT DEVICE NUMBER
	LD	IY,SIO_CFG		; POINT TO START OF CFG TABLE
SIO_PREINIT0:	
	PUSH	BC			; SAVE LOOP CONTROL
	CALL	SIO_INITUNIT		; HAND OFF TO GENERIC INIT CODE
	POP	BC			; RESTORE LOOP CONTROL
;
	LD	A,(IY+1)		; GET THE SIO TYPE DETECTED
	OR	A			; SET FLAGS
	JR	Z,SIO_PREINIT2		; SKIP IT IF NOTHING FOUND
;	
	PUSH	BC			; SAVE LOOP CONTROL
	PUSH	IY			; CFG ENTRY ADDRESS
	POP	DE			; ... TO DE
	LD	BC,SIO_FNTBL		; BC := FUNCTION TABLE ADDRESS
	CALL	NZ,CIO_ADDENT		; ADD ENTRY IF SIO FOUND, BC:DE
	POP	BC			; RESTORE LOOP CONTROL
;
SIO_PREINIT2:	
	LD	DE,SIO_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,DE			; BUMP IY TO NEXT ENTRY
	DJNZ	SIO_PREINIT0		; LOOP UNTIL DONE
;
#IF (INTMODE >= 1)
	; SETUP INT VECTORS AS APPROPRIATE
	LD	A,(SIO_DEV)		; GET NEXT DEVICE NUM
	OR	A			; SET FLAGS
	JR	Z,SIO_PREINIT3		; IF ZERO, NO SIO DEVICES, ABORT
;
#IF (INTMODE == 1)
	; ADD IM1 INT CALL LIST ENTRY
	LD	A,(SIO_DEV)		; GET NEXT DEVICE NUM
	OR	A			; SET FLAGS
	JR	Z,SIO_PREINIT3		; IF ZERO, NO SIO DEVICES
	LD	HL,SIO_INT		; GET INT VECTOR
	CALL	HB_ADDIM1		; ADD TO IM1 CALL LIST
#ENDIF
;
#IF (INTMODE == 2)
	; SETUP IM2 VECTORS
	LD	HL,SIO_INT0
	LD	(HB_IVT07 + 1),HL	; IVT INDEX 7
;
#IF (SIOCNT >= 2)
	LD	HL,SIO_INT1
	LD	(HB_IVT08 + 1),HL	; IVT INDEX 8
#ENDIF
;
#ENDIF
;
#ENDIF
;
SIO_PREINIT3:
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; SIO INITIALIZATION ROUTINE
;
SIO_INITUNIT:
	CALL	SIO_DETECT		; DETERMINE SIO TYPE
	LD	(IY+1),A		; SAVE IN CONFIG TABLE
	OR	A			; SET FLAGS
	RET	Z			; ABORT IF NOTHING THERE

	; UPDATE WORKING SIO DEVICE NUM
	LD	HL,SIO_DEV		; POINT TO CURRENT UART DEVICE NUM
	LD	A,(HL)			; PUT IN ACCUM
	INC	(HL)			; INCREMENT IT (FOR NEXT LOOP)
	LD	(IY),A			; UPDATE UNIT NUM
	
	; SET DEFAULT CONFIG
	LD	DE,-1			; LEAVE CONFIG ALONE
	; CALL INITDEVX TO IMPLEMENT CONFIG, BUT NOTE THAT WE CALL
	; THE INITDEVX ENTRY POINT THAT DOES NOT ENABLE/DISABLE INTS!
	JP	SIO_INITDEVX		; IMPLEMENT IT AND RETURN
;
;
;
SIO_INIT:
	LD	B,SIO_CFGCNT		; COUNT OF POSSIBLE SIO UNITS
	LD	IY,SIO_CFG		; POINT TO START OF CFG TABLE
SIO_INIT1:
	PUSH	BC			; SAVE LOOP CONTROL
	LD	A,(IY+1)		; GET SIO TYPE
	OR	A			; SET FLAGS
	CALL	NZ,SIO_PRTCFG		; PRINT IF NOT ZERO
	POP	BC			; RESTORE LOOP CONTROL
	LD	DE,SIO_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,DE			; BUMP IY TO NEXT ENTRY
	DJNZ	SIO_INIT1		; LOOP TILL DONE
;
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
; RECEIVE INTERRUPT HANDLER
;
#IF (INTMODE > 0)
;
; IM0 ENTRY POINT
;
SIO_INT:
	; CHECK/HANDLE FIRST CARD (SIO0) IF IT EXISTS
	LD	A,(SIO0A_CFG + 1)	; GET SIO TYPE FOR FIRST CHANNEL OF FIRST SIO
	OR	A			; SET FLAGS
	CALL	NZ,SIO_INT0		; CALL IF CARD EXISTS
	RET	NZ			; DONE IF INT HANDLED
;
#IF (SIOCNT >= 2)
	; CHECK/HANDLE SECOND CARD (SIO1) IF IT EXISTS
	LD	A,(SIO1A_CFG + 1)	; GET SIO TYPE FOR FIRST CHANNEL OF SECOND SIO
	OR	A			; SET FLAGS
	CALL	NZ,SIO_INT1		; CALL IF CARD EXISTS
#ENDIF
;
	RET				; DONE
;
; IM1 ENTRY POINTS
;
SIO_INT0:
	; INTERRUPT HANDLER FOR FIRST SIO (SIO0)
	LD	IY,SIO0A_CFG		; POINT TO SIO0A CFG
	CALL	SIO_INTRCV		; TRY TO RECEIVE FROM IT
	RET	NZ			; DONE IF INT HANDLED
	LD	IY,SIO0B_CFG		; POINT TO SIO0B CFG
	JR	SIO_INTRCV		; TRY TO RECEIVE FROM IT AND RETURN
;
#IF (SIOCNT >= 2)
;
SIO_INT1:
	; INTERRUPT HANDLER FOR SECOND SIO (SIO1)
	LD	IY,SIO1A_CFG		; POINT TO SIO1A CFG
	CALL	SIO_INTRCV              ; TRY TO RECEIVE FROM IT
	RET	NZ                      ; DONE IF INT HANDLED
	LD	IY,SIO1B_CFG            ; POINT TO SIO1B CFG
	JR	SIO_INTRCV              ; TRY TO RECEIVE FROM IT AND RETURN
;
#ENDIF
;
; HANDLE INT FOR A SPECIFIC CHANNEL
; BASED ON UNIT CFG POINTED TO BY IY
;
SIO_INTRCV:
	; CHECK TO SEE IF SOMETHING IS ACTUALLY THERE
	LD	C,(IY+3)		; CMD/STAT PORT TO C
	XOR	A			; A := 0
	OUT	(C),A			; ADDRESS RD0
	IN	A,(C)			; GET RD0
	AND	$01			; ISOLATE RECEIVE READY BIT
	RET	Z			; NOTHING AVAILABLE ON CURRENT CHANNEL
;
SIO_INTRCV1:
	; RECEIVE CHARACTER INTO BUFFER
	LD	C,(IY+4)		; DATA PORT TO C
	IN	A,(C)			; READ PORT
	LD	B,A			; SAVE BYTE READ
	LD	L,(IY+7)		; SET HL TO
	LD	H,(IY+8)		; ... START OF BUFFER STRUCT
	LD	A,(HL)			; GET COUNT
	CP	SIO_BUFSZ		; COMPARE TO BUFFER SIZE
	JR	Z,SIO_INTRCV4		; BAIL OUT IF BUFFER FULL, RCV BYTE DISCARDED
	INC	A			; INCREMENT THE COUNT
	LD	(HL),A			; AND SAVE IT
	CP	SIO_BUFSZ / 2		; BUFFER GETTING FULL?
	JR	NZ,SIO_INTRCV2		; IF NOT, BYPASS CLEARING RTS
	LD	C,(IY+3)		; CMD/STAT PORT TO C
	LD	A,5			; RTS IS IN WR5
	OUT	(C),A			; ADDRESS WR5
	LD	A,SIO_RTSOFF		; VALUE TO CLEAR RTS
	OUT	(C),A			; DO IT
SIO_INTRCV2:
	INC	HL			; HL NOW HAS ADR OF HEAD PTR
	PUSH	HL			; SAVE ADR OF HEAD PTR
	LD	A,(HL)			; DEREFERENCE HL
	INC	HL
	LD	H,(HL)
	LD	L,A			; HL IS NOW ACTUAL HEAD PTR
	LD	(HL),B			; SAVE CHARACTER RECEIVED IN BUFFER AT HEAD
	INC	HL			; BUMP HEAD POINTER
	POP	DE			; RECOVER ADR OF HEAD PTR
	LD	A,L			; GET LOW BYTE OF HEAD PTR
	ADD	A,-SIO_BUFSZ-4		; SUBTRACT SIZE OF BUFFER AND POINTER
	CP	E			; IF EQUAL TO START, HEAD PTR IS PAST BUF END
	JR	NZ,SIO_INTRCV3		; IF NOT, BYPASS
	LD	H,D			; SET HL TO
	LD	L,E			; ... HEAD PTR ADR
	INC	HL			; BUMP PAST HEAD PTR
	INC	HL
	INC	HL
	INC	HL			; ... SO HL NOW HAS ADR OF ACTUAL BUFFER START
SIO_INTRCV3:
	EX	DE,HL			; DE := HEAD PTR VAL, HL := ADR OF HEAD PTR
	LD	(HL),E			; SAVE UPDATED HEAD PTR
	INC	HL
	LD	(HL),D
	; CHECK FOR MORE PENDING...
	LD	C,(IY+3)		; CMD/STAT PORT TO C
	XOR	A			; A := 0
	OUT	(C),A			; ADDRESS RD0
	IN	A,(C)			; GET RD0
	RRA				; READY BIT TO CF
	JR	C,SIO_INTRCV1		; IF SET, DO SOME MORE
SIO_INTRCV4:
	OR	$FF			; NZ SET TO INDICATE INT HANDLED
	RET				; AND RETURN
;
#ENDIF
;
; DRIVER FUNCTION TABLE
;
SIO_FNTBL:
	.DW	SIO_IN
	.DW	SIO_OUT
	.DW	SIO_IST
	.DW	SIO_OST
	.DW	SIO_INITDEV
	.DW	SIO_QUERY
	.DW	SIO_DEVICE
#IF (($ - SIO_FNTBL) != (CIO_FNCNT * 2))
	.ECHO	"*** INVALID SIO FUNCTION TABLE ***\n"
#ENDIF
;
;
;
#IF (INTMODE == 0)
;
SIO_IN:
	CALL	SIO_IST			; CHAR WAITING?
	JR	Z,SIO_IN		; LOOP IF NOT
	LD	C,(IY+4)		; DATA PORT
	IN	E,(C)			; GET CHAR
	XOR	A			; SIGNAL SUCCESS
	RET
;
#ELSE
;
SIO_IN:
	CALL	SIO_IST			; SEE IF CHAR AVAILABLE
	JR	Z,SIO_IN		; LOOP UNTIL SO
	HB_DI				; AVOID COLLISION WITH INT HANDLER
	LD	L,(IY+7)		; SET HL TO
	LD	H,(IY+8)		; ... START OF BUFFER STRUCT
	LD	A,(HL)			; GET COUNT
	DEC	A			; DECREMENT COUNT
	LD	(HL),A			; SAVE UPDATED COUNT
	CP	SIO_BUFSZ / 4		; BUFFER LOW THRESHOLD
	JR	NZ,SIO_IN1		; IF NOT, BYPASS SETTING RTS
	LD	C,(IY+3)		; C IS CMD/STATUS PORT ADR
	LD	A,5			; RTS IS IN WR5
	OUT	(C),A			; ADDRESS WR5
	LD	A,SIO_RTSON		; VALUE TO SET RTS
	OUT	(C),A			; DO IT
SIO_IN1:
	INC	HL
	INC	HL
	INC	HL			; HL NOW HAS ADR OF TAIL PTR
	PUSH	HL			; SAVE ADR OF TAIL PTR
	LD	A,(HL)			; DEREFERENCE HL
	INC	HL
	LD	H,(HL)
	LD	L,A			; HL IS NOW ACTUAL TAIL PTR
	LD	C,(HL)			; C := CHAR TO BE RETURNED
	INC	HL			; BUMP TAIL PTR
	POP	DE			; RECOVER ADR OF TAIL PTR
	LD	A,L			; GET LOW BYTE OF TAIL PTR
	ADD	A,-SIO_BUFSZ-2		; SUBTRACT SIZE OF BUFFER AND POINTER
	CP	E			; IF EQUAL TO START, TAIL PTR IS PAST BUF END
	JR	NZ,SIO_IN2		; IF NOT, BYPASS
	LD	H,D			; SET HL TO
	LD	L,E			; ... TAIL PTR ADR
	INC	HL			; BUMP PAST TAIL PTR
	INC	HL			; ... SO HL NOW HAS ADR OF ACTUAL BUFFER START
SIO_IN2:
	EX	DE,HL			; DE := TAIL PTR VAL, HL := ADR OF TAIL PTR
	LD	(HL),E			; SAVE UPDATED TAIL PTR
	INC	HL
	LD	(HL),D
	LD	E,C			; MOVE CHAR TO RETURN TO E
	HB_EI				; INTERRUPTS OK AGAIN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
#ENDIF
;
;
;
SIO_OUT:
	CALL	SIO_OST			; READY FOR CHAR?
	JR	Z,SIO_OUT		; LOOP IF NOT
	LD	C,(IY+4)		; DATA PORT
	OUT	(C),E			; SEND CHAR FROM E
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
#IF (INTMODE == 0)
;
SIO_IST:
	LD	C,(IY+3)		; CMD PORT
	XOR	A			; WR0
	OUT	(C),A			; DO IT
	IN	A,(C)			; GET STATUS
	AND	$01			; ISOLATE BIT 0 (RX READY)
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ASCCUM := 1 TO SIGNAL 1 CHAR WAITING
	RET				; DONE
;
#ELSE
;
SIO_IST:
	LD	L,(IY+7)		; GET ADDRESS
	LD	H,(IY+8)		; ... OF RECEIVE BUFFER
	LD	A,(HL)			; BUFFER UTILIZATION COUNT
	OR	A			; SET FLAGS
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	RET
;
#ENDIF
;
;
;
SIO_OST:
	LD	C,(IY+3)		; CMD PORT
	XOR	A			; WR0
	OUT	(C),A			; DO IT
	IN	A,(C)			; GET STATUS
	AND	$04			; ISOLATE BIT 2 (TX EMPTY)
	JP	Z,CIO_IDLE		; NOT READY, RETURN VIA IDLE PROCESSING
	XOR	A			; ZERO ACCUM
	INC	A			; ACCUM := 1 TO SIGNAL 1 BUFFER POSITION
	RET				; DONE
;
; AT INITIALIZATION THE SETUP PARAMETER WORD IS TRANSLATED TO THE FORMAT 
; REQUIRED BY THE SIO AND STORED IN A PORT/REGISTER INITIALIZATION TABLE, 
; WHICH IS THEN LOADED INTO THE SIO.
;
; RTS, DTR AND XON SETTING IS NOT CURRENTLY SUPPORTED.
; MARK & SPACE PARITY AND 1.5 STOP BITS IS NOT SUPPORTED BY THE SIO.
; INITIALIZATION WILL NOT BE COMPLETED IF AN INVALID SETTING IS DETECTED.
;
; NOTE THAT THERE ARE TWO ENTRY POINTS.  INITDEV WILL DISABLE/ENABLE INTS
; AND INITDEVX WILL NOT.  THIS IS DONE SO THAT THE PREINIT ROUTINE ABOVE
; CAN AVOID ENABLING/DISABLING INTS.
;
SIO_INITDEV:
	HB_DI				; DISABLE INTS
	CALL	SIO_INITDEVX		; DO THE WORK
	HB_EI				; INTS BACK ON
	RET				; DONE
;
SIO_INITDEVX:
;
; THIS ENTRY POINT BYPASSES DISABLING/ENABLING INTS WHICH IS REQUIRED BY
; PREINIT ABOVE.  PREINIT IS NOT ALLOWED TO ENABLE INTS!
;
	; TEST FOR -1 WHICH MEANS USE CURRENT CONFIG (JUST REINIT)
	LD	A,D			; TEST DE FOR
	AND	E			; ... VALUE OF -1
	INC	A			; ... SO Z SET IF -1
	JR	NZ,SIO_INITDEV1	; IF DE == -1, REINIT CURRENT CONFIG
;
	; LOAD EXISTING CONFIG TO REINIT
	LD	E,(IY+5)		; LOW BYTE
	LD	D,(IY+6)		; HIGH BYTE	
;
SIO_INITDEV1:
	PUSH	DE			; SAVE CONFIG

	LD	A,D			; GET CONFIG MSB
	AND	$1F			; ISOLATE ENCODED BAUD RATE

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" ENCODE[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF
;
; ONLY FOUR BAUD RATES ARE POSSIBLE WITH A FIXED CLOCK.
; THESE ARE PREDETERMINED BY HARDWARE SETTINGS AND MATCHING
; CONFIGURATION SETTINGS. WE PRECALCULATED THE FOUR 
; POSSIBLE ENCODED VALUES.
;
	CP	SIOBAUD1		; We set the divider and the lower bit (d2) of the stop bits
	LD	D,$04			; /1 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD2	
	LD	D,$44			; /16 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD3	
	LD	D,$84			; /32 N,8,1
	JR	Z,BROK	
	CP	SIOBAUD4	
	LD	D,$C4			; /64 N,8,1
	JR	Z,BROK			
	
#IF (SIODEBUG)
	PUSH	AF
	PRTS(" BR FAIL[$")	
	CALL PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF
;
EXITINIT:
	POP	DE
	RET				; NZ status here indicating fail / invalid baud rate.
	
BROK:
	LD	A,E
	AND	$E0
	JR	NZ,EXITINIT		; NZ status here indicates dtr, xon, parity mark or space so return

	LD	A,E			;  set stop bit (d3) and add divider
	AND	$04
	RLA
	OR	D			; carry gets reset here
	LD	D,A
	
	LD	A,E			; get the parity bits
	SRL	A			; move them to bottom two bits
	SRL	A			; we know top bits are zero from previous test
	SRL	A			; add stop bits
	OR	D 			; carry = 0
;	
; SET DIVIDER, STOP AND PARITY WR4
;	
	LD	BC,SIO_INITVALS+3
	LD	(BC),A
	
#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR4[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF

	LD	A,E			; 112233445566d1d0 CC
	RRA				; CC112233445566d1 d0
	RRA				; d0CC112233445566 d1
	RRA 				; d1d0CC1122334455 66
	LD	D,A	
	RRA				; 66d1d0CC11223344 55
	AND	$60			; 0011110000000000 00
	OR	$8a
;	
; SET TRANSMIT DATA BITS WR5	
;
	LD	BC,SIO_INITVALS+11
	LD	(BC),A	

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR5[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF	
;
; SET RECEIVE DATA BITS WR3 
;	
	LD	A,D			; DATA BITS
	AND	$C0			; CLEAR OTHER BITS
	OR	$21			; CTS/DCD AUTO, RX ENABLE
	
	LD	BC,SIO_INITVALS+9
	LD	(BC),A	

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR3[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF
;
; SET INTERRUPT VECTOR OFFSET WR2
;
#IF (INTMODE == 2)
	LD	A,(IY+2)		; CHIP / CHANNEL
	SRL	A			; SHIFT AWAY CHANNEL BIT
	LD	E,IVT_SER0		; ASSUME CHIP 0
	JR	Z,SIO_IVT1		; IF SO, DO IT
	LD	E,IVT_SER1		; ASSUME CHIP 1
	DEC	A			; CHIP 1?
	JR	Z,SIO_IVT1		; IF SO, TO IT
	CALL 	PANIC			; IMPOSSIBLE SITUATION
SIO_IVT1:
	LD	A,E			; VALUE TO A
	LD	(SIO_INITVALS+7),A	; SAVE IT

#IF (SIODEBUG)
	PUSH	AF
	PRTS(" WR2[$")
	CALL	PRTHEXBYTE
	PRTC(']')
	POP	AF
#ENDIF

#ENDIF

	POP	DE			; RESTORE CONFIG

	LD	(IY+5),E		; SAVE LOW WORD
	LD	(IY+6),D		; SAVE HI WORD
;
	; PROGRAM THE SIO CHIP CHANNEL
	LD	C,(IY+3)		; COMMAND PORT
	LD	HL,SIO_INITVALS		; POINT TO INIT VALUES
	LD	B,SIO_INITLEN		; COUNT OF BYTES TO WRITE
	OTIR				; WRITE ALL VALUES
;
#IF (INTMODE > 0)
;
	; RESET THE RECEIVE BUFFER
	LD	E,(IY+7)
	LD	D,(IY+8)		; DE := _CNT
	XOR	A			; A := 0
	LD	(DE),A			; _CNT = 0
	INC	DE			; DE := ADR OF _HD
	PUSH	DE			; SAVE IT
	INC	DE
	INC	DE
	INC	DE
	INC	DE			; DE := ADR OF _BUF
	POP	HL			; HL := ADR OF _HD
	LD	(HL),E
	INC	HL
	LD	(HL),D			; _HD := _BUF
	INC	HL
	LD	(HL),E
	INC	HL
	LD	(HL),D			; _TL := _BUF
;
#ENDIF
;
	XOR	A			; SIGNAL SUCCESS
	RET				; RETURN
;
;
SIO_INITVALS:
	.DB	$00, $18		; WR0: CHANNEL RESET
	.DB	$04, $00		; WR4: CLK BAUD PARITY STOP BIT
#IF (INTMODE == 0)
	.DB	$01, $00		; WR1: NO INTERRUPTS
#ELSE
	.DB	$01, $18		; WR1: INTERRUPT ON ALL RECEIVE CHARACTERS
#ENDIF
	.DB	$02, IVT_SER0		; WR2: IM2 INTERRUPT VECTOR OFFSET
	.DB	$03, $E1		; WR3: 8 BIT RCV, CTS/DCD AUTO, RX ENABLE
	.DB	$05, SIO_RTSON		; WR5: DTR, 8 BITS SEND,  TX ENABLE, RTS 1 11 0 1 0 1 0 (1=DTR,11=8bits,0=sendbreak,1=TxEnable,0=sdlc,1=RTS,0=txcrc)
SIO_INITLEN	.EQU	$ - SIO_INITVALS
;
;
;
SIO_QUERY:
	LD	E,(IY+5)		; FIRST CONFIG BYTE TO E
	LD	D,(IY+6)		; SECOND CONFIG BYTE TO D
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
;
;
SIO_DEVICE:
	LD	D,CIODEV_SIO		; D := DEVICE TYPE
	LD	E,(IY)			; E := PHYSICAL UNIT
	LD	C,$00			; C := DEVICE TYPE, 0x00 IS RS-232
	XOR	A			; SIGNAL SUCCESS
	RET
;
; SIO CHIP PROBE
; CHECK FOR PRESENCE OF SIO CHIPS AND POPULATE THE
; SIO_MAP BITMAP (ONE BIT PER CHIP).  THIS DETECTS
; CHIPS, NOT CHANNELS.  EACH CHIP HAS 2 CHANNELS.
; MAX OF TWO CHIPS CURRENTLY.  INT VEC VALUE IS TRASHED!
;
SIO_PROBE:
	; CLEAR THE PRESENCE BITMAP
	LD	HL,SIO_MAP		; HL POINTS TO BITMAP
	XOR	A			; ZERO
	LD	(SIO_MAP),A		; CLEAR CHIP PRESENT BITMAP
	; INIT THE INT VEC REGISTER OF ALL POSSIBLE CHIPS
	; TO ZERO.  A IS STILL ZERO.
	LD	B,2			; WR2 REGISTER (INT VEC)
	LD	C,SIO0B_CMD		; FIRST CHIP
	CALL	SIO_WR			; WRITE ZERO TO CHIP REG
#IF (SIOCNT >= 2)
	LD	C,SIO1B_CMD		; SECOND CHIP
	CALL	SIO_WR			; WRITE ZERO TO CHIP REG
#ENDIF
	; FIRST POSSIBLE CHIP
	LD	C,SIO0B_CMD		; FIRST CHIP CMD/STAT PORT
	CALL	SIO_PROBECHIP		; PROBE IT
	JR	NZ,SIO_PROBE1		; IF NOT ZERO, NOT FOUND
	SET	0,(HL)			; SET BIT FOR FIRST CARD
SIO_PROBE1:
;
#IF (SIOCNT >= 2)
	LD	C,SIO1B_CMD		; SECOND CHIP CMD/STAT PORT
	CALL	SIO_PROBECHIP		; PROBE IT
	JR	NZ,SIO_PROBE2		; IF NOT ZERO, NOT FOUND
	SET	1,(HL)			; SET BIT FOR SECOND CARD
SIO_PROBE2:
#ENDIF
;
	RET
;
SIO_PROBECHIP:
	; READ WR2 TO ENSURE IT IS ZERO (AVOID PHANTOM PORTS)
	CALL	SIO_RD			; GET VALUE
	AND	$F0			; ONLY TOP NIBBLE
	RET	NZ			; ABORT IF NOT ZERO
	; WRITE INT VEC VALUE TO WR2
	LD	A,$FF			; TEST VALUE
	CALL	SIO_WR			; WRITE IT
	; READ WR2 TO CONFIRM VALUE WRITTEN
	CALL	SIO_RD			; REREAD VALUE
	AND	$F0			; ONLY TOP NIBBLE
	CP	$F0			; COMPARE
	RET				; DONE, Z IF FOUND, NZ IF MISCOMPARE
;
; READ/WRITE CHIP REGISTER.  ENTER CHIP CMD/STAT PORT ADR IN C
; AND CHIP REGISTER NUMBER IN B.  VALUE TO WRITE IN A OR VALUE
; RETURNED IN A.
;
SIO_WR:
	OUT	(C),B			; SELECT CHIP REGISTER
	OUT	(C),A			; WRITE VALUE
	RET
;
SIO_RD:
	OUT	(C),B			; SELECT CHIP REGISTER
	IN	A,(C)			; GET VALUE
	RET
;
; SIO DETECTION ROUTINE
;
SIO_DETECT:
	LD	B,(IY+2)		; GET  CHIP/CHANNEL
	SRL	B			; SHIFT AWAY THE CHANNEL BIT
	INC	B			; NUMBER OF TIMES TO ROTATE BITS
	LD	A,(SIO_MAP)		; BIT MAP IN A
SIO_DETECT1:
	; ROTATE DESIRED CHIP BIT INTO CF
	RRA				; ROTATE NEXT BIT INTO CF
	DJNZ	SIO_DETECT1		; DO THIS UNTIL WE HAVE DESIRED BIT
	; RETURN CHIP TYPE
	LD	A,SIO_NONE		; ASSUME NOTHING HERE
	RET	NC			; IF CF NOT SET, RETURN
	LD	A,SIO_SIO		; CHIP TYPE IS SIO
	RET				; DONE
;
;
;
SIO_PRTCFG:
	; ANNOUNCE PORT
	CALL	NEWLINE			; FORMATTING
	PRTS("SIO$")			; FORMATTING
	LD	A,(IY)			; DEVICE NUM
	CALL	PRTDECB			; PRINT DEVICE NUM
	PRTS(": IO=0x$")		; FORMATTING
	LD	A,(IY+3)		; GET BASE PORT
	CALL	PRTHEXBYTE		; PRINT BASE PORT

	; PRINT THE SIO TYPE
	CALL	PC_SPACE		; FORMATTING
	LD	A,(IY+1)		; GET SIO TYPE BYTE
	RLCA				; MAKE IT A WORD OFFSET
	LD	HL,SIO_TYPE_MAP		; POINT HL TO TYPE MAP TABLE
	CALL	ADDHLA			; HL := ENTRY
	LD	E,(HL)			; DEREFERENCE
	INC	HL			; ...
	LD	D,(HL)			; ... TO GET STRING POINTER
	CALL	WRITESTR		; PRINT IT
;
	; ALL DONE IF NO SIO WAS DETECTED
	LD	A,(IY+1)		; GET SIO TYPE BYTE
	OR	A			; SET FLAGS
	RET	Z			; IF ZERO, NOT PRESENT
;
	PRTS(" MODE=$")			; FORMATTING
	LD	E,(IY+5)		; LOAD CONFIG
	LD	D,(IY+6)		; ... WORD TO DE
	CALL	PS_PRTSC0		; PRINT CONFIG
;
	XOR	A
	RET
;
;
;
SIO_TYPE_MAP:
		.DW	SIO_STR_NONE
		.DW	SIO_STR_SIO

SIO_STR_NONE	.DB	"<NOT PRESENT>$"
SIO_STR_SIO	.DB	"SIO$"
;
; WORKING VARIABLES
;
SIO_DEV		.DB	0		; DEVICE NUM USED DURING INIT
SIO_MAP		.DB	0		; CHIP PRESENCE BITMAP
;
#IF (INTMODE == 0)
;
SIO0A_RCVBUF	.EQU	0
SIO0B_RCVBUF	.EQU	0
;
#IF (SIOCNT >= 2)
SIO1A_RCVBUF	.EQU	0
SIO1B_RCVBUF	.EQU	0
#ENDIF
;
#ELSE
;
; SIO0 CHANNEL A RECEIVE BUFFER
SIO0A_RCVBUF:
SIO0A_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIO0A_HD	.DW	SIO0A_BUF	; BUFFER HEAD POINTER
SIO0A_TL	.DW	SIO0A_BUF	; BUFFER TAIL POINTER
SIO0A_BUF	.FILL	SIO_BUFSZ,0	; RECEIVE RING BUFFER
;
; SIO0 CHANNEL B RECEIVE BUFFER
SIO0B_RCVBUF:
SIO0B_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIO0B_HD	.DW	SIO0B_BUF	; BUFFER HEAD POINTER
SIO0B_TL	.DW	SIO0B_BUF	; BUFFER TAIL POINTER
SIO0B_BUF	.FILL	SIO_BUFSZ,0	; RECEIVE RING BUFFER
;
#IF (SIOCNT >= 2)
;
; SIO1 CHANNEL A RECEIVE BUFFER
SIO1A_RCVBUF:
SIO1A_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIO1A_HD	.DW	SIO1A_BUF	; BUFFER HEAD POINTER
SIO1A_TL	.DW	SIO1A_BUF	; BUFFER TAIL POINTER
SIO1A_BUF	.FILL	SIO_BUFSZ,0	; RECEIVE RING BUFFER
;
; SIO1 CHANNEL B RECEIVE BUFFER
SIO1B_RCVBUF:
SIO1B_CNT	.DB	0		; CHARACTERS IN RING BUFFER
SIO1B_HD	.DW	SIO1B_BUF	; BUFFER HEAD POINTER
SIO1B_TL	.DW	SIO1B_BUF	; BUFFER TAIL POINTER
SIO1B_BUF	.FILL	SIO_BUFSZ,0	; RECEIVE RING BUFFER
;
#ENDIF
;
#ENDIF
;
; SIO PORT TABLE
;
SIO_CFG:
	; SIO0 CHANNEL A
SIO0A_CFG:
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	$00			; CHIP 0 / CHANNEL A (LOW BIT IS CHANNEL)
	.DB	SIO0A_CMD		; CMD/STATUS PORT
	.DB	SIO0A_DAT		; DATA PORT
	.DW	DEFSIO0ACFG		; LINE CONFIGURATION
	.DW	SIO0A_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
SIO_CFGSIZ	.EQU	$ - SIO_CFG	; SIZE OF ONE CFG TABLE ENTRY
;
	; SIO0 CHANNEL B
SIO0B_CFG:
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	$01			; CHIP 0 / CHANNEL B (LOW BIT IS CHANNEL)
	.DB	SIO0B_CMD		; CMD/STATUS PORT
	.DB	SIO0B_DAT		; DATA PORT
	.DW	DEFSIO0BCFG		; LINE CONFIGURATION
	.DW	SIO0B_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
#IF (SIOCNT >= 2)
;
	; SIO1 CHANNEL A
SIO1A_CFG:
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	$02			; CHIP 1 / CHANNEL A (LOW BIT IS CHANNEL)
	.DB	SIO1A_CMD		; CMD/STATUS PORT
	.DB	SIO1A_DAT		; DATA PORT
	.DW	DEFSIO1ACFG		; LINE CONFIGURATION
	.DW	SIO1A_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
	; SIO1 CHANNEL B
SIO1B_CFG:
	.DB	0			; DEVICE NUMBER (SET DURING INIT)
	.DB	0			; SIO TYPE (SET DURING INIT)
	.DB	$03			; CHIP 1 / CHANNEL B (LOW BIT IS CHANNEL)
	.DB	SIO1B_CMD		; CMD/STATUS PORT
	.DB	SIO1B_DAT		; DATA PORT
	.DW	DEFSIO1BCFG		; LINE CONFIGURATION
	.DW	SIO1B_RCVBUF		; POINTER TO RCV BUFFER STRUCT
;
#ENDIF
;
SIO_CFGCNT	.EQU	($ - SIO_CFG) / SIO_CFGSIZ

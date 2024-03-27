


TITLE	    "Comms"
SUBTITLE    "SCC369 Assessment 3 WK5-6"
    
PROCESSOR   16F1507

#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTOSC         ; Oscillator Selection bits (Internal Oscillator, I/O Function on OSC1)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable (WDT disabled)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable (PWRT disabled)
  CONFIG  MCLRE = ON            ; MCLR Pin Function Select (MCLR/VPP pin function is MCLR)
  CONFIG  CP = OFF              ; Flash Program Memory Code Protection (Program memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown-out Reset Enable (Brown-out Reset disabled)
  CONFIG  CLKOUTEN = OFF        ; Clock Out Enable (CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin)

; CONFIG2
  CONFIG  WRT = OFF             ; Flash Memory Self-Write Protection (Write protection off)
  CONFIG  STVREN = ON           ; Stack Overflow/Underflow Reset Enable (Stack Overflow or Underflow will cause a Reset)
  CONFIG  BORV = LO             ; Brown-out Reset Voltage Selection (Brown-out Reset Voltage (Vbor), low trip point selected.)
  CONFIG  LPBOR = OFF           ; Low-Power Brown Out Reset (Low-Power BOR is disabled)
  CONFIG  LVP = ON              ; Low-Voltage Programming Enable (Low-voltage programming enabled)

  
MOVLF MACRO LITERAL, REG
 MOVLW LITERAL
 MOVWF REG MOD 0x80
 ENDM

MOVFF	MACRO REG1, REG2
 MOVF	REG1, W
 MOVWF	REG2
 ENDM
  
PSECT udata_bank0
GLOBAL	TEMP
GLOBAL	BUFFER
GLOBAL	BUFFER2
GLOBAL	BUFFER3
GLOBAL	COUNTER
GLOBAL	COUNTER2
GLOBAL	I2C_STATUS

 GLOBAL COUNT_INNER  ;	Make variable global and thus visible in symbol table
GLOBAL COUNT_OUTER
COUNT_INNER: DS	1
COUNT_OUTER: DS	1
 
TEMP:		DS  1
BUFFER:		DS  1
BUFFER2:	DS  1
BUFFER3:	DS  1
COUNTER:	DS  1
COUNTER2:	DS  1
I2C_STATUS:	DS  1
  
;Instruction opcodes are 14 bits wide on this midline device (PIC16F1507).
  
;delta=2 flag indicates that 2 bytes reside at each address in memory space.

;Specify psect position for linker: 
  ; 1. Go to File>Project Properties> pic-as Global options> pic-as Linker in the IDE
  ; 2. Click on 'Custom Linker Options' > '...' and add the line below (excluding the ';')
;    -Pres_vect=0h     
  
PSECT res_vect, class=CODE, delta=2
res_vect:
    goto MAIN
;===================;    
    
;Specify psect position for linker: 
;    -Pint_vect=4h 
PSECT int_vect, class=CODE, delta=2 
int_vect:
    goto ISR
;===================;    
    
;the program psect is positioned automatically and so no corresponding linker entry is needed 
PSECT program, class=CODE, delta=2
;main program here
MAIN:
    BANKSEL ANSELC	;   Could use MOVLB 3 to move to Bank 3
    CLRF    ANSELC	;   Ensure configured for digital I/O (disable ADC)
    CLRF    ANSELB	;   Ensure configured for digital I/O (disable ADC)
    BANKSEL TRISC	;   Could use MOVLB 1 to move to Bank 1
    CLRF    TRISC	;   PORTC all outputs
    MOVLF   0XFF, TRISB
    BANKSEL WPUB
    MOVLF   0XFF, WPUB
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    BANKSEL PORTC
    CLRF    PORTC
;    GOTO    TASK
;    CALL BAD
MY_LOOP:
;    CALL BLINK
    CALL TASK
    CALL DISPLAY
    CALL DELAY
    GOTO MY_LOOP
DISPLAY:
;    MOVLW   11000011B
;    ANDWF   PORTC, F
;    MOVLW   00111100B
;    ANDWF   BUFFER
    MOVFF   BUFFER2, PORTC
    RETURN
   
; =======================================
;   SUBR    DELAY
;   PARAM   None
;   RETURN  None
;   WRITES  W, COUNT_INNER, COUNT_OUTER
;
;   DESCR   Long delay using nested loop
;
;   CONFIG  bDlyLpCount	# Byte 0..255: Number of iterations for outer loop
;   CALLS   None
; =======================================
DELAY:
    MOVLW   50		;   Reset outer loop count
    MOVWF   COUNT_OUTER

DL_OUTER:
    MOVLW   0xFF		;   Reset inner loop count
    MOVWF   COUNT_INNER

DL_INNER:
    DECFSZ  COUNT_INNER, F	;   Break inner loop if zero
    GOTO    DL_INNER

    DECFSZ  COUNT_OUTER, F	;   Break outer loop if zero
    GOTO    DL_OUTER

    RETURN
    
I2C_DELAY:
    NOP
    NOP
    RETURN
    
I2C_START:
    ; To keep the SCL and SDA high as normal
    BSF	    PORTC, 7
    CALL    I2C_DELAY
    BSF	    PORTC, 6
    CALL    I2C_DELAY
    
    ; Pull down SDA then SCL to start a transmition
    BCF	    PORTC, 7
    CALL    I2C_DELAY
    BCF	    PORTC, 6
    CALL    I2C_DELAY
    
    RETURN
    
I2C_STOP:
    BCF	    PORTC, 7
    CALL    I2C_DELAY
    BSF	    PORTC, 6
    CALL    I2C_DELAY
    BSF	    PORTC, 7
    CALL    I2C_DELAY
    
    RETURN
    
;===============================================================================
; The function(subroutine) is to make transferring a byte  
;   
; Parameters: the transferring byte needs to be saved in register BUFFER
;   
; Return: ACK bit will be saved in bit 0 of I2C_STATUS
;
; The I2C connection needs to be established before. 
; I2C_TX_LOOP is the looping block for sending each bit. After left shift, 
; put the overflow bit to I2C_SDA port. Finally, toggle the I2C_SCL clock bit. 
;===============================================================================
I2C_TX:
    BANKSEL TRISC
    CLRF    TRISC		    ; Change the I2C_SDA pin to be output mode
    BANKSEL COUNTER
    MOVLF   0X08, COUNTER	    ; Set a counter at 8 for 8-bit-transferring
    MOVLF   0XFF, COUNTER2	    ; Set a counter for waiting ack
    MOVFF   BUFFER, TEMP	    ; Copy the buffer to a temp register 
I2C_TX_LOOP:
    LSLF    TEMP, F		    ; Left shift the highest bit
IF_STATUS_C:
    BTFSS   STATUS, 0		    ; Put the overflow bit to SDA
    GOTO    CLR_SDA
    GOTO    SET_SDA
CLR_SDA:
    BCF	    PORTC, 7
    GOTO    I2C_TX_ENDIF
SET_SDA:
    BSF	    PORTC, 7
    GOTO    I2C_TX_ENDIF
I2C_TX_ENDIF:
    BSF	    PORTC, 6		    ; Set the I2C_SCL to enable the new transferring bit
    CALL    I2C_DELAY
    BCF	    PORTC, 6		    ; Clear the I2C_SCL to enable the new transferring bit
    CALL    I2C_DELAY
    DECFSZ  COUNTER, F		    ; Self-decrement of 8-bit-transferring counter
    GOTO    I2C_TX_LOOP		    ; If the counter is not zero, loop to the next bit transferring
    BSF	    PORTC, 7		    ; Set the I2C_SDA bit and wait for the ACK signal from slave
    BCF	    I2C_STATUS, 0	    ; For the returning ACK bit
    BANKSEL TRISC
    BSF	    TRISC, 7		    ; Change the I2C_SDA pin to be input mode for waiting ACK
    CALL    I2C_DELAY
    BANKSEL PORTC
    BSF	    PORTC, 6
    CALL    I2C_DELAY
    BTFSS   PORTC, 7		    ; Check the I2C_SDA pin
    RETURN			    ; If clear, return and finish the subroutine. All bits are transferring successfully
    BSF	    I2C_STATUS, 0	    ; If set, set the first bit of I2C_STATUS as a returning ACK bit
    RETURN			    ; Return and finish the subroutine
    
I2C_RX:
    BANKSEL TRISC
    BSF	    TRISC, 7
    BANKSEL COUNTER
    MOVLF   0X08, COUNTER
I2C_RX_LOOP:
    BSF	    PORTC, 6
    CALL    I2C_DELAY
IF_SDA:
    BTFSS   PORTC, 7
    GOTO    SDA_CLR
    GOTO    SDA_SET
SDA_CLR:
    LSLF    BUFFER, F
    BCF	    BUFFER, 0
    GOTO    I2C_RX_ENDIF
SDA_SET:
    LSLF    BUFFER, F
    BSF	    BUFFER, 0
    GOTO    I2C_RX_ENDIF
I2C_RX_ENDIF:
    BCF	    PORTC, 6
    DECFSZ  COUNTER, F
    GOTO    I2C_RX_LOOP
    BANKSEL TRISC
    BCF	    TRISC, 7
    BANKSEL PORTC
IF_I2C_STATUS:
    BTFSS   I2C_STATUS, 0
    GOTO    STATUS_CLEAR
    GOTO    STATUS_SET
STATUS_CLEAR:
    BCF	    PORTC, 7
    BSF	    PORTC, 6
    CALL    I2C_DELAY
    BCF	    PORTC, 6
    RETURN
STATUS_SET:
    BSF	    PORTC, 7
    BSF	    PORTC, 7
    CALL    I2C_DELAY
    BCF	    PORTC, 6
    RETURN
    
TASK:
    BANKSEL BUFFER
    CALL    I2C_START
    CALL    I2C_DELAY
    MOVLF   10010001B, BUFFER
    CALL    I2C_TX
    BANKSEL TRISC
    BCF	    TRISC, 7
    BANKSEL PORTC
    BCF	    PORTC, 6	
    BTFSC   I2C_STATUS, 0
    GOTO    RESET_I2C
    BCF	    I2C_STATUS, 0
    CALL    I2C_RX
    MOVFF   BUFFER, BUFFER2
    BSF	    I2C_STATUS, 0
    CALL    I2C_RX
    MOVFF   BUFFER, BUFFER3
 RETURN
RESET_I2C:
    BCF	    PORTC, 7
    CALL    DELAY
    CALL    BLINK
    GOTO    TASK
ISR:
    RETFIE
    
BLINK:
    BSF	PORTC, 2
    CALL DELAY
    BCF	PORTC, 2
    CALL DELAY
    RETURN

BAD:
    CALL BLINK
    GOTO BAD
    
END
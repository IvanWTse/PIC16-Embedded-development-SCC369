


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

SUBLF	MACRO LITERAL, REG, DEST
 MOVLW	LITERAL
 SUBWF	REG, DEST
 ENDM
  
PSECT udata_bank0
GLOBAL	TEMP
GLOBAL	BUFFER
GLOBAL	BUFFER2
GLOBAL	BUFFER3
GLOBAL	COUNTER
GLOBAL	I2C_STATUS
GLOBAL	FRAMEBUFFER
GLOBAL	COUNT_INNER
GLOBAL	COUNT_OUTER
GLOBAL	HIGHEST
GLOBAL	LOWEST
 
TEMP:		DS  1
BUFFER:		DS  1
BUFFER2:	DS  1
BUFFER3:	DS  1
COUNTER:	DS  1
I2C_STATUS:	DS  1
FRAMEBUFFER:	DS  1
COUNT_INNER:	DS  1
COUNT_OUTER:	DS  1
HIGHEST:	DS  1
LOWEST:		DS  1
  
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
LOOP:
    CALL    TASK1
    GOTO    LOOP
    
;===============================================================================
; This subroutine is for display bit 2-5 of framebuffer to PORTC. 
; In this setup, there are only four bits for output. Bit 6-7 is for I2C. 
; Therefore, this function is to put a mask of FRAMEBUFFER and try not to modity
; those I2C pins. 
;===============================================================================
DISPLAY:
    MOVLW   11000011B
    ANDWF   PORTC, F
    MOVF    FRAMEBUFFER, W
    ANDLW   00111100B
    IORWF   PORTC, F
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
    
 I2C_RESET:
    BCF	    PORTC, 7
    MOVLF   0X50, COUNT_OUTER
    CALL    DELAY
    GOTO    TASK1
    
;===============================================================================
; The function(subroutine) is to make transferring a byte  
;   
; Parameter: the transferring byte needs to be saved in register BUFFER
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
    BCF	    I2C_STATUS, 0	    ; Assuming the returning is an ACK. In the later ACK checking, if it's NACK, set it later
    BANKSEL TRISC
    BSF	    TRISC, 7		    ; Change the I2C_SDA pin to be input mode for waiting ACK
    CALL    I2C_DELAY
    BANKSEL PORTC
    BSF	    PORTC, 6		    ; Rise the I2C_SCL bit for waiting ACK
    CALL    I2C_DELAY
    BTFSC   PORTC, 7		    ; Check the I2C_SDA pin
    BSF	    I2C_STATUS, 0	    ; If set, set the first bit of I2C_STATUS as a returning ACK bit
    BANKSEL TRISC		    ; Otherwise, change the PC7 to output mode, then finish and return this subroutine
    BCF	    TRISC, 7
    BANKSEL PORTC
    RETURN
    
;===============================================================================
; The function(subroutine) is to receive a coming byte  
;   
; Parameter: the ACK bit needs to be saved in bit 0 of I2C_STATUS
;   
; Return: The coming byte will be saved in register BUFFER
;
; The I2C connection needs to be established before. 
; I2C_RX_LOOP is the looping block for receiving each bit. 
; Finally, send the ACK bit. 
;===============================================================================
I2C_RX:
    BANKSEL TRISC
    BSF	    TRISC, 7		    ; Set PORTC7 to input mode
    BANKSEL COUNTER
    MOVLF   0X08, COUNTER	    ; Set a 8-time countdown counter for receiving 8 bits
I2C_RX_LOOP:
    BSF	    PORTC, 6		    ; Rise I2C_CLK pin for receiving one bit
    CALL    I2C_DELAY
    LSLF    BUFFER, F		    ; Left shift one bit for placing one coming bit
IF_SDA:				    ; Move the coming bit in I2C_SDA pin to last bit of BUFFER
    BTFSS   PORTC, 7
    GOTO    SDA_CLR
    GOTO    SDA_SET
SDA_CLR:
    BCF	    BUFFER, 0
    GOTO    I2C_RX_ENDIF
SDA_SET:
    BSF	    BUFFER, 0
    GOTO    I2C_RX_ENDIF
I2C_RX_ENDIF:
    BCF	    PORTC, 6		    ; Reset I2C_SCL pin to finish receiving this bit
    DECFSZ  COUNTER, F		    ; Check if 8-time countdown is end
    GOTO    I2C_RX_LOOP		    ; If false, self decrement one and loop to receive the next bit
    BANKSEL TRISC		    ; If true, set the PORTC7 back to output mode to sned to the ACK bit
    BCF	    TRISC, 7
    BANKSEL PORTC
IF_I2C_STATUS:			    ; Send the bit 0 of I2C_STATUS to I2C_SDA pin
    BTFSS   I2C_STATUS, 0
    GOTO    STATUS_CLEAR
    GOTO    STATUS_SET
STATUS_CLEAR:
    BCF	    PORTC, 7
    BSF	    PORTC, 6		    ; Rise the I2C_SCL pin for transferring the ACK bit
    CALL    I2C_DELAY
    BCF	    PORTC, 6		    ; Reset the I2C_SCL pin for finish transferring the ACK bit
    RETURN
STATUS_SET:
    BSF	    PORTC, 7
    BSF	    PORTC, 6		    ; Rise the I2C_SCL pin for transferring the ACK bit
    CALL    I2C_DELAY
    BCF	    PORTC, 6		    ; Reset the I2C_SCL pin for finish transferring the ACK bit
    RETURN
 
TEST:
    CALL    READ_TEMPERTURE
    LSLF    BUFFER2, F
    LSLF    BUFFER2, F
    MOVFF   BUFFER2, FRAMEBUFFER
    CALL    DISPLAY
    RETURN
    
;===============================================================================
; Task1. A function. Call it by CALL, and loop outside
;===============================================================================
TASK1:
    CALL    READ_TEMPERTURE
    MOVLF   0X28, COUNT_OUTER
;===============================================================================
; The function(subroutine) is to show temperatures with combinations of LEDs.   
;   
; Parameter: the temperature needs to be saved in BUFFER2
;===============================================================================
SHOW_TEMP:    
;    SUBLF   0X0F, BUFFER2, 0
    MOVLW   0X0F
    SUBWF   BUFFER2, 0
    BTFSC   STATUS, 2
    GOTO    G1
    BTFSS   STATUS, 0
    GOTO    T15
    
    SUBLF   0X14, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    G1Y1
    BTFSS   STATUS, 0
    GOTO    G1
    
    SUBLF   0X19, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    Y1
    BTFSS   STATUS, 0
    GOTO    G1Y1
    
    SUBLF   0X1E, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    Y1O1
    BTFSS   STATUS, 0
    GOTO    Y1
    
    SUBLF   0X23, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    O1
    BTFSS   STATUS, 0
    GOTO    Y1O1
    
    SUBLF   0X25, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    O1R1
    BTFSS   STATUS, 0
    GOTO    O1
    
    SUBLF   0X27, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    R1
    BTFSS   STATUS, 0
    GOTO    O1R1 
    
    SUBLF   0X28, BUFFER2, W
    BTFSC   STATUS, 2
    GOTO    T40
    BTFSS   STATUS, 0
    GOTO    R1
    GOTO    T40
T15:
;    CALL    DEBUG
    MOVLF   0X14, COUNT_OUTER
    BSF	    PORTC, 2
    CALL    DELAY
    BCF	    PORTC, 2
    CALL    DELAY
    MOVLF   0X28, COUNT_OUTER
    RETURN
    
G1:
    BSF	    PORTC, 2
    CALL    DELAY
    RETURN

G1Y1:
    BSF	    PORTC, 2
    BSF	    PORTC, 3
    CALL    DELAY
    RETURN
    
Y1:
    BSF	    PORTC, 3
    CALL    DELAY
    RETURN
    
Y1O1:
    BSF	    PORTC, 3
    BSF	    PORTC, 4
    CALL    DELAY
    RETURN

O1:
    BSF	    PORTC, 4
    CALL    DELAY
    RETURN
 
O1R1:
    BSF	    PORTC, 4
    BSF	    PORTC, 5
    CALL    DELAY
    RETURN
    
R1:
    BSF	    PORTC, 5
    CALL    DELAY
    RETURN
    
T40:
    MOVLF   0X14, COUNT_OUTER
    BSF	    PORTC, 5
    CALL    DELAY
    BCF	    PORTC, 5
    CALL    DELAY
    MOVLF   0X28, COUNT_OUTER
    RETURN
    
;===============================================================================
; Task2. A subroutine. Call it by GOTO, and it will self looping
;===============================================================================
TASK2:
    CALL    READ_TEMPERTURE
    MOVFF   BUFFER2, HIGHEST
    MOVFF   BUFFER2, LOWEST
    MOVLF   0X28, COUNT_OUTER
TASK2_LOOP:
    CALL    READ_TEMPERTURE	    ; Get the current temperature
    
    MOVF    BUFFER2, W
    SUBWF   HIGHEST, W		    ; W = HIGHEST - BUFFER2
    BTFSS   STAUS, 0		    ; Check STATUS.CARRY
    CALL    MOVB22H		    ; if clear, means value in BUFFER2 is greater than value in HIGHEST
    
    MOVF    BUFFER2, W
    SUBWF   LOWEST, W		    ; W = LOWEST - BUFFER2
    BTFSC   STATUS, 0		    ; Check STATUS.CARRY
    CALL    MOVB22L		    ; if set, means value in BUFFER2 is smaller than value in LOWEST
    
    CALL    SHOW_TEMP
    GOTO    TASK2_LOOP
    
MOVB22H:
    MOVFF   BUFFER2, HIGHEST
    RETURN
    
MOVB22L:
    MOVFF   BUFFER2, LOWEST
    RETURN
    
TASK3:
    BANKSEL TMR1H
    MOVLF   0X0B, TMR1H
    MOVLF   0XDC, TMR1L
    MOVLF   0X21, T1CON		    ; Set the internal instruction clock and 1:4 prescaler
    BSF	    INTCON, 7
    BSF	    INTCON, 6
    BANKSEL PIE1
    BSF	    PIE1, 0
    BANKSEL PORTC
    
;===============================================================================
; This function will automatically establish an I2C connection and read current
; temperture in 2-byte 8-exponential float number. Higher byte will be saved in
; BUFFER2, and the lower byte will be saved in BUFFER. 
;===============================================================================
READ_TEMPERTURE:
    BANKSEL BUFFER
    CALL    I2C_START
    MOVLF   10010001B, BUFFER
    CALL    I2C_TX
    BTFSC   I2C_STATUS, 0
    GOTO    I2C_RESET
    BCF	    I2C_STATUS, 0
    CALL    I2C_RX
    MOVFF   BUFFER, BUFFER2
    BSF	    I2C_STATUS, 0
    CALL    I2C_RX
    CALL    I2C_STOP
    RETURN
    
DEBUG:
    MOVLF   0X10, COUNT_OUTER
    BSF	    PORTC, 2
    BSF	    PORTC, 5
    CALL    DELAY
    BCF	    PORTC, 2
    BCF	    PORTC, 5
    CALL    DELAY
    BSF	    PORTC, 2
    BSF	    PORTC, 5
    CALL    DELAY
    BCF	    PORTC, 2
    BCF	    PORTC, 5
    CALL    DELAY
    MOVLF   0XA3, COUNT_OUTER
    
    CALL    READ_TEMPERTURE
    LSLF    BUFFER2, F
    LSLF    BUFFER2, F
    MOVFF   BUFFER2, FRAMEBUFFER
    CALL    DISPLAY
    CALL    DELAY
    
    CALL    READ_TEMPERTURE
    LSLF    BUFFER2, F
    LSLF    BUFFER2, F
    MOVFF   BUFFER2, FRAMEBUFFER
    CALL    DISPLAY
    CALL    DELAY
        
    CALL    READ_TEMPERTURE
    LSLF    BUFFER2, F
    LSLF    BUFFER2, F
    MOVFF   BUFFER2, FRAMEBUFFER
    CALL    DISPLAY
    CALL    DELAY
    RETURN
    
ISR:
    RETFIE
    
END
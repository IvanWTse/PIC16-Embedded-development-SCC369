


TITLE	    "The Intruder Alarm"
SUBTITLE    "SCC369 Assessment Wk9 Mini-Project"
    
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
 MOVWF REG mod 0x80
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
 GLOBAL	COUNT_INNER
 GLOBAL	COUNT_OUTER
 GLOBAL	R3_COUNTER
 GLOBAL	R4_STATUS
 GLOBAL	R4_STAGE
 GLOBAL	R4_BEEP_COUNTER
 GLOBAL	SLEEPCOUNTER_OUTER
 GLOBAL	SLEEPCOUNTER_INNER
 GLOBAL	SLEEP_STATUS
 
    TEMP:		DS  1
    COUNT_INNER:	DS  1
    COUNT_OUTER:	DS  1
    R3_COUNTER:		DS  1
    R4_STATUS:		DS  1
    R4_STAGE:		DS  1
    R4_BEEP_COUNTER:	DS  1
    SLEEPCOUNTER_OUTER:	DS  1
    SLEEPCOUNTER_INNER:	DS  1
    SLEEP_STATUS:	DS  1
  
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
    BANKSEL ANSELC		    ;   Could use MOVLB 3 to move to Bank 3
    CLRF    ANSELC		    ;   Ensure configured for digital I/O (disable ADC)
    CLRF    ANSELB		    ;   Ensure configured for digital I/O (disable ADC)
    BANKSEL TRISC		    ;   Could use MOVLB 1 to move to Bank 1
    CLRF    TRISC		    ;   PORTC all outputs
    MOVLF   0XFF, TRISB		    ;   PORTB all inputs
    BANKSEL WPUB
    MOVLF   0XFF, WPUB		    ;   Enable all internal weak pull-up of PORTB
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    
    ; PWM1 and TIMER1 configuration
    BANKSEL PIR1		    ; Clear the timer2 flag
    BCF	    PIR1, 1
    BANKSEL T2CON		    ; Set the timer2 prescaler to 1:1
    BCF	    T2CON, 0
    BCF	    T2CON, 1
    MOVLF   0X15, T1CON		    ; Set TIMER1 prescaler to 1:2 and enable TIMER1
    BANKSEL PIE1
    BCF	    PIE1, 0		    ; Disable TIMER1
    BANKSEL PWM1CON		    ; Get timer2 ready for output PWM
    MOVLF   0XE0, PWM1CON	    ; Configure PWM output
    
    ; Low-power Sleep configur
    BANKSEL VREGCON
    BSF	    VREGCON, 1
    
    ; IOC configuration
    BANKSEL INTCON
    MOVLF   0XC8, INTCON	    ; Set GIE, PEIE and IOCIE. Clear others
    BANKSEL IOCBN
    MOVLF   0X70, IOCBN		    ; IOC listening for PORTB.456 at negative
    MOVLF   0X40, IOCBP		    ; IOC listening for PORTB.6 at positive which is the sensor
    BANKSEL PORTC
    CLRF    PORTC
    CLRF    SLEEP_STATUS
LOOP:
    BCF	    SLEEP_STATUS, 7
    CALL    SLEEPING_DELAY
    BANKSEL PORTC
    BSF	    PORTC, 6
; Check SLEEP_STATUS.0&SLEEP_STATUS.7. No sleeping if the result is set
IF_SLEEP_GRANTED:
    SUBLF   0X00, SLEEP_STATUS, W
    BTFSS   STATUS, 2
    GOTO    NO_SLEEP_ALLOWED
    GOTO    GO_SLEEP
;    BTFSC   SLEEP_STATUS, 0	    ; Check if it is granted to sleep
;    GOTO    NO_SLEEP_ALLOWED	    ; If SLEEP_STATUS.0 is set(yes), no sleeping and loop back
;    BTFSC   SLEEP_STATUS, 7	    ; Check whether interrupt during SLEEPING_DELAY
;    GOTO    NO_SLEEP_ALLOWED	    ; If SLEEP_STATUS.7 is set(yes), no sleeping and loop back
;    GOTO    GO_SLEEP		    ; Otherwise, go to sleep and keep the Sleep LED on
GO_SLEEP:
    SLEEP
NO_SLEEP_ALLOWED:
    BCF	    PORTC, 6
    GOTO    LOOP
    
PLAY1KHZ:
    BANKSEL PR2
    MOVLF   0X7C, PR2		    ; Configure Timer2 duty cycle
    BANKSEL PWM1DCH
    MOVLF   0X3E, PWM1DCH	    ; Configure Timer2 freq
    MOVLF   0X80, PWM1DCL
    BANKSEL T2CON		    ; Set the TIMER2 prescaler to 1:1
    MOVLW   0XFC
    ANDWF   T2CON, F
    BSF	    T2CON, 2		    ; Enable Timer2
    BANKSEL PORTC
    BSF	    SLEEP_STATUS, 0	    ; Set SLEEP_STATUS.0 to not allow sleeping
    RETURN
    
PLAY500HZ:
    BANKSEL PR2
    MOVLF   0XF9, PR2		    ; Configure Timer2 duty cycle
    BANKSEL PWM1DCH
    MOVLF   0X7D, PWM1DCH	    ; Configure Timer2 freq
    MOVLF   0X00, PWM1DCL
    BANKSEL T2CON		    ; Set the TIMER2 prescaler to 1:1
    MOVLW   0XFC
    ANDWF   T2CON, F
    BSF	    T2CON, 2		    ; Enable Timer2
    BANKSEL PORTC
    BSF	    SLEEP_STATUS, 0	    ; Set SLEEP_STATUS.0 to not allow sleeping
    RETURN
    
PLAY250HZ:
    BANKSEL PR2
    MOVLF   0X7C, PR2		    ; Configure Timer2 duty cycle
    BANKSEL PWM1DCH
    MOVLF   0X3E, PWM1DCH	    ; Configure Timer2 freq
    MOVLF   0X80, PWM1DCL
    BANKSEL T2CON		    ; Set TIMER2 prescaler to 1:4
    BSF	    T2CON, 0
    BCF	    T2CON, 1
    BSF	    T2CON, 2
    BANKSEL PORTC
    BSF	    SLEEP_STATUS, 0	    ; Set SLEEP_STATUS.0 to not allow sleeping
    RETURN
    
STOP_PLAYING:
    BANKSEL T2CON
    BCF	    T2CON, 2		    ; Disable Timer2
    BANKSEL PORTC
    BCF	    SLEEP_STATUS, 0	    ; Set SLEEP_STATUS.0 to not allow sleeping
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
    
SLEEPING_DELAY:
    BANKSEL PORTC
    MOVLF   0XFF, SLEEPCOUNTER_OUTER
SLEEPINGDL_OUTER:
    MOVLW   0xFF		;   Reset inner loop count
    MOVWF   SLEEPCOUNTER_INNER

SLEEPINGDL_INNER:
    DECFSZ  SLEEPCOUNTER_INNER, F	;   Break inner loop if zero
    GOTO    SLEEPINGDL_INNER

    
    DECFSZ  SLEEPCOUNTER_OUTER, F	;   Break outer loop if zero
    GOTO    SLEEPINGDL_OUTER

    RETURN

;===============================================================================
; Go to the repective sub-ISR by different ISR flag
;===============================================================================
ISR:
    BANKSEL PORTC
    BSF	    PORTC, 7
    BANKSEL IOCBF
    BTFSC   IOCBF, 4
    GOTO    IOCB4
    BTFSC   IOCBF, 5
    GOTO    IOCB5
    BTFSC   IOCBF, 6
    GOTO    IOCB6
    BANKSEL PIR1
    BTFSC   PIR1, 0
    GOTO    ISR_TM1
    GOTO    ISR_FINALLY

IOCB4:
    CALL    STOP_PLAYING	    ; Stop any playing
    BANKSEL PIE1
    BCF	    PIE1, 0		    ; Disable timer1
    BANKSEL IOCBP		    ; Enable IOC on PB6(door sensor)
    MOVLF   0X70, IOCBN		    ; IOC listening for PORTB.456 at negative
    MOVLF   0X40, IOCBP		    ; IOC listening for PORTB.6 at positive which is the sensor
    GOTO    ISR_FINALLY
    
IOCB5:
    BANKSEL IOCBP
    BCF	    IOCBP, 6		    ; Disable IOC on PB6(door sensor)
    BCF	    IOCBN, 6
    BCF	    IOCBN, 5		    ; Disable IOC on PB5(R3 button)
    BANKSEL TMR1H
    MOVLF   0X0B, TMR1H
    MOVLF   0XDC, TMR1L
    BCF	    T1CON, 5		    ; Set TIMER1 prescaler to 1:2
    BSF	    T1CON, 4
    MOVLF   0X05, R3_COUNTER	    ; Set a countdown value 30
    CLRF    R4_STATUS
    BANKSEL PIE1
    BSF	    PIE1, 0		    ; Enable TIMER1
    GOTO    ISR_FINALLY
   
;=============================================================================== 
; Called when R3 counter is decreased to zero. It will handle the end of R3 mode. 
; This subroutine will re-enable all IOC detection and check if the door sensor
; is set to be closed. If not, trigger the alarm. 
;===============================================================================    
R3_END:
    BANKSEL PIE1
    BCF	    PIE1, 0		    ; Disable timer1
    BANKSEL IOCBP		    ; Enable IOC on PB5.6(door sensor)
    BSF	    IOCBP, 6
    BSF	    IOCBN, 6
    BSF	    IOCBN, 5
    BANKSEL PORTB
    BTFSC   PORTB, 6		    ; Check whether the door is opened
    CALL    PLAY1KHZ		    ; If true,  opened. Playing 1khz
    GOTO    ISR_FINALLY
    
IOCB6:
; R1 sub-ISR
;========================
;    BANKSEL PORTB
;    BTFSC   PORTB, 6
;    CALL    PLAY1KHZ
;    CLRF    R4_STATUS
;    GOTO    ISR_FINALLY
;========================
    
; R4 sub-ISR
;===============================================================================
    BANKSEL PORTB
    BTFSS   PORTB, 6		    ; Check whether door sensor shows opened
    GOTO    ISR_FINALLY		    ; If closed, go to end of isr
    MOVLF   0X80, R4_STATUS	    ; Otherwise, set the R4_STATUS to indicate TIMER1 later
    MOVLF   0X03, R4_STAGE	    ; At the beginning, set R4_STAGE to the first ramp
    MOVLF   0X14, R4_BEEP_COUNTER   ; At the beginning, set beep counter to 0x14(20) for counting twice per second for 10 seconds
    MOVLF   0X0B, TMR1H		    ; Configure TIMER1
    MOVLF   0XDC, TMR1L
    BCF	    T1CON, 5
    BCF	    T1CON, 4		    ; Set the TIMER1 prescaler to 1:1
    BANKSEL IOCBP
    BCF	    IOCBP, 6		    ; Disable IOC on PB6(door sensor)
    BCF	    IOCBN, 6
    BCF	    IOCBN, 5		    ; Disable IOC on PB5(R3 button)
    BANKSEL PIE1
    BSF	    PIE1, 0		    ; Enable TIMER1
    GOTO    ISR_FINALLY
;===============================================================================
    
;===============================================================================
; Go to the corresponding TIMER1 ISR depends on if it is in R4 status
;===============================================================================
ISR_TM1:
    BANKSEL R4_STATUS
    BTFSC   R4_STATUS, 7
    GOTO    ISR_TM1_R4
    GOTO    ISR_TM1_R3		    ; Go to R3 timer1 ISR if R4_STATUS.7 is not set
   
;===============================================================================
; Go to the corresponding beeping ramp by respective R4 stage
;===============================================================================
ISR_TM1_R4:
    BANKSEL IOCBN
    BCF	    IOCBN, 5		    ; Disable IOC PB5 to avoid entering R3
    BANKSEL PORTC
    SUBLF   0X03, R4_STAGE, W	    ; Compare whether R4 is in the first stage
    BTFSC   STATUS, 2
    GOTO    ISR_R4_TRIG_2HZ	    ; If true, go to the 2Hz ramp subroutine
    SUBLF   0X02, R4_STAGE, W	    ; Compare whether R4 is in the second stage
    BTFSC   STATUS, 2
    GOTO    ISR_R4_TRIG_3HZ	    ; If true, go to the 3Hz ramp subroutine
    SUBLF   0X01, R4_STAGE, W	    ; Compare whether R4 is in the third stage
    BTFSC   STATUS, 2
    GOTO    ISR_R4_TRIG_4HZ	    ; If true, go to the 4Hz ramp subroutine
    GOTO    ISR_FINALLY		    ; Leave ISR
    
;===============================================================================
; To play 1KHz sound for 0.33s when triggerred by Timer1 and check if the beeping counter goes to zero.
; If it is zero, get configuration ready to proceed to the next stage
;===============================================================================
ISR_R4_TRIG_2HZ:
    MOVLF   0X0B, TMR1H		    ; Reset the Timer1 counter for triggering every 0.5 second
    MOVLF   0XDC, TMR1L
    CALL    PLAY1KHZ		    ; Playing 1KHz sound
    MOVLF   0X31, COUNT_OUTER	    ; For 0.33s
    CALL    DELAY
    CALL    STOP_PLAYING	    ; Stop playing after 0.33s
    DECFSZ  R4_BEEP_COUNTER, F	    ; Decrement beeping counter by 1
    GOTO    ISR_FINALLY		    ; If the counter is not zero, leave ISR
    DECF    R4_STAGE, F		    ; If the counter is zero, decrement R4_STAGE to proceed to the next stage(beeping at 3Hz)
    MOVLF   0X1E, R4_BEEP_COUNTER   ; Set beep counter to 0x1E(30) for counting three times per second for 10 seconds
    BSF	    T1CON, 4		    ; Set TIMER1 prescaler 1:2
    BCF	    T1CON, 5
    MOVLF   0XAE, TMR1H		    ; Configure Timer1 to trigger every 0.33 second for the next stage
    MOVLF   0X9F, TMR1L
    GOTO    ISR_FINALLY		    ; Leave ISR
  
;===============================================================================
; To play 1KHz sound for 0.2s when triggerred by Timer1 and check if the beeping counter goes to zero.
; If it is zero, get configuration ready to proceed to the next stage
;===============================================================================
ISR_R4_TRIG_3HZ:
    CALL    PLAY1KHZ	
    MOVLF   0XAE, TMR1H
    MOVLF   0X9F, TMR1L
    MOVLF   0X20, COUNT_OUTER
    CALL    DELAY
    CALL    STOP_PLAYING
    DECFSZ  R4_BEEP_COUNTER, F
    GOTO    ISR_FINALLY
    DECF    R4_STAGE, F
    MOVLF   0X28, R4_BEEP_COUNTER
    BCF	    T1CON, 4		    ; Set TIMER1 prescaler 1:1
    BCF	    T1CON, 5
    MOVLF   0X85, TMR1H
    MOVLF   0XEE, TMR1L
    GOTO    ISR_FINALLY
    
;===============================================================================
; To play 1KHz sound for 0.15s when triggerred by Timer1 and check if the beeping counter goes to zero.
; If it is zero, get configuration ready to proceed to the next stage
;===============================================================================    
ISR_R4_TRIG_4HZ:
    CALL    PLAY1KHZ
    MOVLF   0X85, TMR1H
    MOVLF   0XEE, TMR1L
    MOVLF   0X20, COUNT_OUTER
    CALL    DELAY
    CALL    STOP_PLAYING
    DECFSZ  R4_BEEP_COUNTER, F
    GOTO    ISR_FINALLY
    DECFSZ  R4_STAGE, F		    ; If all stages have been gone, and it has still not been reset
    GOTO    ISR_FINALLY
    CALL    PLAY1KHZ		    ; Then play 1Khz sound continuously
    BANKSEL PIE1
    BCF	    PIE1, 0		    ; Disable TIMER1
    BANKSEL IOCBN
    MOVLF   0X70, IOCBN		    ; Configure IOC listening for PORTB.456 at negative
    MOVLF   0X40, IOCBP		    ; Configure IOC listening for PORTB.6 at positive which is the sensor
    GOTO    ISR_FINALLY		    ; Leave ISR
    
;===============================================================================
; Triggerred by Timer1 for R3 tasks. Play 250Hz sound for 0.2s and check whether
; it is the end of R3 by checking R3_COUNTER is zero
;===============================================================================    
ISR_TM1_R3:
    CALL    PLAY250HZ		    ; Play 250Hz sound
    MOVLF   0X20, COUNT_OUTER	    ; For a small time, at 0.2s
    CALL    DELAY
    CALL    STOP_PLAYING	    ; After a 0.2s delay, stop playing
    DECFSZ  R3_COUNTER, F	    ; Decrease R3 counter
    GOTO    ISR_FINALLY		    ; If it is not zero, leave ISR
    GOTO    R3_END		    ; If the counter is decreased to zero, it will be the end of R3, which will re-enable IOC and check whether the door sensor is closed
    
;=============================================================================== 
; The end of ISR for all sub-ISR. It will remove all interrupt flags and return
; from the interrupt to main program. 
;===============================================================================    
ISR_FINALLY:
    BANKSEL IOCBF
    CLRF    IOCBF
    BANKSEL PORTC
    BCF	    PORTC, 7
    BSF	    SLEEP_STATUS, 7
    BANKSEL PIR1
    BCF	    PIR1, 0
    RETFIE

    

    
END
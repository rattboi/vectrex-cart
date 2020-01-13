

; zero delay is needed for zeroing to work correctly
; depends on the distance of the current integrator position to actual zero point
; experiment with my vectri:
;ZERO ing the integrators takes time. Measures at my vectrex show e.g.:
;If you move the beam with a to x = -127 and y = -127 at diffferent scale values, the time to reach zero:
;- scale $ff -> zero 110 cycles
;- scale $7f -> zero 75 cycles
;- scale $40 -> zero 57 cycles
;- scale $20 -> zero 53 cycles
ZERO_DELAY_P        EQU      2                            ; delay 7 counter is exactly 111 cycles delay between zero SETTING and zero unsetting (in moveto_d)
                    jsr      DP_to_D0
FONT_LENGTH         EQU      ((font5a_line2-font5a_line1))
FONT_START_A        EQU      font5a_line1 - ' '            ; // space is 1
FONT_END            EQU      FONT_START_A+4*FONT_LENGTH

;***************************************************************************
; MY_MOVE_TO_D MACRO START
;***************************************************************************
MY_MOVE_TO_D        macro
; optimzed, tweaked not perfect... 'MOVE TO D' makro
;
;
; NOT DONE:
;
; what should be done:
; s = $ff / max(abs(a),abs(b))
; a = a * s
; b = b * s
; scaling = scaling / s
;
; that would give the most efficient positioning
; bother it takes more time to calculate the above,
; than it saves
; with every positioning via this routine now,
; it takes SCALE_FACTOR_GAME + const (of another 100+) cycles
; to do one simple positioning!!!
; that is probably about 300 cycles per positioning
; this is done about 30-40 times per round
; alone the positioning takes thus about over 10000 cycles
; and we haven't drawn a single line yet!!!
                    STA      <VIA_port_a                  ;Store Y in D/A register
                    LDA      #$CE                         ;Blank low, zero high?
                    STA      <VIA_cntl                    ;
                    CLRA
                    STA      <VIA_port_b                  ;Enable mux
                    STA      <VIA_shift_reg               ;Clear shift regigster
                    INC      <VIA_port_b                  ;Disable mux
                    STB      <VIA_port_a                  ;Store X in D/A register
                    STA      <VIA_t1_cnt_hi               ;enable timer
                    LDB      #$40                         ;
1                   BITB     <VIA_int_flags               ;
                    BEQ      1B                           ;
                    endm
;***************************************************************************
; MY_MOVE_TO_D MACRO END
;***************************************************************************

NEXT_SYNC_LINE macro
; zero
                    ldd      #(%10000010)*256+$CC                         ; zero the integrators
                    stb      <VIA_cntl                    ; store zeroing values to cntl
                    ldb      #ZERO_DELAY_P                  ; and wait for zeroing to be actually done
; reset integrators
                    clr      <VIA_port_a                  ; reset integrator offset
; wait that zeroing surely has the desired effect!
2
                    sta      <VIA_port_b                  ; while waiting, zero offsets
                    decb
                    bne      2B
                    inc      <VIA_port_b
                    ldd      ,s
                    MY_MOVE_TO_D

                    LDD      #$1883                       ;a?AUX: b?ORB: $8x = Disable RAMP, Disable Mux, mux sel = 01 (int offsets)
                    CLR      <VIA_port_a                  ;Clear D/A output
                    STA      <VIA_aux_cntl                ;Shift reg mode = 110 (shift out under system clock), T1 PB7 disabled, one shot mode
                                                          ; first entry here, ramp is disabled
                                                          ; if there was a jump from below
                                                          ; ramp will be enabled by next line
                    STB      <VIA_port_b                  ;ramp off/on set mux to channel 1
                    DEC      <VIA_port_b                  ;Enable mux
                    LDD      #$8081                       ;both to ORB, both disable ram, mux sel = 0 (y int), a:?enable mux: b:?disable mux
                    INC      <VIA_port_b                  ;Disable mux
                    STB      <VIA_port_b                  ;Disable RAMP, set mux to channel 0, disable mux
                    STA      <VIA_port_b                  ;Enable mux
                    INC      <VIA_port_b                  ;disable mux
                    LDA      Vec_Text_Width               ;Get text width
                    STA      <VIA_port_a                  ;Send it to the D/A
                    LDD      #$0100                       ;both to ORB, both ENABLE RAMP, a:? disable mux, b:? enable mux
                    LDU      Vec_Str_Ptr                  ;Point to start of text string
                    STA      <VIA_port_b                  ;[4]enable RAMP, disable mux
                    BRA      4F                           ;[3]

; one letter is drawn (one row that is) in 18 cycles
; 13 cycles overhead
; ramp is thus active for #ofLetters*18 + 13 cycles
3
                    LDA      A,X                          ;[+5]Get bitmap from chargen table
                    STA      <VIA_shift_reg               ;[+4]rasterout of char bitmap "row" thru shift out in shift register
4
                    LDA      ,U+                          ;[+6]Get next character
                    BPL      3B                      ;[+3]Go back if not terminator

                    LDA      #$81                         ;[2]disable mux, disable ramp
                    STA      <VIA_port_b                  ;[4]disable RAMP, disable mux
                    LEAX     FONT_LENGTH,X                ;[3]Point to next chargen row
                    LDA      #$98
                    STA      <VIA_aux_cntl                ;T1?PB7 enabled
                    lda      Vec_Text_Height
            		dec      0,s
                    endm

sync_Print_Str_d
; put move position on stack put it so, that we can load "d" directly from stack
 				pshs     d
                    STU      Vec_Str_Ptr                  ;Save string pointer

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; POSITION "EXACT" PATCH assuming x pos is midle alligned,
; if that is a case we can use neg x pos as "opposite" string pos
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                    ldd      #(%10000010)*256+$CC                         ; zero the integrators
                    stb      <VIA_cntl                    ; store zeroing values to cntl
                    ldb      #ZERO_DELAY_P                  ; and wait for zeroing to be actually done
; reset integrators
                    clr      <VIA_port_a                  ; reset integrator offset
           ;         lda      #%10000010
; wait that zeroing surely has the desired effect!
zeroLoop_a_2
                    sta      <VIA_port_b                  ; while waiting, zero offsets
                    decb
                    bne      zeroLoop_a_2

                    ldd      ,s
                    negb
                    MY_MOVE_TO_D
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


                    LDX      #FONT_START_A                ;Point to start of chargen bitmaps
                    NEXT_SYNC_LINE
                    NEXT_SYNC_LINE
                    NEXT_SYNC_LINE
                    NEXT_SYNC_LINE



; zero
                    ldd      #(%10000010)*256+$CC                         ; zero the integrators
                    stb      <VIA_cntl                    ; store zeroing values to cntl
                    ldb      #ZERO_DELAY_P                  ; and wait for zeroing to be actually done
; reset integrators
                    clr      <VIA_port_a                  ; reset integrator offset
; wait that zeroing surely has the desired effect!
zeroLoop_a
                    sta      <VIA_port_b                  ; while waiting, zero offsets
                    decb
                    bne      zeroLoop_a
                    inc      <VIA_port_b
                    ldd      ,s
                    MY_MOVE_TO_D

                    LDD      #$1883                       ;a?AUX: b?ORB: $8x = Disable RAMP, Disable Mux, mux sel = 01 (int offsets)
                    CLR      <VIA_port_a                  ;Clear D/A output
                    STA      <VIA_aux_cntl                ;Shift reg mode = 110 (shift out under system clock), T1 PB7 disabled, one shot mode
                                                          ; first entry here, ramp is disabled
                                                          ; if there was a jump from below
                                                          ; ramp will be enabled by next line
;LF4A5_a:
                    STB      <VIA_port_b                  ;ramp off/on set mux to channel 1
                    DEC      <VIA_port_b                  ;Enable mux
                    LDD      #$8081                       ;both to ORB, both disable ram, mux sel = 0 (y int), a:?enable mux: b:?disable mux
                    INC      <VIA_port_b                  ;Disable mux
                    STB      <VIA_port_b                  ;Disable RAMP, set mux to channel 0, disable mux
                    STA      <VIA_port_b                  ;Enable mux
                    INC      <VIA_port_b                  ;disable mux
                    LDA      Vec_Text_Width               ;Get text width
                    STA      <VIA_port_a                  ;Send it to the D/A
                    LDD      #$0100                       ;both to ORB, both ENABLE RAMP, a:? disable mux, b:? enable mux
                    LDU      Vec_Str_Ptr                  ;Point to start of text string
                    STA      <VIA_port_b                  ;[4]enable RAMP, disable mux
                    BRA      LF4CB_a                      ;[3]

; one letter is drawn (one row that is) in 18 cycles
; 13 cycles overhead
; ramp is thus active for #ofLetters*18 + 13 cycles
LF4C7_a
                    LDA      A,X                          ;[+5]Get bitmap from chargen table
                    STA      <VIA_shift_reg               ;[+4]rasterout of char bitmap "row" thru shift out in shift register
LF4CB_a
                    LDA      ,U+                          ;[+6]Get next character
                    BPL      LF4C7_a                      ;[+3]Go back if not terminator

                    LDA      #$81                         ;[2]disable mux, disable ramp
                    STA      <VIA_port_b                  ;[4]disable RAMP, disable mux

 				ldd      #$98
                    sta      <VIA_shift_reg
                    STb      <VIA_aux_cntl                ;T1?PB7 enabled
                    puls     d  ,pc                       ; all done, correct stack




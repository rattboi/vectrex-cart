; Copyright (C) 2020 Brett Walach <technobly at gmail.com>
; --------------------------------------------------------------------------
; LED TEST demo v1.1
;
; This application demonstrates how to control the addressable LEDs
; by seeding $7ff0 through $7ff9 with the LED colors, then calling
; RPC function ID 7 (updateMulti) which writes out the data to all LEDs
;
; LED Colors
; ----------
; 0 = off
; 1 = red
; 2 = orange
; 3 = yellow
; 4 = green
; 5 = cyan
; 6 = blue
; 7 = pink
; 8 = magenta
; 9 = white (Try not to use this one... it kind of draws a lot of power!)
;
; HW and SW Version
; -----------------
; Also demonstrates the Hardware and Software Version RPC function ID 9
; Which reads HW version HI:LO into $7ffc:$7fffd
;      ...and SW verison HI:LO into $7ffe:$7ffff
; This can be used to know how many LEDs are expected on the VEXTREME PCB this
; game is running on, or other info that might be useful in a programatic way.
; This app converts the values to strings to display, but the comparison would
; be much easier to check for different types of boards and software revisions.
;
; Original header follows:
; --------------------------------------------------------------------------
; Copyright (C) 2015 Jeroen Domburg <jeroen at spritesmods.com>
;
; This library is free software: you can redistribute it and/or modify
; it under the terms of the GNU Lesser General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this library.  If not, see <http://www.gnu.org/licenses/>.
;
                    include  "vectrex.i"
;***************************************************************************
; DEFINES SECTION
;***************************************************************************

;***************************************************************************
; USER RAM SECTION ($C880-$CBEA)
;***************************************************************************
user_ram            equ      $c880
logo_scale          equ      $c880
calibrationValue    equ      $c881
gameScale           equ      $c882
led_color           equ      $c883
led_color_cnt       equ      $c884
led_num             equ      $c885 ; counter to know when to switch colors (20ms * 5 = 100ms)
led_num_inv         equ      $c886 ; inverse of led_num for sound generation
led_true            equ      $c887 ; how many to light up 0 - 10
                             ; Keep next 4 addresses in order
cart_hw_ver_hi      equ      $c888 ; HW version vHI.LO saved in $7ffc
cart_hw_ver_lo      equ      $c889 ;  |                         $7ffd
cart_sw_ver_hi      equ      $c890 ; SW version vHI.LO          $7ffe
cart_sw_ver_lo      equ      $c891 ;  |                         $7fff
                             ; Keep these in order ^
hw_ver_str_ram      equ      $c892 ; reserve 9 bytes, "HW=V0.00",$80
sw_ver_str_ram      equ      #hw_ver_str_ram+9 ; reserve 9 bytes, "SW=V0.00",$80
cart_ver_check      equ      #sw_ver_str_ram+9 ; Flag to force version check once
led0_addr           equ      $7ff0 ; start address of LED0
ver_addr            equ      $7ffc ; start address of Version Info (see above)
;***************************************************************************
; SYSTEM AREA of USER RAM SECTION ($CB00-$CBEA)
;***************************************************************************
rpcfn               equ      $cb00
;***************************************************************************
; HEADER SECTION
;***************************************************************************
                    org      0
                    fcb      "g GCE 2020", $80            ; 'g' is copyright sign
                    fdb      vextreme_tune1               ; catchy intro music to get stuck in your head
                    fcb      $F6, $60, $20, -$60
                    fcb      "LED TEST V1.1",$80          ; some game information ending with $80
                    fcb      0                            ; end of game header
;***************************************************************************
; PROGRAM STARTS HERE
;***************************************************************************
main
;***************************************************************************
; RPC COPY START
;***************************************************************************
rpccopystart
                    ldx      #rpcfndat
                    ldy      #rpcfn
rpccopyloop
                    lda      ,x+
                    sta      ,y+
                    cmpx     #rpcfndatend
                    bne      rpccopyloop
;***************************************************************************
; RPC COPY END
;***************************************************************************
;***************************************************************************
; LOAD VERSION STRING TEMPLATES IN RAM
;***************************************************************************
ver_str_cpy
                    ldx      #hw_ver_string
                    ldy      #hw_ver_str_ram
ver_str_cpy_loop
                    lda      ,x+
                    sta      ,y+
                    cmpx     #sw_ver_string+9
                    bne      ver_str_cpy_loop
;***************************************************************************
; INIT VARIABLES
;***************************************************************************
init_vars
                    lda      #0
                    sta      led_color_cnt
                    lda      #1
                    sta      cart_ver_check
                    sta      led_true
                    sta      led_color
                    sta      calibrationValue
                    sta      gameScale
                    lda      #20
                    sta      logo_scale

                    lda      #0                        ; 0 disables Joy 1 X
                    sta      Vec_Joy_Mux_1_X           ;  |
                    lda      #3                        ; 3 enables Joy 1 Y
                    sta      Vec_Joy_Mux_1_Y           ;  |
                    lda      #0                        ; 0 disables Joy 2 X & Y
                    sta      Vec_Joy_Mux_2_X           ;  | saves a few hundred cycles
                    sta      Vec_Joy_Mux_2_Y           ;  |
;***************************************************************************
; CART VERSION UPDATE FUNCTION
;***************************************************************************
ver_update_start    lda      #9                        ; rpc call to check cart version saved in $7ff0 - $7ff3
                    jmp      rpcfn                     ; Call, and return to loop
;***************************************************************************
; LED UPDATE FUNCTION
;***************************************************************************
led_update_start    lda      led_true                  ; Is it time to update?
                    cmpa     #1                        ;  |
                    bne      led_update_exit           ;  No, exit LED update
                    clra                               ;  |
                    sta      led_true                  ;  Yes, clear flag and start update
; update LEDs from 0 to led_num as led_color desired, off for remainder up to 9 (10 LEDs)
led_color_start
                    clrb                               ; LED index counter
                    lda      led_color                 ; LED desired color
                    ldx      #led0_addr                ; Load start address for LED0
led_color_loop
                    cmpb     led_num                   ; Reached 0 - N LEDs yet?
                    beq      led_off_start             ;  Yes, turn off the rest
                    sta      ,x+                       ;  No, Write color to LED0 memory
                    incb                               ; inc LEDx index counter
                    bra      led_color_loop            ; Keep writing LEDx color
led_off_start
                    clra                               ; LED color that indicates OFF
led_off_loop
                    cmpb     #10                       ; Already wrote to last LED9 ?
                    beq      led_color_exit            ;  Yes, all done, exit
                    sta      ,x+                       ;  No, keep writing LEDx off color
                    incb                               ; inc LEDx index counter
                    bra      led_off_loop
led_color_exit
; cycle LED color for next time through
led_change_color_start
                    lda      led_color                 ; LED desired color
                    cmpa     #7                        ; Reached last LED color?
                    bne      led_change_color_next     ;  No, inc to next color
led_change_color_reset                                 ;
                    clra                               ;  Yes, wrap back to color 1
led_change_color_next                                  ;   |
                    inca                               ;   |
                    sta      led_color                 ; Save updated LED color
led_update
                    lda      #7                        ; rpc call to update multiple LEDs, color saved in $7ff0 - $7ff9
                    jmp      rpcfn                     ; Call
led_update_exit
;***************************************************************************
; MAIN LOOP
;***************************************************************************
loop
; Recal video stuff
                    jsr      Wait_Recal
                    jsr      Intensity_5F
;***************************************************************************
; DRAW VEXTREME LOGO
;***************************************************************************
logo_start
                    ldx      #_SM_vextreme_logo
logo_next_part
                    lda      logo_scale
                    sta      VIA_t1_cnt_lo
                    lda      #$CE
                    sta      <VIA_cntl
                    ldu      ,x++
                    beq      logo_done
                    jsr      drawSmart
                    bra      logo_next_part
logo_done
; logo zoom in animation
                    lda      logo_scale
                    cmpa     #34
                    beq      logo_zoom_done
                    inca
                    sta      logo_scale
logo_zoom_done
;***************************************************************************
; READ ANALOG JOYSTICK
;***************************************************************************
                    ldd      #$f150                    ; font settings
                    std      Vec_Text_HW               ;  |
                    lda      #$80                      ;  |
                    sta      <VIA_t1_cnt_lo            ;  |
                    clra                               ; Set the Joystick Analog resolution to max!
                    sta      Vec_Joy_Resltn            ;  |
                    jsr      DP_to_D0                  ; Ensure DP is set to D0
                    jsr      Joy_Analog                ; read joystick positions
                    ldb      Vec_Joy_1_Y               ; load joystick 1 position
                    bmi      no_y_movement             ; Bail if -Y
                    cmpb     #$3e                      ; Is outside of +Y dead-band? (0-$3e)
                    blo      no_y_movement             ;  No, bail out
                                                       ;  Yes, in active band, fall through
up_move
                    subb     #$3e                      ; Chop a bit off, but not too much so we hit full scale
                    lsrb                               ; Scale to 1-10 Divide by 6 and add 1
                    lsrb                               ;  |
                    lsrb                               ;  |
                    negb                               ; First divide by 8 and invert it
                    leau     b,u                       ; Save it away in lower U
                    negb                               ; Restore B and keep dividing to /32
                    lsrb                               ;  |
                    lsrb                               ;  |
                    negb                               ; Invert it
                    leau     b,u                       ; Effectively add /32 to /8 to get /6
                    tfr      u,d                       ; Transfer it back out of U (we only care about B)
                    negb                               ; Invert it to restore and add 1 to prevent 0
                    incb                               ;  |
                    cmpb     #10                       ; Did we calculate more than 10 LEDs?
                    blo      save_led_num              ;  No, save calculated value
                    ldb      #10                       ;  Yes, limit to 10
save_led_num                                           ;  |
                    stb      led_num                   ; Save led_num
                    ldu      #ms_ship_thrust_sound     ; VROOM!
                    jsr      make_the_misc_sound       ;  |
                    lda      led_num                   ; Load led_num into reg A
                    lsla                               ; Scale it up a bit x 4
                    lsla                               ;  |
                    ldb      #$d7                      ; a little bit left
                                                       ; use joystick Y value as Y position
                    ldu      #joypad_up_string         ; display up string
                    bra      y_done                    ; goto y done
no_y_movement
                    lda      #1                        ; reset to 1 to prevent 0
                    sta      led_num                   ;  |
                    jsr      Clear_Sound               ; Clear any sounds playing
                    ldd      #$00d0                    ; a little bit left, centered vertically
                    ldu      #no_joypad_y_string       ; display no y string
y_done
                    jsr      sync_Print_Str_d          ; using string function
;***************************************************************************
; CALCULATE AND DISPLAY VERSION INFORMATION
;***************************************************************************
; Did we just come back from RPC call to update versions?
                    lda      cart_ver_check            ; Is it time to calculate version info one time?
                    cmpa     #1                        ;  |
                    bne      display_version           ;  Already done, just display it!
                    clra                               ;  |
                    sta      cart_ver_check            ;  Yes, clear flag and load info
load_hw_ver_start   clrb                               ; HW Version info bytes index counter
                    ldx      #ver_addr                 ; Load start address for Version Info source
                    ldy      #cart_hw_ver_hi           ; Load start address for Version Info dest
load_hw_ver_loop    lda      ,x+                       ; Copy source to dest
                    sta      ,y+                       ;  |
                    incb                               ;
                    cmpb     #2                        ; Copied 2 bytes?
                    bne      load_hw_ver_loop          ;  No, get the next one
load_sw_ver_start   clrb                               ; SW Version info bytes index counter
                    ldx      #ver_addr+2               ; Load start address for Version Info source
                    ldy      #cart_sw_ver_hi           ; Load start address for Version Info dest
load_sw_ver_loop    lda      ,x+                       ; Copy source to dest
                    sta      ,y+                       ;  |
                    incb                               ;
                    cmpb     #2                        ; Copied 2 bytes?
                    bne      load_sw_ver_loop          ;  No, get the next one
; Snippets below inspired heavily by OSD @
; http://vectrexprogramming.blogspot.com/2014/11/converting-byte-value-to-ascii-in-6809_26.html
hw_hi_start                                            ;
                    ldb      cart_hw_ver_hi            ;
                    clra                               ; reg a is our 10's count
hw_hi_loop                                             ; Div10
                    inca                               ; result will be +1
                    subb     #10                       ; subtract 10 until <= 0
                    bge      hw_hi_loop                ;  |
                    ldx      #hw_ver_str_ram+4         ; load HW HI ram location
                    ; reg b = 1's count, but it is 10 less than desired result
                    addb     #48+10                    ; add ascii '0' + 10
                    stb      ,x                        ; store 1's digit
hw_lo_start                                            ;
                    ldb      cart_hw_ver_lo            ;
                    clra                               ; reg a is our 10's count
hw_lo_loop                                             ; Div10
                    inca                               ; result will be +1
                    subb     #10                       ; subtract 10 until <= 0
                    bge      hw_lo_loop                ;  |
                    adda     #48-1                     ; add ascii '0' - 1
                    ldx      #hw_ver_str_ram+6         ; load HW LO ram location
                    sta      ,x+                       ; store 10's digit
                    ; reg b = 1's count, but it is 10 less than desired result
                    addb     #48+10                    ; add ascii '0' + 10
                    stb      ,x                        ; store 1's digit
sw_hi_start                                            ;
                    ldb      cart_sw_ver_hi            ;
                    clra                               ; reg a is our 10's count
sw_hi_loop                                             ; Div10
                    inca                               ; result will be +1
                    subb     #10                       ; subtract 10 until <= 0
                    bge      sw_hi_loop                ;  |
                    ldx      #sw_ver_str_ram+4         ; load SW HI ram location
                    ; reg b = 1's count, but it is 10 less than desired result
                    addb     #48+10                    ; add ascii '0' + 10
                    stb      ,x                        ; store 1's digit
sw_lo_start                                            ;
                    ldb      cart_sw_ver_lo            ;
                    clra                               ; reg a is our 10's count
sw_lo_loop                                             ; Div10
                    inca                               ; result will be +1
                    subb     #10                       ; subtract 10 until <= 0
                    bge      sw_lo_loop                ;  |
                    adda     #48-1                     ; add ascii '0' - 1
                    ldx      #sw_ver_str_ram+6         ; load SW LO ram location
                    sta      ,x+                       ; store 10's digit
                    ; reg b = 1's count, but it is 10 less than desired result
                    addb     #48+10                    ; add ascii '0' + 10
                    stb      ,x                        ; store 1's digit
; Display version finally :D
display_version
                    ldd      #$40A0                    ; a little bit left, lower than center
                    ldu      #hw_ver_str_ram           ; display HW version string
                    jsr      sync_Print_Str_d          ; using string function
                    ldd      #$4010                    ; a little bit left, next line down
                    ldu      #sw_ver_str_ram           ; display SW version string
                    jsr      sync_Print_Str_d          ; using string function

;***************************************************************************
; LED LOGIC
;***************************************************************************
                    lda      #10                       ; Calculate inverse of led_num for sound
                    suba     led_num                   ;  |
                    sta      led_num_inv               ;  |
delay_led_update
                    lda      led_color_cnt             ; update every 100ms (20ms * 5)
                    cmpa     #5                        ;  |
                    beq      do_led_update             ;  |
                    inca                               ;  |
                    sta      led_color_cnt             ;  |
                    bra      wait_led_update           ;  |
do_led_update                                          ;  |
                    lda      #1                        ;  |
                    sta      led_true                  ;  |
                    lda      #0                        ;  |
                    sta      led_color_cnt             ;  |
;***************************************************************************
; ANY POINT IN GAME THAT WOULD RETURN TO LOOP,
; SHOULD RETURN TO led_update_start INSTEAD
;***************************************************************************
wait_led_update                                        ;  |
                    jmp      led_update_start          ;  |

;***************************************************************************
; RPC FUNCTION START
;***************************************************************************
; Rpc function. Because this makes the cart unavailable, this
; will copied to SRAM. Call as rpcfn.
rpcfndat
                    sta      $7fff
rpcwaitloop
                    lda      $0
                    cmpa     # 'g'
                    bne      rpcwaitloop
                    lda      $1
                    cmpa     # ' '
                    bne      rpcwaitloop
                    jmp      loop ;start address
rpcfndatend
;***************************************************************************
; RPC FUNCTION END
;***************************************************************************

;***************************************************************************
; SUBROUTINE SECTION
;***************************************************************************
; Mine Storm sound routine by Fred Taft (fred@hp-pcd.cv.hp.com)
; Edited by Brett Walach to make dynamic
make_the_misc_sound
                    jsr      Sound_Bytes
PED0A               ldb      $C800
                    addb     led_num_inv
                    cmpb     #$A0
                    bhs      PED1A
                    lda      #$00
                    jsr      Sound_Byte
                    bra      PED20
PED1A               ldd      #$0800
                    jsr      Sound_Byte
PED20               ldb      $C802
                    addb     led_num_inv
                    addb     led_num_inv
                    cmpb     #$F0
                    bhs      PED30
                    lda      #$02
                    jsr      Sound_Byte
                    bra      PED36
PED30               ldd      #$0900
                    jsr      Sound_Byte
PED36               rts

                    include  "printStringSync.asm"
;***************************************************************************
; DATA SECTION
;***************************************************************************
                    include  "font_5_fixed.asm"
                    include  "vextremeLogoSM.asm"
; VEXTREME Tune Notes
CS5                 equ      $1E
F5                  equ      $22
FS5                 equ      $23
GS5                 equ      $25
AS5                 equ      $27
RST                 equ      $3F
VIBENL              fcb      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
FADE14              fdb      $0000,$2DDD,$DDDD,$B000,0,0,0,0
; VEXTREME Intro Tune
vextreme_tune1
                    fdb      FADE14
                    fdb      VIBENL
                    fcb      FS5,8
                    fcb      FS5,8
                    fcb      FS5,8
                    fcb      AS5,16
                    fcb      GS5,16
                    fcb      FS5,16
                    fcb       F5,16
                    fcb      CS5,8
                    fcb      FS5,8
                    fcb      RST,8
                    fcb      0,$80 ; $80 is end marker for music, frequency is not played so 0
; Mine Storm sounds by Fred Taft (fred@hp-pcd.cv.hp.com)
ms_ship_thrust_sound
                    fcb      $00
                    fcb      $10
                    fcb      $01
                    fcb      $00
                    fcb      $06
                    fcb      $1F
                    fcb      $07
                    fcb      $06
                    fcb      $08
                    fcb      $0F
                    fcb      $FF
; Strings
no_joypad_y_string
                    fcb      "PRESS UP", $80
joypad_up_string
                    fcb      "SWOOSH!", $80
hw_ver_string
                    fcb      "HW=V0.00", $80
sw_ver_string
                    fcb      "SW=V0.00", $80
;***************************************************************************
; BA-DEEB BA-DEEB THAT'S ALL FOLKS!
;***************************************************************************

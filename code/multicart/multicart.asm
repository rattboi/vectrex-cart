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
MENU_POS_X          equ      #-110
MENU_POS_Y          equ      #50
MENU_ITEMS_MAX      equ      #4

BUTTONS_POS_X       equ      #-120
BUTTONS_POS_Y       equ      #-80
;***************************************************************************
; USER RAM SECTION ($C880-$CBEA)
;***************************************************************************
										RAM
                    ORG      $c880
user_ram
page                rmb      1
cursor              rmb      1
curpos              rmb      1
waitjs              rmb      1
lastpage            rmb      1
logo_scale          rmb      1
logo_dir            rmb      1
page_label          rmb      1
page_label_end      rmb      1
calibrationValue    rmb      1
gameScale           rmb      1
lastpagecursormax   rmb      1
cursormax           rmb      1
onlastpage          rmb      1
;***************************************************************************
; VECTREX RAM SECTION ($C800-$CFFF)
;***************************************************************************
rpcfn               equ      $cb00
;***************************************************************************
; HEADER SECTION
;***************************************************************************
										CODE
                    org      0
                    fcb      "g GCE 2019", $80            ; 'g' is copyright sign
                    fdb      vextreme_tune1               ; catchy intro music to get stuck in your head
                    fcb      $F6, $60, $20, -$42
                    fcb      "VEXTREME",$80               ; some game information ending with $80
                    fcb      0                            ; end of game header
;***************************************************************************
; CODE SECTION
;***************************************************************************
; here the cartridge program starts off
main
rpccopystart
                    ldx      #rpcfndat
                    ldy      #rpcfn
rpccopyloop
                    lda      ,x+
                    sta      ,y+
                    cmpx     #rpcfndatend
                    bne      rpccopyloop
init_vars
; init menu var
                    jsr      init_page_cursor
; init vextreme logo vars
                    lda      #1
                    sta      logo_dir
                    lda      #20
                    sta      logo_scale
                    lda      #1
                    sta      calibrationValue
                    lda      #1
                    sta      gameScale
loop
; Recal video stuff
                    jsr      Wait_Recal
                    jsr      Intensity_5F
; display vextreme logo
drawLogo
                    ldx      #_SM_vextreme_logo
nextLogoPart
                    lda      logo_scale
                    sta      VIA_t1_cnt_lo
                    lda      #$CE                          ;Blank low, zero high?
                    sta      <VIA_cntl
                    ldu      ,x++
                    beq      logoDone
                    jsr      drawSmart
                    bra      nextLogoPart
logoDone
; logo zoom in animation
                    lda      logo_scale
                    cmpa     #34
                    beq      logoZoomDone
                    inca
                    sta      logo_scale
logoZoomDone
; menu font settings
                    ldd      #$f160
                    std      Vec_Text_HW
                    lda      #$80
                    sta      <VIA_t1_cnt_lo
; update joystick
                    lda      #1
                    sta      Vec_Joy_Mux_1_X
                    lda      #3
                    sta      Vec_Joy_Mux_1_Y
                    lda      #0
                    sta      Vec_Joy_Mux_2_X
                    sta      Vec_Joy_Mux_2_Y
                    lda      #0
                    sta      curpos
nameloop
                    ldb      cursor              ;Handle highlighting of active entry
                    cmpb     curpos
                    bne      nohighlight
                    jsr      Intensity_7F
                    bra      hlend

nohighlight
                    jsr      Intensity_5F
hlend
; load address of next string title in reg U based on (page * 4) + curpos
                    ldu      #filedata                    ;data of pointer to filenames
                    ldb      page                         ;load page no
                    lda      #0
                    lslb                                  ; *4
                    rola                                  ; |
                    lslb                                  ; |
                    rola                                  ; |
                    addb     curpos                       ;add in current pos
                    adca     #0
                    lslb                                  ;because the addresses are 2 bytes
                    rola
                    leau     d,u                          ;fetch addr of string, page
                    ldu      a,u                          ;add pos
; adjust menu Y position in reg A
                    lda      curpos
                    nega                                  ;because y decreases downward
                    lsla                                  ; *8
                    lsla                                  ; |
                    lsla                                  ; | (fine tunes Y line spacing, add more lsla's to inc.)
                    adda     #MENU_POS_Y                  ; menu y offset from 0,0
; check if we hit the end of the list within this page
                    cmpu     #0                           ; compare reg U to null pointer, which signifies end of menu data
                    bne      showtitle                    ; if not the end, showtitle
                    lda      #1                           ; else bail out and set onlastpage = 1 to avoid lengthy test later
                    sta      onlastpage                   ;  |
                    lda      lastpagecursormax
                    sta      cursormax
                    bra      menuend
showtitle

                    ldb      #MENU_POS_X                  ; menu x offset from 0,0
                    jsr      sync_Print_Str_d             ;print string
                    lda      curpos
                    inca
                    sta      curpos
                    cmpa     #MENU_ITEMS_MAX              ; number of menu items
                    bne      nameloop
                    lda      #0
                    sta      onlastpage
                    lda      #MENU_ITEMS_MAX
                    sta      cursormax
menuend
                    jsr      Intensity_5F
                    ldu      #buttons_label
                    lda      #BUTTONS_POS_Y
                    ldb      #BUTTONS_POS_X
                    jsr      sync_Print_Str_d             ;print string
gfxend
;End of gfx routines.
;Input handling
                    lda      waitjs
                    bne      dowaitjszero
                    jsr      Joy_Digital
;X handling
                    lda      Vec_Joy_1_X
                    jsr      handlepage
;Y handling
                    lda      Vec_Joy_1_Y
                    beq      skipymove
                    bpl      ymoveup
ymovedown
                    lda      cursor
                    inca      
                    cmpa     cursormax
                    bne      ymovedone
                    lda      #0
                    bra      ymovedone
ymoveup
                    lda      cursor
                    beq      ymoveupwrap
                    deca
                    bra      ymovedone
ymoveupwrap
                    lda      cursormax
                    deca
ymovedone       
                    sta      cursor
                    ldb      1
                    stb      waitjs
                    bra      skipymove
skipymove
                    jsr      Read_Btns
                    anda     #$0F                         ; ignore joy2
                    lsla                                  ; convert to 2-byte index
                    ldu      #button_routines
                    leau     a,u                          ;fetch addr of string, page
                    pulu     pc

;Js has been touched. Ignore input until it returns.
;(ToDo: input repeating?)
dowaitjszero
                    jsr      Joy_Digital
                    lda      Vec_Joy_1_X
                    bne      nozero
                    lda      Vec_Joy_1_Y
                    bne      nozero
                    sta      waitjs
nozero
                    jmp      loop

button_routines
                    fdb      nobuttons                    ; 0x00 no buttons
                    fdb      dirup                        ; 0x01 b1
                    fdb      pageleft                     ; 0x02 b2
                    fdb      nobuttons                    ; 0x03 b2+b1
                    fdb      pageright                    ; 0x04 b3
                    fdb      nobuttons                    ; 0x05 b3+b1
                    fdb      nobuttons                    ; 0x06 b3+b2
                    fdb      nobuttons                    ; 0x07 b3+b2+b1
                    fdb      startgame                    ; 0x08 b4
                    fdb      nobuttons                    ; 0x09 b4+b1
                    fdb      nobuttons                    ; 0x0A b4+b2
                    fdb      nobuttons                    ; 0x0B b4+b2+b1
                    fdb      nobuttons                    ; 0x0C b4+b3
                    fdb      nobuttons                    ; 0x0D b4+b3+b1
                    fdb      nobuttons                    ; 0x0E b4+b3+b2
                    fdb      nobuttons                    ; 0x0F b4+b3+b2+b1

nobuttons
                    jmp      loop

pageleft
                    lda      #-1
                    bra      dopage
pageright
                    lda      #1
dopage
                    jsr      handlepage
                    jmp      loop

startgame                                                          ;Start the game.
                    lda      page                         ;Calculate the number of the ROM
                    lsla                                  ; (page * 4) + cursor
                    lsla                                  ;  |
                    adda     cursor                       ;  |
                    sta      $7ffe                        ;Store in special cart location
                    lda      #1                           ;rpc call to load a rom
                    jmp      rpcfn                        ;Call

dirup
                    lda      #3                           ;rpc call to change up a directory
                    jmp      rpcfn                        ;Call


; Handle changing pages left/right
handlepage
                    beq      skipxmove
                    bpl      xpos
                    lda      page
                    beq      xmovedone
                    dec      page
                    bra      xmovedone
xpos
										lda      onlastpage
										bne      xmovedone
                    lda      page
										cmpa     lastpage
                    bne      donextpage                   ; if not, do next page
                    bra      xmovedone
donextpage
                    inc      page
										lda      page
                    cmpa     lastpage
                    bne      xmovedone
                    lda      #1                           ; else set onlastpage = 1
                    sta      onlastpage                   ;  |
                    lda      lastpagecursormax
                    sta      cursormax
										deca
                    cmpa     cursor
                    bpl      xmovedone
                    sta      cursor
xmovedone
                    ldb      1
                    stb      waitjs
skipxmove
                    rts

init_page_cursor
                    ; set up last selected cart vars
                    lda      lastselcart
                    anda     #3
                    sta      cursor
                    lda      lastselcart                  ; (lastselcart / 4) = page
                    lsra                                  ;  |
                    lsra                                  ;  |
                    sta      page                         ;  |
                    ; pre-compute last page / num items on last page
                    lda      listingcount
                    inca
                    anda     #3
                    sta      lastpagecursormax
                    lda      listingcount                 ; (listingcount / 4) = lastpage
                    lsra                                  ;  |
                    lsra                                  ;  |
                    sta      lastpage                     ;  |
                    rts

;Rpc function. Because this makes the cart unavailable, this
;will copied to SRAM. Call as rpcfn.
rpcfndat
                    sta      $7fff
rpcwaitloop
                    lda      $0
                    cmpa     # 'g'
                    bne      rpcwaitloop
                    lda      $1
                    cmpa     # ' '
                    bne      rpcwaitloop
                    ; set up header comparison
                    ldx      #$11
                    ldu      #rpcfn+(vextreme_marker-rpcfndat) ; needs to be relative to where it's copied in ram
headerloop
                    lda      ,x+
                    cmpa     ,u+
                    bne      newrom
                    cmpx     #$1A
                    bne      headerloop
                    jsr      init_page_cursor
                    jmp      loop ;start address
newrom
                    ldu      #$f000
                    pshs     u
                    rts
vextreme_marker
                    fcb      "VEXTREME",$80   ; for matching against cart header
rpcfndatend
;***************************************************************************
; SUBROUTINE SECTION
;***************************************************************************
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

buttons_label
                    fcb      "(BK) (<) (>) (SEL)",$80               ; some game information ending with $80
;***************************************************************************
; MENU SECTION
;***************************************************************************
;Test multicart list data. This gets overwritten by the firmware running in the
;STM with actual cartridge data.
                    org      $ffe
listingcount                    
                    fcb      0
                    org      $fff
lastselcart
                    fcb      0
                    org      $1000
filedata
                    fdb      text0
                    fdb      text1
                    fdb      text2
                    fdb      text3
                    fdb      text4
                    fdb      text5
                    fdb      text6
                    fdb      text7
                    fdb      text8
                    fdb      text9
                    fdb      text10
                    fdb      text11
                    fdb      text12
                    fdb      text13
                    fdb      text14
                    fdb      text15
                    fdb      text16
                    fdb      text17
                    fdb      text18
                    fdb      text19
                    fdb      font1
                    fdb      font2
                    fdb      font3
                    fdb      font4
                    fdb      font5
                    fdb      font6
                    fdb      font7
                    fdb      font8
                    fdb      font9
                    fdb      font10
                    fdb      font11
                    fdb      font12
                    fdb      0
text0
                    fcb      "CART 1",$80
text1
                    fcb      "CART 2",$80
text2
                    fcb      "CART 3",$80
text3
                    fcb      "CART 4",$80
text4
                    fcb      "DE VIERDE UNIT",$80
text5
                    fcb      "EENTJE MET EEN LANGE NAAM DUS",$80
text6
                    fcb      "BEN IK HET AL ZAT?",$80
text7
                    fcb      "LALALA",$80
text8
                    fcb      "OMGWTFBBQ",$80
text9
                    fcb      "GNORK",$80
text10
                    fcb      "EENTJE MET EEN LANGE NAAM DUS",$80
text11
                    fcb      "BEN IK HET AL ZAT?",$80
text12
                    fcb      "LALALA",$80
text13
                    fcb      "OMGWTFBBQ",$80
text14
                    fcb      "GNORK",$80
text15
                    fcb      "GNORK2",$80
text16
                    fcb      "GNORK3",$80
text17
                    fcb      "GNORK4",$80
text18
                    fcb      "OMGWTFBBQ",$80
text19
                    fcb      "GNORK",$80
font1
                    fcb      "! \"#$%&",$80
font2
                    fcb      "`()*+,-./",$80
font3
                    fcb      "0123456789",$80
font4
                    fcb      ":;<=>?@",$80
font5
                    fcb      "ABCDEFGH",$80
font6
                    fcb      "IJKLMNOP",$80
font7
                    fcb      "QRSTUVW",$80
font8
                    fcb      "YZ[\]^_",$80
font9
                    fcb      "abcdefgh",$80
font10
                    fcb      "ijklmnop",$80
font11
                    fcb      "qrstuvw",$80
font12
                    fcb      "xyz{|}~",$80

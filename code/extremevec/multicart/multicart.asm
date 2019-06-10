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
	include "vectrex.i"

page	EQU	$ca00
cursor	EQU $ca01
curpos  EQU $ca02
waitjs	EQU $ca03
lastpage EQU $ca04

rpcfn	EQU $cb00

;Cartridge header
	ORG 0
	fcb "g GCE 2015", $80		;'g' is copyright sign
	fdb music1					;music from the rom
	fcb $F8, $50, $20, -$56		; height, width, rel y, rel x (from 0,0)
	fcb "MULTICART",$80			; some game information ending with $80
	fcb 0						; end of game header

main
;copy rpc fn into place
	ldx #rpcfndat
	ldy #rpcfn
rpccopyloop
	lda ,x+
	sta ,y+
	cmpx #rpcfndatend
	bne rpccopyloop
	
;default values
	lda lastselcart
	anda #7
	sta cursor
	lda lastselcart
	lsra
	lsra
	lsra
	sta page

loop
;Recal video stuff
	JSR Wait_Recal
	JSR Intensity_5F

;js things
	lda #1
	sta Vec_Joy_Mux_1_X
	lda #3
	sta Vec_Joy_Mux_1_Y
	lda #0
	sta Vec_Joy_Mux_2_X
	sta Vec_Joy_Mux_2_Y


	lda #0
	sta curpos
nameloop
	;Handle highlighting of active entry
	ldb cursor
	cmpb curpos
	bne nohighlight
	JSR Intensity_7F
	bra hlend
nohighlight
	JSR Intensity_5F
hlend

	ldu #filedata	;data of pointer to filenames
	ldb page		;load page no
	lda #0
	lslb			;*8
	rola
	lslb
	rola
	lslb
	rola
	addb curpos		;add in current pos
	adca #0
	lslb			;because the addresses are 2 bytes
	rola
	leau d,u			;fetch addr of string, page
	ldu a,u			;add pos

	lda curpos
	nega			;because y decreases downward
	lsla			;*16
	lsla
	lsla
	lsla
	adda #50		;move up by a bit
	cmpu #0			;;se if we're at the end of the list
	bne showtitle
	;Yep -> bail out
	lda #1
	sta lastpage
	bra gfxend
showtitle
	ldb #-110		;x offset
	jsr Print_Str_d	;print string

	lda curpos
	inca
	sta curpos
	cmpa #8
	bne nameloop

	lda #0
	sta lastpage
gfxend
;End of gfx routines.


;Input handling
	lda waitjs
	bne dowaitjszero


	jsr Joy_Digital
;X handling
	lda Vec_Joy_1_X
	beq skipxmove
	bpl xneg
	lda page
	beq xmovedone
	dec page
	bra xmovedone
xneg
	lda lastpage
	bne xmovedone
	inc page
xmovedone
	ldb 1
	stb waitjs
skipxmove

;Y handling
	lda Vec_Joy_1_Y
	beq skipymove
	bpl yneg
	inc cursor
	bra ymovedone
yneg
	dec cursor
ymovedone
	lda #7
	anda cursor
	sta cursor
	ldb 1
	stb waitjs
skipymove

	jsr Read_Btns
	cmpa #0
	beq nobuttons
	
	;Start the game.
	lda page	;Calculate the number of the ROM
	lsla
	lsla
	lsla
	adda cursor
	sta $7ffe	;Store in special cart location
	ldu #$f000	;Warm start address
	pshs u		;Push to stack so rpcfn will return to this
	lda #1		;rpc call to load a rom
	jmp rpcfn	;Call
	;We shouldn't return here.
nobuttons
	jmp loop

;Js has been touched. Ignore input until it returns.
;(ToDo: input repeating?)
dowaitjszero
	jsr Joy_Digital
	lda Vec_Joy_1_X
	bne nozero
	lda Vec_Joy_1_Y
	bne nozero
	sta waitjs
nozero
	jmp loop


;Rpc function. Because this makes the cart unavailable, this
;will copied to SRAM. Call as rpcfn.
rpcfndat
	sta $7fff
rpcwaitloop
	lda $0
	cmpa #'g'
	bne rpcwaitloop
	lda $1
	cmpa #' '
	bne rpcwaitloop
	rts
rpcfndatend


;Test multicart list data. This gets overwritten by the firmware running in the
;STM with actual cartridge data.

	org $3ff
lastselcart
	fcb 0
	org $400
filedata
	fdb text0
	fdb text1
	fdb text2
	fdb text3
	fdb text4
	fdb text5
	fdb text6
	fdb text7
	fdb text8
	fdb text9
	fdb text10
	fdb text11
	fdb text12
	fdb text13
	fdb text14
	fdb text15
	fdb text16
	fdb text17
	fdb text18
	fdb text19
	fdb 0


text0
	fcb "CART 0",$80
text1
	fcb "CART 1",$80
text2
	fcb "CART 2",$80
text3
	fcb "DERDE CART",$80
text4
	fcb "DE VIERDE UNIT",$80
text5
	fcb "EENTJE MET EEN LANGE NAAM DUS",$80
text6
	fcb "BEN IK HET AL ZAT?",$80
text7
	fcb "LALALA",$80
text8
	fcb "OMGWTFBBQ",$80
text9
	fcb "GNORK",$80
text10
	fcb "EENTJE MET EEN LANGE NAAM DUS",$80
text11
	fcb "BEN IK HET AL ZAT?",$80
text12
	fcb "LALALA",$80
text13
	fcb "OMGWTFBBQ",$80
text14
	fcb "GNORK",$80
text15
	fcb "GNORK2",$80
text16
	fcb "GNORK3",$80
text17
	fcb "GNORK4",$80
text18
	fcb "OMGWTFBBQ",$80
text19
	fcb "GNORK",$80






; ESP Ra. De. (international ver) Free Play patch
; 2018 Michael Moffitt
; mikejmoffitt@gmail.com
;
; This patch adds a Free Play option to the game's configuration screen,
; replacing the 3 coins / 1 play option that is rarely used in a home or
; presentation environment.
;
; A forced-reset feature is also added, where holding both start buttons
; for three seconds resets the game, allowing a player to start fresh.
;
; Presently only the international version of the game has been patched.
; Support for either Japanese release can be done, it would just require
; a little more work.
;
; Place dumps of the original international version's U41 and U42 ROMs
; in the same directory, and assemble with Macro Assembler. Burn the
; resulting u41.bin and u42.bin files in the out/ directory to a pair of
; 27C040 EPROM / 29F040 FLASH chips and install on the PCB.

; AS configuration and original binary file to patch over
	CPU 68000
	PADDING OFF
	ORG		$000000
	BINCLUDE	"prg.orig"

; Port definitions and useful RAM values
INPUT_P1_HW = $D00000 ; Start is the MSB of the first byte, $80
INPUT_P2_HW = $D00002 ; same for P2
INPUT_P1 = $101254 ; The game inverts hardware reads and stuffs results here
INPUT_P2 = $101256 ; ditto for P2
CRED_COUNT = $101226 ; Number of valid credits; i.e. number of entries
CRED_PREV = $101228 ; Seems to be used to keep track of last frame's count
COINAGE_CFG = $101299 ; Copy of settings from the EEPROM found in RAM.

; Some locations of interest
FREE_REGION = $07A204 ; Found a big blob of unused ROM, all $FF
GAME_START_LOC = $004200
DRAW_CREDTEXT_LOC = $04F672
DRAW_SPRITE_LOC = $0527F0
CONTINUE_LOC = $004ABC
STARTFREE_LOC = $004206
SPINNING_START_LOC = $005476
TITLE_INSCOIN_LOC = $004018
INSCOIN_BOTTOM_LOC = $05078E
TITLE_START_INIT_LOC = $0040FC
START_TRANSITION_COUNT = $101ECE
DEMO_EXPIRE_NUM = $09E0
DEMO_TIMER = $100EC6
VBL_HIT_FLAG = $100F04
WAIT_VBL_LOC = $04F37C
TRANSITION_LOC = $1025B4
YMZ_LOC = $300000

PLAY_SOUND_LOC = $065062
STOP_SOUND_LOC = $0655AC

; Unused RAM we're going to use to count how long the start button(s) are held
CHARSEL_WDOG = $10FC00
RESET_TIMER = $10FC02

; The how-to-play screen tends to end on 8A9, but if a player joins on the last
; frame, the counter is reset to 10 seconds, letting it end on BE1.
; $C0D gives a little overhead, and it's a kind of fish, so it was chosen.
CHARSEL_WDOG_MAX = $C0D
RESET_TIMER_MAX = 180

; Screen state machine
SC_STATE = $10240A

S_INIT        = $0
S_TITLE       = $1
S_HISCORE     = $2
S_DEMOSTART   = $3
S_TITLE_START = $4
S_DEMO        = $5
S_INGAME_P2   = $6
S_INGAME_P1   = $7
S_CONTINUE1   = $8
S_LOGO_DARK   = $9
S_CONTINUE2   = $A ; I am still unsure what differentiates this from $8.
S_HOWTOPLAY   = $B
S_CAVESC      = $C
S_ATLUSSC     = $D
S_UNK         = $E
S_INVALID     = $F

; Set the "3 coins 1 play" text to read FREE PLAY instead
; ============================================================================
	ORG	$064521
	DC.B	"     FREE PLAY      "
	ORG	$0645FD
	DC.B	"     FREE PLAY      "

; Change the version string on the legal notice screen
; ============================================================================
	ORG	$0641FE
	DC.B	" 980422 / 180110 MOFFITT VER. \\"
	; Cave always uses two terminating marks "\\", even though the text
	; printing routine at $04FCD6 only checks for one.

; Make pressing a start button during attract go to the game start screen
; ============================================================================
	ORG	DRAW_CREDTEXT_LOC
	; Replacement hook
	jmp start_hook		; move.w #$1C0, d1
post_starthook:
	nop			; tst.w ($1025AC).l
	nop

; Make game-starting free, and not subtract from the credit count
;=============================================================================
	ORG	STARTFREE_LOC
	jmp startfree_hook
post_startfreehook:

; Make in-game join-in / continue free, and not subtract from the credit count
; ============================================================================
	ORG	CONTINUE_LOC
	jmp continue_hook
post_continuehook:

; Make the title screen show the spinning "press start" text if on free play
; ============================================================================
	ORG	TITLE_INSCOIN_LOC
	jmp title_inscoin_hook
post_inscoinhook:

; Hide "insert credit" sprite on the bottom if in free play
; ============================================================================
	ORG	INSCOIN_BOTTOM_LOC
	jmp inscoin_bottom_hook
post_inscoin_bottomhook:

; If start isn't held on the "press-start" title screen, revert to normal
; ============================================================================
	ORG	TITLE_START_INIT_LOC
	jmp title_start_exit_hook
post_title_start_exithook:

; Patch the wait-for-vblank routine to do the holding-start check for reset
; ============================================================================
	ORG	WAIT_VBL_LOC
	jmp wait_vbl_hook
	nop
	nop
	nop
	nop
	; We want to keep this entire looping structure in the new routine,
	; since it is a tight loop using a short branch (beq.s). The NOPs
	; overwrite the tst.w and beq.s instructions that were absorbed.
post_wait_vblhook:

; Subroutines stuffed into empty ROM space
; ============================================================================
	ORG FREE_REGION

; Hook in the "wait-for-vblank" routine that checks the reset timers
; ============================================================================
wait_vbl_hook:
.wait_for_vbl:
; Now do the normal VBL wait bit
	addq.b #1, ($1011F9).l
	tst.w (VBL_HIT_FLAG).l
	beq.s .wait_for_vbl

	move.l d1, -(sp)
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en
	bra .end

.freeplay_en:

.user_reset:
	; P1 and P2 buttons both held?
	; Read P1 and P2 inputs together
	move.w (INPUT_P1).l, d1
	and.w (INPUT_P2).l, d1
	andi.b #$80, d1
	beq .no_user_reset

	; Buttons held; increment reset timer
	addi #1, (RESET_TIMER).l
	cmpi.w #RESET_TIMER_MAX, (RESET_TIMER).l
	bcs .charsel_watchdog

	; Buttons held for (charsel_wdog_max), do a hot crash
	clr.w (RESET_TIMER).l
	jmp crash_machine

.no_user_reset:
	clr.w (RESET_TIMER).l

.charsel_watchdog:
	; Are we in how to play?
	move.w (SC_STATE).l, d1
	cmpi.w #S_HOWTOPLAY, d1
	bne .no_wdog_reset

	; KIND OF GROSS HACK ALERT
	; There is a bug that is extremely hard to reproduce. Only twice I
	; have hit start, gotten through character select, the transition
	; animation begins, and... the screen stays covered in the transition
	; squares indefinitely. The BGM is still of the how to play / char
	; select screen, so for some reason the transition to state $5 is
	; not made. This is a soft watchdog to ensure that the character
	; select screen is stuck for too long. This is for if the game is run
	; in a semi-public setting.
	;
	; This hack is in the wait for vblank routine as the same mechanism is
	; used to allow you to hold P1 & P2 start to reset the machine.
	; Increment the counter
	addi #1, (CHARSEL_WDOG).l
	cmpi.w #CHARSEL_WDOG_MAX, (CHARSEL_WDOG).l
	bcs .end

	; We have been on this screen longer than we should.
	; Crash the game into a reset
	clr.w (CHARSEL_WDOG).l
	jmp crash_machine

.no_wdog_reset:
	clr.w (CHARSEL_WDOG).l

.end:
	move.l (sp)+, d1
	jmp post_wait_vblhook

; Hook during title ($4)'s init that'll revert to the normal title ($1) if the
; player isn't holding start.
; This is to eliminate situations where start is held for exactly one frame,
; so we aren't stuck on the title $4 forever.
; ============================================================================
title_start_exit_hook:
	move.l d1, -(sp)
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	; Free play isn't enabled; do the normal stuff and get out
	move.l (sp)+, d1
	tst.b ($102409).l
	jmp post_title_start_exithook

.freeplay_en:
	move.l (sp)+, d1
	; If screen transition has started, don't bother with the rest of this
	tst.b ($100ECC).l
	beq .continue
	jmp post_title_start_exithook

.continue
	; Read P1 and P2 inputs together
	move.w (INPUT_P1).l, d1
	or.w INPUT_P2, d1
	andi.b #$80, d1

	; If start is not held, redirect to regular title
	beq .finish

	; Else, continue like normal
	tst.b ($102409).l
	jmp post_title_start_exithook
.finish:

	; Change the state to the title screen
	clr.w ($100EC4).l
	move.w #S_TITLE, (SC_STATE).l
	jmp post_title_start_exithook

; Remove the "insert coin!" scroller in-game if free play is enabled.
; ============================================================================
inscoin_bottom_hook:
	move.l d1, -(sp)
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	; Free play is not enabled; resume normal logic
	move.l (sp)+, d1
	cmp.w (CRED_COUNT).l, d4
	jmp post_inscoin_bottomhook

.freeplay_en:
	; Jump past the check to drawing the normal empty bottom bar
	move.l (sp)+, d1
	jmp $507AC

; Place the spinning "press start" text on the title if in free play instead
; of showing the credit count.
; Glancing at the state machine entry for title $1, it looks like this was
; originally supposed to be present on this screen without having to flip
; to another state. Even on a normal ESP Ra. De. program the spinning logo
; routine is called for one frame before it flips on over to title $4.
; ============================================================================
title_inscoin_hook:
	
	move.l d1, -(sp)
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	; Go back to showing the normal "CREDIT n" stuff
	jsr $004FCD6
	bra .post

.freeplay_en:
	; Call the routine to place the press start animation
	jsr SPINNING_START_LOC

.post:
	move.l (sp)+, d1
	; Jump past the point of drawing the credit message on screen
	jmp post_inscoinhook

; Hook in the title screen ($4) code that subtracts credits on start.
; ============================================================================
startfree_hook
	move.w d6, ($10240C).l
	move.l d1, -(sp)
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	move.l (sp)+, d1
	jmp post_startfreehook

.freeplay_en:
	move.l (sp)+, d1
	; Skip right past the credit subtraction
	jmp $004222

; Hook in the code that checks for # credits when player tries to continue.
; ============================================================================
continue_hook:
	move.l d1, -(sp)
	; Is free play enabled?
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	; if not, reproduce the original credit check sequence and get back
	move.l (sp)+, d1
	cmp.w (a1), d3
	bhi.w .locret
	jmp post_continuehook

.freeplay_en
	move.l (sp)+, d1
	; Show "press start" graphic(s)
	jsr $507E8
	and.w ($1013A8).l, d6
	beq.w .locret
	; Jump past the part of the routine that checks # credits and subtracts
	; them when the player presses start
	jmp $004ADA
.locret: 
	rts

; Hook placed in "drawing credit" routine that pushes the screen state machine
; to $4 (title, waiting for start button) if free play is on, and start is hit
; ============================================================================
start_hook:
	; Is free play enabled?
	move.b (COINAGE_CFG).l, d1
	andi.b #$F0, d1
	cmpi.b #$30, d1			; Check if 1P freeplay enabled
	beq .freeplay_en
	cmpi.b #$C0, d1			; Check if 2P freeplay enabled
	beq .freeplay_en
	cmpi.b #$F0, d1			; Check if both freeplay enabled
	beq .freeplay_en

	; Not in free play; do normal credit drawing operations and resume
	; from where the original code did.
	move.w #$1C0, d1
	tst.w ($1025AC).l
	jmp post_starthook

.freeplay_en:
	; Zero out the credit count just in case
	clr.w (CRED_COUNT).l
	clr.w (CRED_PREV).l

	move.w	(SC_STATE).l, d1
	; We don't want to be able to start (at least not this way) from
	; the continue screen or the how to play screen
	cmpi.w	#S_CONTINUE1, d1
	beq .finish
	cmpi.w	#S_CONTINUE2, d1
	beq .finish
	cmpi.w	#S_HOWTOPLAY, d1
	beq .howtoplay

	; Read P1 and P2 inputs together
	move.w (INPUT_P1).l, d1
	or.w INPUT_P2, d1
	andi.b #$80, d1

	; If start is not held, get out of here
	beq .finish

	; If the transition animation is playing, abort
	; This is to avoid an edge case where start is pressed briefly on the
	; title --> demo transition, where the transition effect will be stuck
	; until the demo starts the next time. This is cleaner than forcing
	; the animation to exit prematurely.
	tst.w (TRANSITION_LOC).l
	bne .finish

	; This is a hack-on-a-hack to let the demo exit cleanly. It sets the
	; demo duration counter to the expiry value instead of manipulating
	; the state machine.
	; The logic for the gameplay itself somewhat runs all the time, hidden
	; only by being disabled and/or having other screens layered on top.
	; If the demo isn't allowed to "clean up" after itself, changing the
	; screen state to the title will give you the demo character doing
	; spastic shooting in the lower-left (really hardware top-left 0,0)
	; and the title screen backdrop slowly scrolls downwards until the
	; game crashes. It's just not a good look.
	move.w (SC_STATE).l, d1
	cmpi.w #S_DEMO, d1
	beq .demo
	cmpi.w #S_DEMOSTART, d1
	beq .demo
	
	; If we're not on the demo screen, just change the state to the title.
	clr.w ($100EC4).l
	move.w #S_TITLE_START, (SC_STATE).l
	rts

.demo:
	; Kill the demo.
	move.w #DEMO_EXPIRE_NUM, (DEMO_TIMER).l
.finish:
	rts

.howtoplay:
	; The how-to-play screen has a little hack to set the credits to a
	; high amount so the "insert coin" doesn't show
	move.w #9, (CRED_COUNT).l
	rts

; Routine to stop all sounds and yell "esprade", then crash the machine.
; ============================================================================
crash_machine:
	jsr (STOP_SOUND_LOC).l
	move.w #$51, d0 ; Sound ID in d0
	move.w #$03, d1 ; Channel to play on in d1 (sound test uses 3)
	jsr (PLAY_SOUND_LOC).l

.play_yell_sound:

	jmp $FFFFFE

;			
;	Tiny BASIC Extended for BYOC-24 CPU Cyclone V (FPGA) Version		
;			
;	Date Created: 10/01/2019		
;			
;	Modified:	1/6/2020 11:41	
;			
;	Base on version originally published in		
;	Dr. Dobb's Journal Jauary 1976		
;	Created by Dick Whipple		
;			
; Additions to Tiny BASIC			
; 1. Multistatement lines			
;			
;			
;			
start:	call	clrscr	;Clear screen
	lxi	irom,msg_wel	;Print welcome message
	call	msgout	
	call	cinit	;Initialize for cold start
	call	 newline	;Skip a line
;			
wstart:	call	winit	;Initialize for warm start
	mvi	a,0b00000011	;Reset push/pop & call/return stacks
	out	0xff,a	
	call	newline	;New line
	call	getline	;Get command or statement
	call	trns	;Translate keywords
	call	newline	;New line
	call	tstl	;Command or statement (to insert)?
	jnc	cmdpr	;If a command, go execute it
	call	insrt	;If a statement, insert it (or delete/replace)
	jmp	wstart	;Repeat
;			
; Command Processor			
;			
cmdpr:	ldr	l,txtstrt	;Point IRAM to start of text in input buffer
	ldr	h,txtstrt+1	
	ldhl	iram	
	ldx	c,(iram)	;TBXC
	sui	c,0b10000000	
	jc	let	
	inx	iram	;Point first text byte
	call	getlink	;If found, get keyword address in HL
	pchl		;Go process it
;			
; Statement Processor			
;			
stmpr:	ldx	a,(iram)	;Update curlbl from program line number
	str	curlbl+1,a	
	inx	iram	
	ldx	a,(iram)	
	str	curlbl,a	
	inx	iram	;Skip line length
	mov	a,iraml	;Store (start of line program text - 1) TBX start
	str	ltxtstrt,a	
	mov	a,iramh	
	str	ltxtstrt+1,a	
stmprns:	inx	iram	;Point next program byte TBX end
stmprc:	mov	a,iraml	;Store start of program text
	str	txtstrt,a	
	mov	a,iramh	
	str	txtstrt+1,a	
	call	skipspace	;Get next nonspace character
	ldx	c,(iram)	;TBXC
	sui	c,0b10000000	
	jc	let	
	inx	iram	;Point first text byte
stmprc0:	call	getlink	;If so, get keyword address in HL
	pchl		;Process statement at HL
;			
; Check that IRAM is at the end of a line(CR)			
;			
; TBX - Modified all			
;			
done:	inp	a,cntr_port	;Get keyboard character into A
	ani	a,kby_mask	;Character available?
	jz	donec0	;If not, continue
	inp	a,data_port	;Get the ASCII character
	cpi	a,escape	;Escape code?
	jz	wstart	;If so, do a warm start
donec0:	call	skipspace	;Skip any spaces
	cpi	a,':'	;End of multi-statement (:)?
	jz	stmprns	;If so, go on to next statement
	cpi	a,cr	;End of line (CR)?
	jnz	err4	;If not, raise expected end of line error
donec0a:	inx	iram	
	ldr	l,curlbl	;Get current label
	ldr	h,curlbl+1	
	or	h,l	;A command (0 label)
	jz	wstart	;If so, get a new line
donec1:	ldr	l,prgend	;Check for end of progarm?
	ldr	h,prgend+1	
	cphl	iram	
	jnz	stmpr	;If not program end, continue to next program line
	jmp	wstart	;Otherwise, end execution
;			
; Process LET Statement			
;			
let:	call	skipspace	:Get next nonspace character -  a variable?
	call	getvaradrs	;Get the variable's address
	jnc	err10	;If not a variable, raise expected variable error
	push	h	;Save address on PP stack
	push	l	
	call	skipspace	;Get next nonspace character
	cpi	a,'='	;Equal sign?
	jnz	err0	;If not, raise syntax error
	inx	iram	;Point next character
	call	skipspace	;Get next nonspace character -an expression?
	call	expr	;Evaluate it
	call	store	;Store the result
	jmp	done	;Done
;			
; Process PRINT Statement			
;			
print:	call	skipspace	;Get next nonspace character
	call	printlit	;Print literal("..text..") if present
printc0:	call	skipspace	;Get next non-space character
	cpi	a,';'	;Semicolon?
	jnz	printc1	;If not, continue
	mvi	a,' '	;Print space
	call	chrout	
	inx	iram	;Point next program character
printe:	call	skipspace	;Get first non-space character
	cpi	a,cr	;End of line?
	jz	done	;If so, done w/o new line
	cpi	a,':'	;Multistatement line? (TBX Mod)
	jz	done	;If so, done w/o new line (TBX Mod)
	jmp	print	;If not, back for more items to print
;			
printc1:	cpi	a,','	;Zone Spacing?
	jnz	printc2	;If not, continue
	inx	iram	;Point next program character
printl0:	ldr	a,zone	;Get zone counter
	ani	a,0b00000111	;Mask lower 3 bits
	jz	printe	;If zero, done
	mvi	a,' '	;Print a space
	call	chrout	
	jmp	printl0	;Back to check if end of zone reached
;			
printc2:	cpi	a,cr	;End of line?
	jz	printc3	;If so, continue  TBX Start
	cpi	a,':'	;Multistatement line?
	jz	printc3	;If so, continue
	call	expr	;Assume an expression and evaluate it
	call	printnum	;Print numeric result
	jmp	printc0	;Check for end of line
;			
printc3:	call	newline	;New line
	jmp	done	;Done TBX End
;			
;			
; Print a Literal			
;			
printlit:	ldx	a,(iram)	;Get character
	cpi	a,'"'	;Beginning quotation mark?
	rnz		;If not, return
	inx	iram	;Point next program character
	ldx	a,(iram)	;Get character
	call	chrout	;Print it
printlitl:	inx	iram	;Point next program character
	ldx	a,(iram)	;Get character
	cpi	a,'"'	;Ending quotation mark?
	jz	printlite	;If so, end it
	call	chrout	;Print it
	jmp	printlitl	;Back for more characters
printlite:	inx	iram	;Point next program character
	ret		;Return
;			
; Print Number on Top of Stack			
;			
printnum:	pop	l	;Get number off PP stack
	pop	h	
	cpi	h,0b10000000	;Number negative?
	jc	printnumc0	;If not, continue
	call	twocmp	;Negate it
	mvi	a,'-'	;Print a minus sign
	call	chrout	
printnumc0:	mov	a,h	;Number is zero?
	or	a,l	
	mvi	c,0	;Suppress leading zeros
	jnz	numout	;If not, display it and return
	mvi	a,'0'	;Print a zero digit and return
	jmp	chrout	
;			
; Process LIST Command			
;			
list:	ldr	l,prgstrt	;Get program starting address into IRAM
	ldr	h,prgstrt+1	
	call	skipspace	;Start line number TBX
	cpi	a,cr	
	jz	listc0	;If not, continue
	call	getnum	;Get line number
	jnc	err13	;If not, raise expected line number error
	pop	e	;Get it into DE
	pop	d	
	call	fndlbl	;Get starting address of line
	jnc	err6	;Raise unknown line number error
listc0:	ldhl	iram	
	ldr	e,prgend	;Get program ending address in DE
	ldr	d,prgend+1	
listl0:	mov	l,e	
	mov	h,d	
	cphl	iram	;Reached program end?
	jz	wstart	;If so, do a warm start
	ldx	h,(iram)	;Get line number
	inx	iram	
	ldx	l,(iram)	
	mvi	c,0	;Suppress leading zeros
	call	numout	;Print line number
	inx	iram	;Skip line length byte
	inx	iram	
listl1:	ldx	a,(iram)	;Get character
	cpi	a,0b10000000	;A keyword?
	jc	listc1	;If not, continue
	call	keyout	;Print the keyword TBXC
	inx	iram	;Point next byte
	ldx	a,(iram)	;Get byte
listc1:	call	chrout	;Print it
	inx	iram	;Point next character
	cpi	a,cr	;Is it a carriage return (end of line)?
	jnz	listl1	;If not, continue
	inp	a,cntr_port	;Get keyboard character into A
	ani	a,kby_mask	;Character available?
	jz	listl0	;If not, continue
	inp	a,data_port	;Get the ASCII character
	cpi	a,escape	;Escape code?
	jz	wstart	;If so, do a warm start
	jmp	listl0	;Reached end of program?
;			
; RUN Processor			
;			
run:	ldr	l,prgend	;Point HL to program end address
	ldr	h,prgend+1	
	str	arrystrt,l	;Arrays start at program end
	str	arrystrt+1,h	
	ldr	l,prgstrt	;Point IRAM to program start address
	ldr	h,prgstrt+1	
	ldhl	iram	
	ldr	l,prgend	;Point IRAM to program start address
	ldr	h,prgend+1	
	cphl	iram	;At end of program?
	jnz	stmpr	;If not, go to statement processor
	jmp	wstart	;Warm start
;			
; STOP Processor			
;			
stop:	call	newline	;Skip line
	lxi	irom,msg_stop	;Print STOP message
	call	msgout	
	ldr	l,curlbl	;Print line number
	ldr	h,curlbl+1	
	mvi	c,0	;Suppress leading zeros
	call	numout	
	jmp	wstart	;Done - Warm start
;			
; GOTO Processor			
;			
goto:	call	skipspace	;Get line target line number on PP stack
	call	expr	
	pop	e	Load it into DE
	pop	d	
	call	fndlbl	;Find the target line number
	jnc	err6	;On carry reset, raise unknown line number error
	ldhl	iram	;Point IRAM to new line
	jmp	stmpr	;Go process it
;			
; IF Processor TBX			
;			
if:	call	lexpr	;Evaluate logical expression
	pop	a	;Get logical result
	rrc	a	;Rotate into carry
	jc	stmprc	;If TRUE, process THEN
ifdone:	ldx	a,(iram)	;Find CR
	cpi	a,cr	
	jz	done	;If found, then done
	inx	iram	
	jmp	ifdone	
;			
; GOSUB Processor			
;			
gosub:	mov	h,iramh	;Put return address on PP stack TBX
	mov	l,iraml	
	push	h	
	push	l	
	ldr	l,ltxtstrt	;Put line text start on PP stack
	ldr	h,ltxtstrt+1	
	push	h	
	push	l	
	jmp	goto	;Transfer execution to line number
;			
; Return Processor			
;			
return:	pop	l	;Get line text start address off PP stack
	pop	h	
	str	ltxtstrt,l	;TBX
	str	ltxtstrt+1,h	
	pop	l	;Get return address off PP stack
	pop	h	
	ldhl	iram	;Point IRAM there
returnl:	ldx	a,(iram)	;Find CR
	cpi	a,cr	
	jz	done	;If found, then done
	cpi	a,':'	;TBX
	jz	done	
	inx	iram	
	jmp	returnl	
;			
; INPUT Processor			
;			
input:	call	skipspace	;Skip to first nonspace
	call	getvaradrs	;Get variable address in HL
	jnc	err7	;If not a variable, raise expected variable error
	push	h	;Put HL on PP stack
	push	l	
	mov	a,iraml	;Save current IRAM address
	str	inptr,a	
	mov	a,iramh	
	str	inptr+1,a	
	mvi	a,'?'	;Print a question mark
	call	chrout	
	call	bufin	;Get value in Input Buffer
	lxi	iram, bufstrt	;Point IRAM to start of Input Buffer
	call	skipspace	;Skip spaces
inputc0:	call	getnum	;Get the value on stack
	call	store	;Store it
	ldr	l,inptr	;Restore IRAM to program line
	ldr	h,inptr+1	
	ldhl	iram	
	jmp	done	;Done
;			
; NEW Processor			
;			
new:	call	cinit	;Initialize for new program
	jmp	wstart	;Back to Main Loop 1
;			
; LOAD Processor			
;			
load:	mov	l,iraml	;Get current program address in HL
	mov	h,iramh	
	call	cinit	;Initialize for new program
	ldhl	iram	;Current program address into IRAM
	call	skipspace	;Skip tp first nonspace
	call	getnum	;Get number of program to load on PP stack
	pop	l	;Then into HL
	pop	h	
	lxi	irom,preprgm	;Point IROM to start address of loaded programs
loadl0:	or	l,l	;Load this program? (Note: Assumes count<256)
	jz	loadc0	;If so, go load it
loadl1:	inx	irom	;Look for next program
	ldx	a,(irom)	
	cpi	a,0xfe	
	jnz	loadl0	
	inx	irom	;Point next IROM byte
	ldx	a,(irom)	
	cpi	a,0xff	;End of programs?
	jz	err11	;Raise no program error
	dcr	l	;Decrement program counter
	jmp	loadl0	
loadc0:	mvi	l,lo(bufstrt)	;Point HL to program start address
	mvi	h,hi(bufstrt)	
loadl2:	ldx	a,(irom)	;Get program to load character
	or	a,a	;End of line?
	jz	loadc1	;If so, continue
	mov	m,a	;Store it in input buffer
	adi	l,1	;Point to next byte
	aci	h,0	
	inx	irom	
	jmp	loadl2	;Repeat
loadc1:	mvi	m,cr	;Place carriage return at end of line
	mov	h,iromh	;Save IROM
	mov	l,iroml	
	push	h	
	push	l	
	call	trns	;Translate keywords TBXC
	pop	l	;Restore IROM
	pop	h	
	ldhl	irom	
	call	tstl	;Command or statement (to insert)
	jnc	cmdpr	;If a command, go execute it
	call	insrt	;Insert the line
	inx	irom	
	ldx	a,(irom)	
	cpi	a,0xfe	;End of program?
	jz	wstart	;If so, do a warm start
	jmp	loadc0	;Repeat
;			
; REM Processor			
;			
rem:	ldr	l,txtstrt	;Get start of text
	ldr	h,txtstrt+1	
	ldhl	iram	;Point IRAM to start of text
	dcx	iram	;Back one location
	ldx	l,(iram)	;Get statement length in HL
	mvi	h,0	
	adhl	iram	;Point IRAM to start of next statement
	dcx	iram	;Back to CR
	jmp	done	;Done
;			
; DIM Processor TBX			
;			
dim:	call	skipspace	;Point to variable
	adi	a,0xc0	;A-Z or a-z?
	jnc	err7	;If not, raise expected variable error
	inx	iram	;Point next character in Data RAM
	ani	a,0b00011111	;Mask lower bits
	dcr	a	;Adjust to zero base
	rlc	a	;Multiply by 2
	mvi	l,lo(varstrt)	;Calculate address
	mvi	h,hi(varstrt)	
	add	l,a	
	aci	h,0	
	push	h	;Put variable address on stack
	push	l	
	ldr	l,arrystrt	;Get array start in HL
	ldr	h,arrystrt+1	
	push	h	;Put on stack
	push	l	
	call	store	;Store array start in variable
	ldx	a,(iram)	;Open prenthesis?
	cpi	a,'('	
	jnz	err0	;If not, raise syntax error
	inx	iram	;Point next byte
	call	expr	;Get first dimension
	ldr	l,arrystrt	;Get array start in HL
	ldr	h,arrystrt+1	
	pop	e	;Pop first dimension in DE
	pop	d	
	cpi	a,')'	;Should be closed parenthesis?
	jnz	err0	;If not, raise a syntax error
	inx	iram	;Point next program byte
	rlc	e	;Double first dimenion
	ral	d	
	jc	err15	;Raise out of memory error
	add	e,l	;Calculate new array start
	adc	d,h	
	jc	err15	;If carry, raise out of memory error.
	cpi	d,hi(memend)	;Check out of memory?
	jnc	err15	;If so, raise out of memory error
	str	arrystrt,e	;Store it
	str	arrystrt+1,d	
diml:	mvi	m,0	;Zero array memory
	adi	l,1	;Increment HL
	aci	h,0	
	cmp	l,e	;Done?
	jnz	diml	;If so, continue
	cmp	h,d	
	jnz	diml	;If so, continue
	call	skipspace	;Get next program byte
	cpi	a,','	;More variables to dimension?
	jnz	done	;If not, then done
	inx	iram	
	jmp	dim	;Process another variable
;			
; RPT Processor TBX			
;			
rpt:	call	skipspace	;Check for end of line?
	cpi	a,cr	
	jnz	rptc	;If not, continue
rpte:	ldr	l,ltxtstrt	;Get (line text start - 1) into IRAM
	ldr	h,ltxtstrt+1	
	ldhl	iram	
	jmp	stmprns	;Go process it
rptc:	call	lexpr	;Assume logical expression
	pop	a	;Get logical result
	rrc	a	;Rotate into carry
	jc	rpte	;If TRUE, repeat line
	jmp	done	
;			
; READ Processor TBX			
;			
read:	call	skipspace	;Check for end of line?
	call	getvaradrs	;Get variable address in HL
	jnc	err10	;If no variable, raise expected variable error
	call	skipspace	;Should be an equal sign
	cpi	a,'='	
	jnz	err0	;If not, raise syntax error
	inx	iram	;Point next program byte
readl:	push	h	;Put address on PP stack
	push	l	
	call	skipspace	;Get data value
	call	getnum	
	jnc	err13	;If not a number, raise expected number error
	call	store	store it
	call	skipspace	;Get next program byte
	cpi	a,','	;More data?
	jnz	done	;If not, done
	inx	iram	;Point next program byte
	adi	l,1	;Increment HL
	aci	h,0	
	jmp	readl	;Do again
;			
;  THEN Processor TBX			
;			
then:	call	skipspace	;Get next program byte
	call	chknum	;Is numeric?
	jc	goto	;If so, then process GOTO
	jmp	stmprc	;Otherwise, process statement
;			
; CLR (Clear Screen) Processor TBX			
;			
clr:	call	clrscr	;Call clear screen subroutine
	jmp	done	
;			
; POKE Processor TBX			
;			
poke:	call	skipspace	;Get next nonspace byte
	call	expr	;Get address to poke
	call	skipspace	;Get next non-space byte
	cpi	a,','	;Should be a comma?
	jnz	err0	;If not, raise syntax error
	inx	iram	
	call	expr	;Get value to poke
	pop	e	;Get value to poke in E
	pop	d	
	pop	l	Get address in HL
	pop	h	
	mov	m,e	;Poke it!
	jmp 	done	;Done
;			
; Logical Expression Evaluator			
;			
lexpr:	call	skipspace	;Skip to first nonspace character
	cpi	a,'!'	;Negation?
	jnz	lexpr0	;If not, continue
	inx	iram	;Point next program byte
	call	lexpr	;Evaluate logical expression
	pop	a	;Negate it
	xri	a,0x01	
	push	a	
	jmp	lexpr1	
lexpr0:	call	lterm	;Evaluate relational expression
lexpr1:	call	skipspace	;Get next program byte
	cpi	a,'&'	;Logical AND?
	jnz	lexpr2	;If not, continue
	inx	iram	;Point next program byte
	call	skipspace	;Get probram byte
	call	lterm	Evaluate relational expression
	pop	a	;Get second result
	pop	b	;Get first result
	and	a,b	;AND the results
	push	a	;Result back on PP stack
	ret		;Done
lexpr2:	cpi	a,'|'	;Logical OR?
	rnz		;If not, done
	inx	iram	;Point next program byte
	call	skipspace	;Get program byte
	call	lterm	;Evaluate relational expression
	pop	a	;Get second result
	pop	b	;Get first result
	or	a,b	;OR the results
	push	a	;Result back on PP stack
	ret		;Done
;			
lterm:	cpi	a,'('	
	jnz	rexpr	
	inx	iram	
	call	lexpr	
	call	skipspace	
	cpi	a,')'	
	jnz	err14	
	inx	iram	
	ret		
;			
; Relational Expression Evaluator			
;			
rexpr:	mvi	a,0	;Preset FALSE result
	push	a	
	call	skipspace	;Skip to first nonspace character
	call	expr	;Get first value on PP stack
	mvi	c,0b10000000	;Set first pass bit 7 in relop status byte
rexprl0:	call	skipspace	;Get first relational operator (relop)
	cpi	a,'<'	;Less than?
	jnz	rexprc0	;If not, continue
	ori	c,0b00000001	;Set less than bit 0
	jmp	rexprc3	;Look for next relop
rexprc0:	cpi	a,'>'	;Greater than?
	jnz	rexprc1	;If not , continue
	ori	c,0b00000010	;Set greater than bit 1
	jmp	rexprc3	;Look for next relop
rexprc1:	CPI	A,'='	;Equal?
	jnz	rexprc2	;If not, contiinue
	ori	c,0b00000100	;Set equal bit 2
	jmp	rexprc3	;Continue
rexprc2:	cpi	c,0b10000000	;First pass?
	jnc	err6	;Raise expected relop on first pass error
	jmp	rexprc4	;Continue
rexprc3:	inx	iram	;Point next relop operator (if any)
	cpi	c,0b10000000	;First pass?
	jc	rexprc4	;If not, then continue
	ani	c,0b00000111	;Mask off first pass bit and do second pass
	jmp	rexprl0	
rexprc4:	call	skipspace	;Get second value
	str	roflag,c	;Save C
	call	expr	
	call	sub	;Subtract the two values
	pop	l	;Result 0?
	pop	h	
	ldr	c,roflag	;Restore C
	mov	a,h	
	or	a,l	
	jnz	rexprc5	;If not, continue
	mov	a,c	;Equal bit set?
	ani	a,0b00000100	
	jnz	rexprT	;If so, process THEN
	ret		;If not, then done
rexprc5:	cpi	h,0b10000000	;Result<0?
	jc	rexprc6	;If not, continue
	mov	a,c	;Less than bit set?
	ani	a,0b00000001	
	jnz	rexprT	;If so, then process THEN
	ret		;If not, then done
rexprc6:	mov	a,c	;Greater than bit set?
	ani	a,0b00000010	
	jnz	rexprT	;If so, then process THEN
	ret		
rexprT:	pop	a	;Switch result to TRUE
	xri	a,0x01	
	push	a	
	ret		
;			
; Get Start of Line Matching Label DE into HL  (Carry set if found)			
;			
fndlbl:	ldr	l,prgstrt	;Get start of program in HL
	ldr	h,prgstrt+1	
	ldr	c,prgend	;Get end of program in BC
	ldr	b,prgend+1	
fndlbll:	cmp	h,b	;Reached end of program?
	jnz	fndlblc0	
	cmp	l,c	
	rz		;If so, return carry reset
fndlblc0:	cmp	m,d	;MS Byte match?
	jnz	fndlblc1	;If not,  skip to next line
	adi	l,1	;Point LS Byte
	aci	h,0	
	cmp	m,e	;LSB match?
	jnz	fndlblc2	;If not, skip to next line
	sui	l,1	;Fount it!
	sbi	h,0	;Point back to start of line
	stc		;Set carry
	ret		;Return
fndlblc1:	adi	l,1	;Point next byte (LSB)
	aci	h,0	
fndlblc2:	adi	l,1	;Point next byte (line length)
	aci	h,0	
	mov	a,m	;Get length of line in A
	add	l,a	;Compute new line start
	aci	h,0	
	jmp	fndlbll	;Try again
;			
;  Convert Number in HL to ASCII and Display It			
;			
;     zero_supr flag used to suppress output of leading zeros except when D is zero			
;			
numout:	push	a	;Save it
	push	d	;Save DE
	push	e	
	mvi	e,lo(10000)	;Display 10000's digit
	mvi	d,hi(10000)	
	call	cnvrt	
	mvi	e,lo(1000)	;Display 1000's digit
	mvi	d,hi(1000)	
	call	cnvrt	
	mvi	e,lo(100)	;Display 100's digit
	mvi	d,hi(100)	
	call	cnvrt	
	mvi	e,lo(10)	;Display 10's digit
	mvi	d,hi(10)	
	call	cnvrt	
	adi	l,48	
	mov	a,l	
	call	chrout	
	pop	e	;Restore DE and A
	pop	d	
	pop	a	
	ret		
;			
; Display Positional Digit in DE			
;			
cnvrt:	mvi	a,255	;Initialize count = -1
cnvrtl0:	adi	a,1	;Increment and store count
	sub	l,e	
	sbb	h,d	
	jnc	cnvrtl0	;If result not negative, subtract again
	add	l,e	
	adc	h,d	
	cmp	a,c	;Suppress zeros?
	rz		;If so, don't display the digit
	dcr	c	;Turn off zero suppression flag
	adi	a,48	Add ASCII bias
	jmp	chrout	;Display the digit
;			
;			
; Skip Spaces in Data Ram			
;			
skipspace:	ldx	a,(iram)	;Get character
	cpi	a,' '	;A space?
	rnz		;If not , return
	inx	iram	;Point next byte in Data RAM
	jmp	skipspace	;Repeat
;			
; Get Keyword - Return with carry if found & link position in C			
;			
getkey:	mov	d,iramh	;Get current start of text
	mov	e,iraml	
	lxi	irom,keytbl	;Point IROM to start of kewword table
getkeyl0:	mvi	c,0	;Zero keyword link table counter
getkeyl1:	mov	h,d	;Restore IRAM to start of text
	mov	l,e	
	ldhl	iram	
getkeyl2:	ldx	b,iram	;Get text byte
	adi	b,0xc0	;Non-alphabetic?
	rnc		;If so, done with carry reset
	adi	b,0x40	;Make alphabetic
	ani	b,0b11011111	;Make upper case
	ldx	a,(irom)	;Get key table byte
	ani	a,0b01111111	;Mask off MSBit
	cmp	a,b	;Same?
	jnz	getkeyc0	;If not, continue
	ldx	a,(irom)	;Get keyword byte
	cpi	a,0b10000000	;End of current keyword?
	jnc	getkeye1	;Found the keyword, continue
	inx	irom	;Point next text byte in Data RAM
	inx	iram	;Point next keyword byte in Data ROM
	ldx	a,(iram)	;Get text byte
	cpi	a,'A'	;Alphabetic?
	jnc	getkeyl2	;If so, try again
getkeye0:	mov	h,d	;Restore IRAM to start of text
	mov	l,e	
	ldhl	iram	
	and	a,a	;Not found. Reset carry and return
	ret		
getkeyc0:	ldx	a,(irom)	;Get keyword byte
	cpi	a,0b10000000	;End of keyword?
	inx	irom	;Point next byte in keyword table
	jc	getkeyc0	;Loop until end of keyword found
	ldx	a,(irom)	;Get keyword byte
	or	a,a	;End of keyword table?
	inx	iram	;Point next text byte in Data RAM
	jz	getkeye0	;If so, not found and return
	inr	c	;Increment keyword counter
	jmp	getkeyl1	;Keep looking in keyword table
getkeye1:	inx	iram	;Point next text byte in Data RAM
	stc		;Set carry
	ret		;Return
;			
; Get Keyword Address Link in HL given link position in C			
;			
getlink:	mvi	l,lo(linktbl)	;Point HL to start of link table
	mvi	h,hi(linktbl)	
	rlc	c	;Double C
	add	l,c	;Calculate address
	aci	h,0	
	ldhl	irom	;Transfer HL to IROM
	ldx	l,(irom)	;Get address
	inx	irom	
	ldx	h,(irom)	
	ret		
;			
; Math Package			
;			
expr:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'+'	;Is it a plus sign
	jnz	exprc0	;If not, continue
	inx	iram	;If so, ignore it
	jmp	exprc1	
exprc0:	ldx	a,(iram)	;Get next character in Data RAM
	cpi	a,'-'	;Is it a negation?
	jnz	exprc1	;If not, continue
	inx	iram	;Point to next character in Data RAM
	call	term	;If so, evaluate a term
	call	neg	;Negate the result
	jmp	exprc2	;Continue
exprc1:	call	term	
exprc2:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'+'	;Is it addition?
	jnz	exprc3	;If not, continue
	inx	iram	;Get next character in Data RAM
	call	term	
	call	add	
	jmp	exprc2	;Repeat
exprc3:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'-'	;Is it subtraction?
	jnz	exprc4	;If not, continue
	inx	iram	;Get next character in Data RAM
	call	term	
	call	neg	;Negate the result
	call	add	
	jmp	exprc2	
exprc4:	ret		
;			
term:	call	factor	
exprc5:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'*'	;Is it multiplication?
	jnz	exprc6	;If not, continue
	inx	iram	;Point to next character in Data RAM
	call	factor	
	call	mul	
	jmp	exprc5	;Repeat
;			
exprc6:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'/'	;Is it division?
	jnz	exprc7	;If not, continue
	inx	iram	;Point to next character in Data RAM
	call	factor	
	call	div	
	jmp	exprc5	;Repeat
;			
exprc7:	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'%'	;Is it modulo?
	jnz	exprc8	;If not, continue
	inx	iram	;Point to next character in Data RAM
	call	factor	
	call	modulo	
	jmp	exprc5	;Repeat
;			
exprc8:	ret		;Done
;			
factor:	call	getfnct	;Is it a function?
	rc		If so, put on PP stack and return
	call	getvar	;Is it a number?
	rc		;If so, put on PP stack and return
	call	getnum	;Is it a variable?
	rc		;If so, put on PP stack and return
 	ldx	a,(iram)	;Get character in Data RAM
	cpi	a,'('	;Open parentheses?
	jnz	err9	;If not, invalid expression
	inx	iram	;Point next character
	call	expr	;Call 
	cpi	a,')'	;Closed Parentheses
	jnz	err9	;If not, invalid expression
	inx	iram	;Point next character
	ret		
;			
; Skip space character in Data Data Ram			
;			
skspc:	ldx	a,(iram)	;Get the character
	cpi	a,' '	;Is it a space?
	rnz		;If not, return
	inx	iram	;Point next character in Data RAM
	jmp	skspc	;Repeat
;			
; Get Function Value on PP Stack			
;			
getfnct:	ldx	a,(iram)	;Get key number in A
	ani	a,0b01111111	;Mask off MS bit
	cpi	a,random	;Is it RND?
	jz	rndm	;If so, process it
	cpi	a,peekid	;Is it PEEK?
	jz	peek	;If so, process it
	sub	a,a	;Reset carry and return
	ret		
;			
;	RNDM - PUTS RANDOM NTEGER (0-10000) ON AE STACK		
;			
; Shift-register pseudorandom number generator calculating successive powers of seed4..seed1			
;			
rndm:	inx	iram	;Point next byte
	ldx	a,(iram)	;Get prigram byte
	cpi	a,'('	;Should be an open parentheses?
	jnz	err0	;If not, raise syntax error
	inx	iram	;Point next character
	call	expr	;Get option parameter
	call	skipspace	;Get next nonspace character
	cpi	a,')'	;Should be a closed parentheses
	jnz	err0	;If not, raise syntax error
	inx	iram	
	pop	l	
	pop	h	
	cpi	l,0	;Is it 0 - new random number?
	jz	rndml0	;If so, continue here
	cpi	l,1	;Is it 1 - randomize first
	jz	rndmz	;If so, continue here
	cpi	l,2	Is it 2 - restart the random sequence first
	jz	rndmrst	;If so, continue here
	jmp	err12	;Invalid function parameter error
rndml0:	mvi	h,0xff	;The 
	mvi	l,seed4	
	mvi	b,8	
rndml1:	mov	a,m	
	rlc	a	
	aci	a,0	
	rlc	a	
	aci	a,0	
	rlc	a	
	aci	a,0	
	xor	a,m	
	ral	a	
	ral	a	
	dcr	l	
	dcr	l	
	dcr	l	
	mov	a,m	
	ral	a	
	mov	m,a	
	inr	l	
	mov	a,m	
	ral	a	
	mov	m,a	
	inr	l	
	mov	a,m	
	ral	a	
	mov	m,a	
	inr	l	
	mov	a,m	
	ral	a	
	mov	m,a	
	dcr	b	
	jnz	rndml1	
	ldr	h,seed3	
	ldr	l,seed4	
	ani	h,0x03	
	cpi	h,0x03	
	jz	rndmc2	
rndmc1:	jnc	rndml0	
	push	h	
	push	l	
	stc		;Set carry and return
	ret		
rndmc2:	cpi	l,0xe8	
	jmp	rndmc1	
;			
peek:	inx	iram	;Point next byte
	ldx	a,(iram)	;Get program byte
	cpi	a,'('	;Should be an open parenthesis?
	jnz	err14	;If not, raise expected paren. Error
	inx	iram	;Point next byte
	call	expr	;Get the address
	pop	l	;Get address in HL
	pop	h	
	mov	a,m	;Get memory byte
	mvi	h,0	;Push on to PP stack
	push	h	
	push	a	
	ldx	a,(iram)	;Get program byte
	cpi	a,')'	;Should be closing parenthesis
	jnz	err14	;If not, raise expected paren. Error
	inx	iram	;Point next byte
	stc		;Set carry
	ret		
;			
; Randomize Seed			
;			
rndmz:	inp	a,2	
	str	seed1,a	
	ani	a,0x7	
rndmzl:	dcr	a	
	jnz	rndmzl	
	inp	a,2	
	ral	a	
	xri	a,0b10101010	
	str	seed2,a	
	jmp	rndml0	
;			
; Reset to Starting Random Seeds			
;			
rndmrst:	lxi	irom,seed_data	
	ldx	a,(irom)	
	str	seed1,a	
	inx	irom	
	ldx	a,(irom)	
	str	seed2,a	
	inx	irom	
	ldx	a,(irom)	
	str	seed3,a	
	inx	irom	
	ldx	a,(irom)	
	str	seed4,a	
	jmp	rndml0	
;			;
; Get Variable Address into HL			
;			
getvaradrs:	ldx	a,(iram)	;Get possible variable name
	adi	a,0xc0	;A-Z or a-z
	rnc		;Return if not
	inx	iram	;Point next character in Data RAM
	ani	a,0b00011111	;Mask lower bits
	dcr	a	;Adjust to zero base
	rlc	a	;Multiply by 2
	mvi	l,lo(varstrt)	;Calculate address
	mvi	h,hi(varstrt)	
	add	l,a	
	aci	h,0	
	ldx	a,(iram)	;An array? TBX
	cpi	a,'('	;Open parenthesis
	jz	arryadrs	
	stc		;Set carry
	ret		;Done and return
;			
arryadrs:	mov	e,m	;Get array start address in DE TBX start
	adi	l,1	
	aci	h,0	
	mov	d,m	
	push	d	;Save it on PP stack
	push	e	
	inx	iram	;Point next program byte
	call	expr	;Get array first index
	ldx	a,(iram)	;Get next byte
	cpi	a,')'	;Must be a closed parenthesis?
	jnz	err0	;If not, raise a syntax error
	inx	iram	;Point next program byte
	pop	e	;Get index in DE
	pop	d	
	pop	l	;Get array address in HL
	pop	h	
	rlc	e	;Double index
	ral	d	
	add	l,e	;Calculate array index address
	adc	h,d	
	stc		;Set carry and return
	ret		; TBX end
;			
; Get Variable Value on Stack			
;			
getvar:	call	getvaradrs	
	rnc		;Return if not a variable
	mov	a,m	;Get variable value
	adi	l,1	
	aci	h,0	
	mov	h,m	
	push	h	
	push	a	
	stc		;Set carry
	ret		
;			
; Get a Number			
;			
getnum:	ldx	a,(iram)	;Get first character
	cpi	a,'-'	;Is it a neagtive number?
	jnz	getnumc0	;If not, continue
	inx	iram	;Point next character in Data RAM
	ldx	a,(iram)	Get next character
	call	chknum	;Is this a numeric digit?
	rnc		;If not return with carry reset
	call	asc2bin	;Get number in HL
	call	twocmp	;Negate the result
	push	h	;Put result on stack
	push	l	
	stc		;Set carry
	ret		
getnumc0:	call	chknum	;Is this a numeric digit?
	rnc		;Return if not
	call	asc2bin	
	push	h	;Put result on stack
	push	l	
	stc		;Set carry and return
	ret		
;			
; Check for 0-9 and return carry set if so			
;			
chknum:	cpi	a,'9'+1	;Digit bigger than 9?
	rnc		;If so, it's not a digit and return with no carry
	cpi	a,'0'	;Digit smaller than 0?
	jc	chknumc	;If so, continue
	stc		;Set carry and return
	ret		
chknumc:	or	a,a	;Reset carry and return
	ret		
;			
; Store top of stack at variable next on stack			
;			
store:	pop	c	
	pop	b	
	pop	l	
	pop	h	
	mov	m,c	
	adi	l,1	
	aci	h,0	
	mov	m,b	
	and	a,a	
	ret		
;			
;	add - add top two values on ae stack		
;			
add:	pop	c	
	pop	b	
	pop	l	
	pop	h	
	add	l,c	
	adc	h,b	
	push	h	
	push	l	
	or	a,a	;Reset carry and return
	ret		
;			
;	sub - subtract top of ae stack from next value on ae stack		
;			
sub:	pop	l	
	pop	h	
	call	twocmp	
	mov	b,h	
	mov	c,l	
	pop	l	
	pop	h	
	add	l,c	
	adc	h,b	
	push	h	
	push	l	
	or	a,a	;Reset carry and return
	ret		
;			
;	mul - multiply top two two values on aestk		
;			
mul:	mvi	b,0	
	pop	l	
	pop	h	
	mov	a,h	
	cpi	a,0b10000000	
	jc	mulc0	
	call	ninox	
mulc0:	mov	e,l	
	mov	d,h	
	pop	l	
	pop	h	
	mov	a,h	
	cpi	a,0b10000000	
	jc	mulc1	
	call	ninox	
mulc1:	call	mult	
	dcr	b	
	jnz	mulc2	
	call	twocmp	
mulc2:	push	h	
	push	l	
	or	a,a	;Reset carry and return
	ret		
;			
ninox:	inr	b	
	jmp	twocmp	
;			
mult:	push	b	
	mov	b,h	
	mov	c,l	
	mvi	h,0	
	mvi	l,0	
	mvi	a,17	
multl:	rar	b	
	rar	c	
	jnc	multc	
	add	l,e	
	adc	h,d	
	stc		;Set carry
multc:	rar	h	
	rar	l	
	dcr	a	
	jnz	multl	
	mov	h,b	
	mov	l,c	
	pop	b	
	ret		
;			
;	div - divide top of aestk into the next value on the ae stack		
;			
div:	mvi	b,0	
	pop	l	
	pop	h	
	mov	a,h	
	cpi	a,0b10000000	
	jc	divc0	
	call	ninox	
divc0:	mov	e,l	
	mov	d,h	
	pop	l	
	pop	h	
	mov	a,h	
	cpi	a,0b10000000	
	jc	divc1	
	call	ninox	
divc1:	call	xhlde	
	cpi	h,0	
	jnz	divc	
	cpi	l,0	
	jz	err8	
divc:	call	divd	
	dcr	b	
	jnz	divc2	
	call	twocmp	
divc2:	push	h	
	push	l	
	or	a,a	;Reset carry and return
	ret		
;			
divd:	push	b	
	mvi	b,1	
divdl1:	mov	a,h	
	ani	a,0x40	
	jnz	divdc0	
	add	l,l	
	adc	h,h	
	inr	b	
	jmp	divdl1	
divdc0:	str	count,b	
	mov	b,h	
	mov	c,l	
	mvi	h,0	
	mvi	l,0	
divdl2:	sub	e,c	
	sbb	d,b	
	jnc	divdc2	
	add	e,c	
	adc	d,b	
	add	l,l	
	adc	h,h	
	ldr	a,count	
	dcr	a	
	jz	divde	
divdc1:	str	count,a	
	call	xhlde	
	add	l,l	
	adc	h,h	
	call	xhlde	
	jmp	divdl2	
divde:	pop	b	
	ret		
divdc2:	add	l,l	
	adc	h,h	
	adi	l,1	
	aci	h,0	
	ldr	a,count	
	dcr	a	
	jz	divde	
	jmp	divdc1	
;			
; Modulo			
;			
modulo:	pop	l	;Get dividend off PP stack
	pop	h	
	pop	e	;Get divisor of PP stack
	pop	d	
	push	d	;Push dividend on PP stack twice
	push	e	
	push	h	
	push	l	
	push	d	;Push divisor on PP stack
	push	e	
	push	h	
	push	l	
	call	div	;Perform integer division
	call	mul	;Multiply the two values
	jmp	sub	;Subtract the two values
;			
;	neg - negate the top of ae stack		
;			
neg:	pop	l	
	pop	h	
	call	twocmp	
	push	h	
	push	l	
	or	a,a	;Reset carry and return
	ret		
;			
;	twocmp - takes 2's complement of hl		
;			
twocmp:	xri	h,0xff	
	xri	l,0xff	
	adi	l,1	
	aci	h,0	
	ret		
;			
xhlde:	mov	a,d	
	mov	d,h	
	mov	h,a	
	mov	a,e	
	mov	e,l	
	mov	l,a	
	ret		
;			
;  Cold boot initialization			
;			
cinit:	lxi	irom,init_data	;Copy initialization data to RAM
	lxi	iram,curlbl+0xff00	
cinitl:	ldx	a,(irom)	
	stx	iram,a	
	inx	irom	
	inx	iram	
	cpi	irom,keytbl	
	jnz	cinitl	
zerovar:	lxi	iram,varstrt	;Zero A-Z variables
	mvi	b,0	
	mvi	a, 26*2	
cinitcl:	stx	iram,b	
	inx	iram	
	dcr	a	
	jnz	cinitcl	
	ret		
;			
;  Warm boot initialization			
;			
winit:	ret		
;			
; Get a line - statement or command			
;			
getline:	mvi	a,'>'	;Display prompt
	call	chrout	
;			
;	buffer input		
;			
bufin:	lxi	iram, bufstrt	;Copy inputted characters to input buffer
	mvi	b, 72	;Set maximum line length
bufinl:	call	chrin	
;	cpi	a,eol	;At end of input line?
	cpi	a,cr	;At end of input line? BYOC 24
	jz	bufend	;If so, go process
	cpi	a,bs	;A backspace?
	jz	rubout	;If so, do a rubout
	stx	iram,a	;Otherwise, strore it in Data RAM
	inx	iram	;Point next position in Data RAM
	dcr	b	;Reduce chacter count by 1
	jz	err1	;If line length exceeded, generate error
	jmp	bufinl	;Get next character
bufend:	mvi	a,cr	;Store last character and return
	stx	iram,a	
	mvi	a,0	
	str	zone,a	
	cpi	b,72	;Buffer empty?
	jz	getline	;If so, do nothing
	ret	0	
;			
; BYOC 24 Rubout code			
;			
rubout:	cpi	b,72	;At beginning of line?
	jz	bufinl	;If so, do nothing
	mvi	a,' '	;Send Esc
	call	chrout	
	mvi	a,bs	;Send ]
	call	chrout	
	dcx	iram	;Otherwise, back up on position
	inr	b	
	jmp	bufinl	
;			
; Translate Input Line			
;			
trns:	lxi	iram,bufstrt	;Point IRAM to input buffer start
	mvi	h,hi(bufstrt)	;Point HL to input buffer start
	mvi	l,lo(bufstrt)	
trnsl0:	ldx	a,(iram)	;Get byte
	cpi	a,cr	;Reached end of line?
	jz	trnse	;If so, done
	cpi	a,'"'	;A literal?
	jz	trnsc1	;If so, copy it ignoring text
	push	a	;Check for keyword
	push	h	
	push	l	
	call	getkey	;Is it a keyword?
	pop	l	
	pop	h	
	pop	a	
	jnc	trnsc0	;If not, copy byte as is
	adi	c,0b10000000	;If a keyword, set MS bit
	mov	m,c	;Store it back in input buffer
	adi	l,1	;Increment HL
	aci	h,0	
	jmp	trnsl0	;Process next byte
trnsc0:	mov	m,a	;Store byte in input buffer
	inx	iram	;Point next byte
	adi	l,1	
	aci	h,0	
	jmp	trnsl0	;Process next byte
trnsc1:	mov	m,a	;Store byte back  in input buffer
	inx	iram	;Point next byte
	adi	l,1	
	aci	h,0	
	ldx	a,(iram)	;Get next program byte
	cpi	a,'"'	;Ending quotation mark?
	jz	trnsc2	;If so, continue looking for keywords
	cpi	a,cr	
	jz	err5	;Raise expected closed quote error
	jmp	trnsc1	;Keep looking for closed quote
trnsc2:	mov	m,a	;Store byte back in input buffer
	inx	iram	;Point next byte
	adi	l,1	
	aci	h,0	
	jmp	trnsl0	;Back for more keyword checks
trnse:	mov	m,a	;Update line end  (cr)
	ret		;Done
;			
; Print Keyword  TBXC			
;			
keyout:	lxi	irom,keytbl	;Point IROM to start of keyword table
	ani	a,0b01111111	;Mask off MSBit
keyoutl0:	or	a,a	;Found the keyword?
	jz	keyoutc1	;If so, continue
	dcr	a	;Decrement keyword counter
keyoutl1:	ldx	c,(irom)	;Get keyword byte
	cpi	c,0b10000000	;Last character of keyword?
	jnc	keyoutc0	;If so, continue
	inx	irom	;Increment IROM
	jmp	keyoutl1	;Do again
keyoutc0:	inx	irom	;Increment IROM
	jmp	keyoutl0	;Do again
keyoutc1:	ldx	a,(irom)	;Print character
	cpi	a,0b10000000	;Last character of keyword?
	jnc	keyoute	;If so, continue
	call	chrout	;Print it
	inx	irom	;Increment IROM
	jmp	keyoutc1	;Do again
keyoute:	ani	a,0b01111111	;Mask off MSBit
	jmp	chrout	
;			
; Label Test Routine			
;			
; Is there a numeric label in buffer?			
;			
;  If so, store label in binary in curlbl and return with carry set.			
 ; If not, store 0 in curlbl and return with carry reset			
;			
tstl:	lxi	iram,bufstrt	;Prepare to scan line buffer
skipspc:	ldx	a,(iram)	;Skip any spaces
	cpi	a,' '	
	inx	iram	
	jz	skipspc	
	dcx	iram	
	mov	l,iraml	;Assume a command
	mov	h,iramh	
	str	txtstrt,l	
	str	txtstrt+1,h	
	mvi	l,0	
	mvi	h,0	
	str	curlbl,l	
	str	curlbl+1,h	
	cpi	a,':'	;Is it a command (non-numeric character)?
	rnc		;If so, return with no carry and curlbl=0
	cpi	a,'0'	;Is what is left is non-numeric?
	jnc	lbl	
	or	a,a	;Reset carry and return
	ret		
	jc	err0	;If so, then it's a syntax error
lbl:	call	asc2bin	;If numeric, capture and store in curlbl
	str	curlbl,l	
	str	curlbl+1,h	
	mov	e,iraml	
	mov	d,iramh	
	str	txtstrt,e	
	str	txtstrt+1,d	
	stc		;Set carry and return
	ret		
;			
; Convert ASCII to Binary			
;			
asc2bin:	mvi	h,0	
	mvi	l,0	
asc2binl:	ldx	a,(iram)	;Get program byte
	call	chknum	;Get value
	rnc		;Done when non-ASCII digit encountered
	ani	a,0b00001111	;Strip back to numeric value
	cpi	a,10	;Is value greater than 10?
	rnc		;If so, done and return
	inx	iram	;Point to next character
	mov	b,h	;Multiply HL by 10
	mov	c,l	
	add	l,l	;2*HL
	adc	h,h	
	jc	err2	;Overflow error
	add	l,l	;4*HL
	adc	h,h	
	jc	err2	;Overflow error
	add	l,c	;5*HL
	adc	h,b	
	jc	err2	;Overflow error
	add	l,l	;10*HL
	adc	h,h	
	jc	err2	;Overflow error
	add	l,a	;10*HL+new digit value
	aci	h,0	
	jc	err2	;Overflow error
	jmp	asc2binl	
;			
;	line insertion routine		
;			
;	inserts a new line; deletes if only line number; or overwrites.		
;			
insrt:	push	d	;Save DE
	push	e	
	ldr	l,txtstrt	;Get text start address in IRAM
	ldr	h,txtstrt+1	
	ldhl	iram	;Point IRAM to text
	ldr	l,curlbl	
	ldr	h,curlbl+1	
	or	a,l	
	jz	err3	;If a command, error
	mov	b,h	;Save label of new line
	mov	c,l	
;			
insrtf1:	mvi	d,1	;Count charaters in new line
insrtl2:	ldx	a,(iram)	
	cpi	a,cr	
	jz	insrtc1	
	inr	d	
	inx	iram	
	jmp	insrtl2	
insrtc1:	str	count,d	;Store count of new line
	ldr	l,txtstrt	;Point HL to program start
	ldr	h,txtstrt+1	
	ldhl	iram	;Point IRAM to start of text
	ldr	l,prgstrt	;Point HL to program start
	ldr	h,prgstrt+1	
insrtl4:	call	ckpend	;Program end same as program begin?
	jz	append	;If so, then append new line
	cmp	m,b	;Compare MSB old line and new line labels
	jz	insrtc2	;If the same, go check LSBs
	jnc	here	;If new line label greater, insert new line here
	adi	l,1	;Otherwise, point to next old line (inx hl)
	aci	h,0	
insrtl3:	adi	l,1	; (inx HL)
	aci	h,0	
	add	l,m	;Add count to point next old line
	aci	h,0	
	jmp	insrtl4	;Then try again
;			
insrtc2:	adi	l,1	;Point to LSB of old line label
	aci	h,0	
	cmp	m,c	;Compare LSB of old line to new line
	jz	ovrdel	;Labels are same, delete old then insert new
	jc	insrtl3	;If new line label less, keep looking
	sui	l,1	;Point back to start of old line
	sbi	h,0	
here:	sui	l,1	
	sbi	h,0	
	mov	e,iraml	;Save start of new line text
	mov	d,iramh	
	push	d	
	push	e	
	mov	d,h	
	mov	e,l	
	ldr	l,prgend	;Point IRAM to new insertion point
	ldr	h,prgend+1	
	push	h	
	push	l	
	ldr	a,count	;Compute new program end
	adi	a,3	
	add	l,a	
	aci	h,0	
	call	memtest	;Check for out of memory error
	jc	err15	;If so, raise out of memory error
	ldhl	iram	
	str	prgend,l	;Update program end
	str	prgend+1,h	
	pop	l	
	pop	h	
insrtl5:	mov	a,m	
	stx	iram,a	
	dcx	iram	
	sui	l,1	
	sbi	h,0	
	mov	a,iramh	
	cmp	a,d	
	jnz	insrtl5	
	mov	a,iraml	
	cmp	a,e	
	jnz	insrtl5	
	adi	e,1	
	aci	d,0	
	mov	h,d	
	mov	l,e	
	ldhl	iram	
	ldr	e,curlbl	
	ldr	d,curlbl+1	
	stx	iram,d	
	inx	iram	
	stx	iram,e	
	inx	iram	
	ldr	a,count	
	inr	a	
	stx	iram,a	
	inx	iram	
	pop	l	
	pop	h	
insrtl6:	mov	a,m	
	stx	iram,a	
	cpi	a,cr	
	jz	insrte	
	inx	iram	
	adi	l,1	
	adi	h,0	
	jmp	insrtl6	
insrte:	pop	d	
	ret		
;			
ovrdel:	sui	l,1	;
	sbi	h,0	
	push	h	
	push	l	
	adi	l,3	
	aci	h,0	
insrtl7:	cpi	m,cr	
	jz	insrtc3	
	adi	l,1	
	aci	h,0	
	jmp	insrtl7	
;			
insrtc3:	adi	l,1	
	aci	h,0	
	mov	d,h	
	mov	e,l	
	ldr	l,prgend	
	ldr	h,prgend+1	
	cmp	h,d	;At last line?
	jnz	insrtc4	;If not, continue
	cmp	l,e	
	jnz	insrtc4	;If not, continue
	pop	l	;Get new program end into HL
	pop	h	
	jmp	insrtc5	;If so, done
insrtc4:	adi	l,1	
	aci	h,0	
	mov	b,h	
	mov	c,l	
	mov	h,d	
	mov	l,e	
	ldhl	iram	
	pop	l	
	pop	h	
insrtl8:	ldx	a,(iram)	
	mov	m,a	
	adi	l,1	
	aci	h,0	
	inx	iram	
	mov	d,iramh	
	cmp	d,b	
	jnz	insrtl8	
	mov	e,iraml	
	cmp	e,c	
	jnz	insrtl8	
	sui	l,1	
	sbi	h,0	
insrtc5:	str	prgend,l	
	str	prgend+1,h	
	ldr	a,count	
	cpi	a,1	
	jnz	insrt+2	
	pop	e	
	pop	d	
	ret		
;			
append:	mov	m,b	;Put MSB of curlbl in new program line
	adi	l,1	
	aci	h,0	
	mov	m,c	;Put LSB of curlbl in new program line 
	adi	l,1	
	aci	h,0	
	ldr	a,count	;Put line count+1 in new program line
	inr	a	
	mov	m,a	
	dcx	iram	;Point new line back one byte
appendl:	adi	l,1	;Point next old line byte
	aci	h,0	
	inx	iram	;Point next new line
	ldx	a,(iram)	;Get new byte
	mov	m,a	;Put in new line
	cpi	a,13	;Carriage return?
	jnz	appendl	;If not, keep adding new bytes
	adi	l,1	;If so, point next new line byte 
	aci	h,0	
	str	prgend,l	;Update program end
	str	prgend+1,h	
	pop	e	;Restore DE
	pop	d	
	ret		
;			
ckpend:	ldr	a,prgend+1	;NEW LINE INSERTED; DONE
	cmp	a,h	
	rnz		;DELETE CURRENT PROGRAM LINE
	ldr	a,prgend	
	cmp	a,l	;CR?
	ret		
;			
;  Check if HL address is beyond end of memory			
;			
memtest:	ldr	a,mend+1	;Program end exceeds memory end?
	cmp	a,h	;Check MSB of memory end
	jz	memtstc	;Same, check LSB
	rc		;If so, return with carry set
memtstc:	ldr	a,mend	;Check LSB of memory end
	cmp	a,l	;Past memory end?
	rnc		;If not, return with carry reset
	stc		;set
	ret		;Return with carry set
;			
; Get keyboard character into A			
;			
chrin:	inp	a,cntr_port	;Get keyboard/display control byte
	ani	a,kby_mask	;Character available?
	jz	chrin	;If not, keep checking
	inp	a,data_port	;Input ASCII character
	cpi	a,escape	;Escape code?
	jz	wstart	;If so, do a warm start
;			
; Print character in A			
;			
chrout:	push	a	;Save character to print
	ldr	a,zone	;Increment zone counter
	inr	a	
	str	zone,a	
wait:	inp	a,cntr_port	;Get keyboard/display control byte
	ani	a,dsp_mask	;Display busy
	jnz	wait	;If so, keep checking
	pop	a	;Restore character to print
	out	data_port,a	;Output ASCII character
	ret		;Done and return
;			
;  Display New Line			
;			
newline:	mvi	a,0	
	str	zone,a	
;	mvi	a,eol	
	mvi	a,cr	;BYOC 24
	jmp	chrout	
;			
;  Clear Screen Routine - BYOC 24			
;			
clrscr:	mvi	a,27	
	call	chrout	
	mvi	a,93	
	call	chrout	
	mvi	a,82	
	jmp	chrout	
;			
; Display message in Data ROM at IROM			
;			
msgout:	ldx	a,(irom)	
	or	a,a	
	rz		
	call	chrout	
	inx	irom	
	jmp	msgout	
;			
; Warm Boot			
;			
warm_boot:	jmp	warm_boot	
;			
; Error Processing			
;			
err0:	mvi	l,0	;Syntax error
	jmp	error	
err1:	mvi	l,1	;Line overflow
	jmp	error	
err2:	mvi	l,2	;Numeric overflow
	jmp	error	
err3:	mvi	l,3	;Badly formed command
	jmp	error	
err4:	mvi	l,4	;Expected end of line
	jmp	error	
err5:	mvi	l,5	;Expected closed quote
	jmp	error	
err6:	mvi	l,6	;Unknown line number
	jmp	error	
err7:	mvi	l,7	;Expected variable name
	jmp	error	
err8:	mvi	l,8	;Divide by zero
	jmp	error	
err9:	mvi	l,9	;Invalid expression+D612
	jmp	error	
err10:	mvi	l,10	;Expected variable
	jmp	error	
err11:	mvi	l,11	;No program to load
	jmp	error	
err12:	mvi	l,12	;Invalid function parameter
	jmp	error	
err13:	mvi	l,13	;Expected number
	jmp	error	
err14:	mvi	l,14	;Expected parenthesis
	jmp	error	
err15:	mvi	l,15	;Out of memory
	jmp	error	
err16:	mvi	l,16	;Invalid array index
	jmp	error	
err17:	mvi	l,17	;Invalid array (dimension conflict)
	jmp	error	
;			
; Error Processor			
;			
error:	call	newline	;Next line
	lxi	irom,msg_err0	
	call	msgout	
	mvi	h,0	
	mvi	c,0	
	call	numout	
	lxi	irom,msg_err1	
	call	msgout	
	ldr	l,curlbl	
	ldr	h,curlbl+1	
	mvi	c,0xff	
	call	numout	
	jmp	wstart	
;			
data			
;			
;   Program Equates			
;			
cr	equ	13	;Carriage return character
lf	equ	10	;Line feed character
eol	equ	10	;End-of-line character
cntr_l	equ	12	;Clear screen character
space	equ	32	;space character
bs	equ	8	;Backspace character
cntr_port	equ	0	;Terminal Unit control port
kby_mask	equ	0b01000000	;Character available on bit 6
dsp_mask	equ	0b10000000	;Display busy on bit 7
data_port	equ	1	;Terminal Unit data port
escape	equ	27	;Escape code (BYOC 24)
nmlines	equ	4	;Lines to switch to linear search
;			
;  Data RAM Map			
;			
ram_start	equ	0	;Start of Data RAM
;			
bufstrt	equ	ram_start	;Keyboard input buffer
;			
varstrt	equ	bufstrt+72	;Space for 26 16-bit (two byte) variables A-Z
;			
prgmem	equ	varstrt+52	;Start of Tiny BASIC program space
;			
curlbl	equ	0	;Current line number
prgstrt	equ	curlbl+2	;First byte of Tiny BASIC program
prgend	equ	prgstrt+2	;Last byte of Tiny BASIC program + 1
txtstrt	equ	prgend+2	;Start of text for curent line
count	equ	txtstrt+2	;Length of text in keybord input buffer
case	equ	count+1	;Reserve for future use
zone	equ	case+1	;Zone counter
arrystrt	equ	zone+1	;Array start TBX
lnmtblstrt	equ	arrystrt+2	;Start of line number table
lnmtblend	equ	lnmtblstrt+2	;End of line number table
ltxtstrt	equ	lnmtblend+2	;Line text start
seed1	equ	ltxtstrt+2	;RANDOM NUMBER SEED 1
seed2	equ	seed1+1	;RANDOM NUMBER SEED 2
seed3	equ	seed2+1	;RANDOM NUMBER SEED 3
seed4	equ	seed3+1	;RANDOM NUMBER SEED 4
mend	equ	seed4+1	;End of program memory
;			
; Temporary Storage Variables			
;			
roflag	equ	mend+2	
inptr	equ	roflag+1	
lnmtbllow	equ	inptr+2	
lnmtblhigh	equ	lnmtbllow+2	
;			
memend	equ	0xfeff	
;			
; Data ROM Map			
;			
init_data:	db	0,0	;Assume 0 current line number
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	1	;Assume length of text in keyboard input buffer is 1
	db	0x20	;Reserve for future use
	db	0	;Zone counter starts at 0
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
	db	lo(prgmem),hi(prgmem)	;First byte of Tiny BASIC program
seed_data:	db	0x68	;RANDOM NUMBER SEED 1
	db	0x85	;RANDOM NUMBER SEED 2
	db	0xe1	;RANDOM NUMBER SEED 3
	db	0xd6	;RANDOM NUMBER SEED 4
	db	lo(memend),hi(memend)	;Current memory end
;			
; Keyword Table			
;			
keytbl:	db	'R','P','T'+128	
	db	'L','E','T'+128	
	db	'I','F'+128	
	db	'T','H','E','N'+128	
	db	'G','O','T','O'+128	
	db	'G','O','S','U','B'+128	
	db	'R','E','T','U','R','N'+128	
	db	'P','R','I','N','T'+128	
	db	'I','N','P','U','T'+128	
	db	'R','U','N'+128	
	db	'R','E','M'+128	
	db	'D','I','M'+128	
	db	'R','E','A','D'+128	
	db	'C','L','R'+128	
	db	'L','I','S','T'+128	
	db	'S','T','O','P'+128	
	db	'N','E','W'+128	
	db	'L','O','A','D'+128	
	db	'R','N','D'+128	
	db	'P','O','K','E'+128	
	db	'P','E','E','K'+128	
	db	0	
;			
; Keyword Link Table			
;			
linktbl:	db	lo(rpt),hi(rpt)	;RPT-REPEAT
	db	lo(let),hi(let)	;LET
	db	lo(if),hi(if)	;IF
	db	lo(then),hi(then)	;THEN
golink:	db	lo(goto),hi(goto)	;GOTO
goslink:	db	lo(gosub),hi(gosub)	;GOSUB
	db	lo(return),hi(return)	;RETURN
	db	lo(print),hi(print)	;PRINT
	db	lo(input),hi(input)	;INPUT
	db	lo(run),hi(run)	;RUN
	db	lo(rem),hi(rem)	;REM
	db	lo(dim),hi(dim)	;DIM
	db	lo(read),hi(read)	;READ
	db	lo(clr),hi(clr)	;READ
	db	lo(list),hi(list)	;LIST
	db	lo(stop),hi(stop)	;STOP
	db	lo(new),hi(new)	;NEW
	db	lo(load),hi(load)	;LOAD
rndlink:	db	lo(err0),hi(err0)	;RND Function
	db	lo(poke),hi(poke)	;POKE
peeklink:	db	lo(err0),hi(err0)	;PEEK Function
	db	0	
;			
random	equ	(rndlink-linktbl)/2	
peekid	equ	(peeklink-linktbl)/2	
gokeynm	equ	(golink-linktbl)/2	
goskeynm	equ	(goslink-linktbl)/2	
;			
;			
; Displayed Messages			
;			
msg_wel:	ds	Tiny BASIC Extended for BYOC-24 CPU Version 1.0	
msg_stop:	ds	STOP at line 	
msg_err0:	ds	Error 	
msg_err1:	ds	  at line 	
;			
; Preloaded Programs			
;			
preprgm:	ds	10 clr:print "Tiny BASIC Programs":print	;Program 0
	ds	30 print "load 0 - TBX Program Index"	
	ds	31 print "load 1 - High/Low Guessing Game"	
	ds	32 print "load 2 - Equation Demo"	
	ds	33 print "load 3 - Squares Demo"	
	ds	34 print "load 4 - Array Demo"	
	ds	35 print "load 5 - Life"	
	ds	36 print "load 6 - Life Revised"	
	db	0xfe	Program 1
	ds	5 e=rnd(1)	
	ds	10 print	
	ds	15 print "High/Low Guessing Game"	
	ds	20 print	
	ds	25 e=rnd(0)%100	
	ds	30 t=1	
	ds	35 print "I am thinking of a number between 1 and 100."	
	ds	40 print "Your guess";	
	ds	45 input g	
	ds	50 if g>e then goto 70	
	ds	55 if g<e then goto 80	
	ds	60 print "You got it in ";t;"tries"	
	ds	65 goto 10	
	ds	70 print "Too high.  Try again."	
	ds	75 goto 85	
	ds	80 print "Too low. Try again"	
	ds	85 t=t+1	
	ds	90 goto 40	
	db	0xfe	;Program 2
	ds	10 a=10	
	ds	20 b=2	
	ds	30 c=3	
	ds	40 d=-2*(16/b+3*a*(c+4*b/(c-b))+16)	
	ds	50 print d	
	db	0xfe	;Program 3
	ds	10 print "Print Squares Demo"	
	ds	20 print	
	ds	30 print "Enter starting number";	
	ds	40 input s	
	ds	50 print "Enter ending number";	
	ds	60 input e	
	ds	70 print	
	ds	80 print "Number","Square"	
	ds	90 print s,s*s	
	ds	100 s=s+1	
	ds	110 if s<=e then goto 90	
	ds	120 stop	
	db	0xfe	;Program 4
	ds	10 dim a(10),b(10)	
	ds	20 i=0:j=0	
	ds	30 a(i)=i+1:b(j)=j*j	
	ds	40 i=i+1:j=j+1	
	ds	50 if i<10 then 30	
	ds	60 i=0:j=0	
	ds	70 print a(i),b(j)	
	ds	80 i=i+1:j=j+1	
	ds	90 if i<10 then 70	
	ds	100 stop	
	db	0xfe	;Program 5
	ds	5 DIM V(512)	
	ds	10 B=0:GOSUB 900:CLR	
	ds	15 B=B+1:GOSUB 800	
	ds	20 GOSUB 700	
	ds	70 M=0	
	ds	80 N=0	
	ds	90 A=0	
	ds	100 I=M-1	
	ds	110 J=N-1	
	ds	120 GOSUB 200:J=J+1:IF J<=N+1 THEN GOTO 120	
	ds	130 I=I+1:IF I<=M+1 THEN GOTO 110	
	ds	140 GOSUB 300	
	ds	150 N=N+1:IF N<=15 THEN GOTO 90	
	ds	160 M=M+1:IF M<=15 THEN GOTO 80	
	ds	170 GOTO 15	
	ds	200 IF I=M THEN IF J=N THEN RETURN	
	ds	205 K=I+16:L=J	
	ds	210 IF K<16 THEN K=31	
	ds	215 IF K>31 THEN K=16	
	ds	220 IF J<0 THEN L=15	
	ds	225 IF J>15 THEN L=0	
	ds	230 A=A+V(16*K+L)	
	ds	240 RETURN	
	ds	300 IF V(16*M+N)=0 THEN IF A=3 THEN V(16*M+N)=1	
	ds	305 IF V(16*M+N)=1 THEN IF A<2 THEN V(16*M+N)=0	
	ds	310 IF V(16*M+N)=1 THEN IF A>3 THEN V(16*M+N)=0	
	ds	315 RETURN	
	ds	700 I=16:J=0	
	ds	705 C=0	
	ds	710 V(16*I+C)=V(16*J+C):C=C+1:IF C<15 THEN GOTO 710	
	ds	715 I=I+1:J=J+1:IF J<15 THEN GOTO 705	
	ds	720 RETURN	
	ds	800 CLR	
	ds	810 M=0	
	ds	815 N=0	
	ds	820 IF V(16*M+N)=0 THEN PRINT " ";:GOTO 830	
	ds	825 PRINT "*";	
	ds	830 N=N+1:IF N<15 THEN GOTO 820	
	ds	835 PRINT	
	ds	840 M=M+1: IF M<15 THEN GOTO 815	
	ds	845 PRINT "GEN ";B	
	ds	850 RETURN	
	ds	900 I=5:J=7:V(16*I+J)=1	
	ds	910 I=6:J=6:V(16*I+J)=1:J=7:V(16*I+J)=1:J=8:V(16*I+J)=1	
	ds	920 I=7:J=6:V(16*I+J)=1:J=8:V(16*I+J)=1	
	ds	930 I=8:J=6:V(16*I+J)=1:J=7:V(16*I+J)=1:J=8:V(16*I+J)=1	
	ds	940 I=9:J=7:V(16*I+J)=1	
	ds	950 RETURN	
	db	0xfe	;Program 6
	ds	5 DIM V(512)	
	ds	10 B=0:GOSUB 900:CLR	
	ds	15 B=B+1:GOSUB 800	
	ds	20 GOSUB 700	
	ds	70 M=0	
	ds	80 N=0	
	ds	90 A=0	
	ds	100 I=M-1	
	ds	110 J=N-1	
	ds	120 GOSUB 200:J=J+1:RPT J<=N+1:I=I+1:J=N-1:RPT I<=M+1	
	ds	130 REM	
	ds	140 GOSUB 300	
	ds	150 N=N+1:IF N<=15 THEN GOTO 90	
	ds	160 M=M+1:IF M<=15 THEN GOTO 80	
	ds	170 GOTO 15	
	ds	200 IF I=M THEN IF J=N THEN RETURN	
	ds	205 K=I+16:L=J	
	ds	210 IF K<16 THEN K=31	
	ds	215 IF K>31 THEN K=16	
	ds	220 IF J<0 THEN L=15	
	ds	225 IF J>15 THEN L=0	
	ds	230 A=A+V(16*K+L)	
	ds	240 RETURN	
	ds	300 IF V(16*M+N)=0 & A=3 THEN V(16*M+N)=1	
	ds	305 IF V(16*M+N)=1 & A<2 THEN V(16*M+N)=0	
	ds	310 IF V(16*M+N)=1 & A>3 THEN V(16*M+N)=0	
	ds	315 RETURN	
	ds	700 I=16:J=0	
	ds	705 C=0	
	ds	710 V(16*I+C)=V(16*J+C):C=C+1:RPT C<15:I=I+1:J=J+1:C=0:RPT j<15	
	ds	715 REM	
	ds	720 RETURN	
	ds	800 CLR	
	ds	810 M=0	
	ds	815 N=0	
	ds	820 IF V(16*M+N)=0 THEN PRINT " ";:GOTO 830	
	ds	825 PRINT "*";	
	ds	830 N=N+1:IF N<15 THEN GOTO 820	
	ds	835 PRINT	
	ds	840 M=M+1: IF M<15 THEN GOTO 815	
	ds	845 PRINT "GEN ";B	
	ds	850 RETURN	
	ds	900 I=5:J=7:READ    V(16*I+J)=1	
	ds	910 I=6:J=6:READ V(16*I+J)=1,1,1	
	ds	920 I=7:J=6:READ V(16*I+J)=1,0,1	
	ds	930 I=8:J=6:READ V(16*I+J)=1,1,1	
	ds	940 I=9:J=7:READ     V(16*I+J)=1	
	ds	950 RETURN	
	db	0xfe,0xff	
;			
; Data End			
;			
end			

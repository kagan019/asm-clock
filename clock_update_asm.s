.data
hr_per_day:
    .int 24
min_per_hr:
    .int 60
sec_per_min:
    .int 60

.text
.global  set_tod_from_secs
		
set_tod_from_secs:
    # int time_of_day_sec: 		%edi
    # tod_t *tod:				%rsi

    # bounds checking
    cmpl    $0,%edi   
    jl      .ERROR                  # .ERROR if time_of_day_sec < 0
    movl    hr_per_day(%rip),%eax
    imull   min_per_hr(%rip)
    imull   sec_per_min(%rip)       # %eax holds the product sec_per_min * min_per_hr * hr_per_day
    cmpl    %eax,%edi
    jge     .ERROR					# jump if $eax >= %edi

	# hours
    movl    min_per_hr(%rip),%eax
    imull   sec_per_min(%rip)
    movl    %eax,%r8d               # (sec_per_min * min_per_hr) is divisor
    movl    %edi,%eax               # time_of_day_sec is dividend     
    cqto
    idivl   %r8d					# quotient = number of full hours passed today
    movl    %eax,%r9d               # %r9d = num_hours = (short)quotient
	movl	%edx,%edi				# time_of_day_sec now equals remainder 
	# convert integer hours to clock hours
	movl    %r9d,%eax 
    addl    $11,%eax
    movl    $12,%r8d				# 12 is divisor
    cqto
    idivl   %r8d
    addl    $1,%edx                 # convert number of hours to the hour of the day
    movw    %dx,0(%rsi)             # tod->hours = (short)the hour of the day
    #tod->hours, 0(%rsi), is now set appropriately for the clock
	
	# am/pm
    movl    %r9d,%eax
    cqto    
    idivl   %r8d					# 12 is divisor
    movb    %al,6(%rsi)             # tod->ispm = (char)(tod->hours / 12)
    
    # minutes
    movl    %edi,%eax
    cqto
    idivl   sec_per_min(%rip)      
    movw    %ax,2(%rsi)             #tod->minutes = (short) (time_of_day_sec / sec_per_min) 

    # seconds
    movw    %dx,4(%rsi)             #tod->seconds = (short)reminder of last division;

	jmp	  .SUCCESS	







.data
# display left shifts
minute_ones:
	.int 0
minute_tens:
	.int 7
hour_ones:
	.int 14
hour_tens:
	.int 21
am_pm:
	.int 28
#display masks
num_masks:
	.int 0b00111111 #0
	.int 0b00000110 #1
	.int 0b01011011 #2
	.int 0b01001111 #3
	.int 0b01100110 #4
	.int 0b01101101 #5
	.int 0b01111101 #6
	.int 0b00000111 #7
	.int 0b01111111 #8
	.int 0b01101111 #9
ampm_masks:
	.int 0b01    #am
	.int 0b10    #pm

#tod right shifts
tod_hours:
	.int 0
tod_minutes:
	.int 16
tod_seconds:
	.int 32
tod_ispm:
	.int 48


.text
.global  set_display_bits_from_tod

set_display_bits_from_tod:
	# tod_t tod:		%rdi
	# int *display: 	%rsi

	# register aliases for indexing the arrays (these won't change)
	leaq	ampm_masks(%rip),%r8
	leaq	num_masks(%rip),%r9

	# bounds checking
	movq	%rdi,%rax
	movb	tod_hours(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFFFF,%rax				# %rax = tod.hours
	cmpq	$0,%rax
	jl		.ERROR
	cmpq	$12,%rax
	jg		.ERROR

	movq	%rdi,%rax
	movb	tod_minutes(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFFFF,%rax				# %rax = tod.minutes
	cmpq	$0,%rax
	jl		.ERROR
	cmpq	$59,%rax
	jg		.ERROR

	movq	%rdi,%rax
	movb	tod_ispm(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFF,%rax					# %rax = tod.ispm
	cmpq	$0,%rax
	jl		.ERROR
	cmpq	$1,%rax
	jg		.ERROR

	movq	%rdi,%rax
	movb	tod_seconds(%rip),%cl		
	shrq	%cl,%rax
	andq	$0xFFFF,%rax				# %rax = tod.seconds
	cmpq	$0,%rax
	jl		.ERROR
	cmpq	$59,%rax
	jg		.ERROR

	# set display
	movl	$0,(%rsi)
	# *display |= ampm_masks[tod.ispm] << am_pm;
	movq	%rdi,%rax
	movb	tod_ispm(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFF,%rax					# %rax = tod.ispm
	movq	(%r8,%rax,4),%rax			# %rax = ampm_masks[tod.ispm]
	movb 	am_pm(%rip),%cl
	shlq 	%cl,%rax					# %rax = ampm_masks[tod.ispm] << am_pm
	orl		(%rsi),%eax
	movl	%eax,(%rsi)					# display now has am/pm bit set
	# *display |= num_masks[tod.minutes % 10] << minute_ones;
	movq	%rdi,%rax
	movb	tod_minutes(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFFFF,%rax				# %rax = tod.minutes
	cqto
	movq	$10,%r10
	idivq	%r10
	movq	%rax,%r10					# store the quotient for later

	movq	%rdx,%rax					# %rax = tod.minutes % 10
	movq	(%r9,%rax,4),%rax			# %rax = num_masks[tod.minutes % 10]
	movb 	minute_ones(%rip),%cl
	shlq 	%cl,%rax					# %rax = num_masks[tod.minutes % 10] << minute_ones
	orl		(%rsi),%eax
	movl	%eax,(%rsi)					# display now has the ones-place minutes bits set
	# *display |= num_masks[tod.minutes / 10] << minute_tens;
	movq	%r10,%rax					# %rax = tod.minutes / 10
	movq	(%r9,%rax,4),%rax			# %rax = num_masks[tod.minutes / 10]
	movb 	minute_tens(%rip),%cl
	shlq 	%cl,%rax					# %rax = num_masks[tod.minutes / 10] << minute_tens
	orl		(%rsi),%eax
	movl	%eax,(%rsi)					# display now has the tens-place minutes bits set
	# *display |= num_masks[tod.hours % 10] << hour_ones;
	movq	%rdi,%rax
	movb	tod_hours(%rip),%cl
	shrq	%cl,%rax
	andq	$0xFFFF,%rax				# %rax = tod.hours
	cqto
	movq	$10,%r10
	idivq	%r10
	movq	%rax,%r10					# store the quotient for later

	movq	%rdx,%rax					# %rax = tod.hours % 10
	movq	(%r9,%rax,4),%rax			# %rax = num_masks[tod.hours % 10]
	movb 	hour_ones(%rip),%cl
	shlq 	%cl,%rax					# %rax = num_masks[tod.hours % 10] << hour_ones
	orl		(%rsi),%eax
	movl	%eax,(%rsi)					# display now has the ones-place hours bits set
	# if(tod.hours / 10)
	# 	*display |= num_masks[tod.hours / 10] << hour_tens;
	movq	%r10,%rax					# %rax = tod.hours / 10
	cmpq	$0,%rax
	je		.SUCCESS						
	movq	(%r9,%rax,4),%rax			# %rax = num_masks[tod.hours / 10]
	movb 	hour_tens(%rip),%cl
	shlq 	%cl,%rax					# %rax = num_masks[tod.hours / 10] << hour_tens
	orl		(%rsi),%eax
	movl	%eax,(%rsi)					# display now has the tens-place hours bits set

	jmp		.SUCCESS








.text
.global clock_update
		
clock_update:
	movl	TIME_OF_DAY_SEC(%rip),%edi
	pushq	$0
	movq	%rsp,%rsi
	call    set_tod_from_secs				# set_tod_from_secs(TIME_OF_DAY_SEC, &time_of_day)
	cmpl	$0,%eax
	jne		.failure

	movq	0(%rsp),%rdi
	movq	%rsp,%rsi
	call	set_display_bits_from_tod		# set_display_bits_from_tod(time_of_day, &CLOCK_DISPLAY_PORT)
	cmpl	$0,%eax
	jne		.failure

	popq	%r9								# move display bits, assembled on the stack, into CLOCK_DISPLAY_PORT
	movl	%r9d,CLOCK_DISPLAY_PORT(%rip)
	jmp		.SUCCESS

.failure:
	popq	%r9
	jmp		.ERROR





.SUCCESS:
	movl    $0,%eax
    ret
.ERROR:
    movl    $1,%eax
    ret

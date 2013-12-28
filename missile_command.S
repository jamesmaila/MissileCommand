# missile_command.S

.data
    
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h
    NEXT       = 0
    X          = 4
    Y          = 8
    VX          = 12
    VY            = 16
    DEST_X      = 20
    DEST_Y      = 24
    EXPLODED  = 28
    C            = 32
    
    # Character to draw for an explosion - '@'
    EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

# Data private to this  file
mp1_missile_list:    .long     0x0        # Head of list pointer
base_alive:            .long     0x0        # Array of 3 bytes, plus a padding byte
mp1_score:            .long     0x0        # Player's current score
delete_list:        .long     0x0        # Missile delete list
base_pic:             .string  "/^^^\\"    # Picture of a live base
dead_base_pic:         .string  "xxxxx"    # Picture of a dead base
crosshairs_x:        .long       0x0        # X-position of the crosshairs
crosshairs_y:        .long     0x0        # Y-position of the crosshairs

.text


# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
    movl    vmem_base_addr(,1),%edx  # EDX<-video memory address
    movb    %cl,(%edx,%eax,1)          # write CL to video memory
    ret                              # return

#----------------------- Exported functions ------------------------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#    (1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#    (2) Redraw the bases - they may have been overwritten with missiles
#    (3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:                        #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    #
    pushl        %esi                    # push callee-saved registers
    pushl        %edi                    #
    pushl        %eax                    #
    pushl        %ecx                    # push caller-saved registers
    pushl        %edx                    #
    call        update_missiles            # update missiles
    call        redraw_bases            # redraw bases
    call         redraw_crosshairs       # redraw crosshairs
    popl        %edx                    #
    popl        %ecx                    # pop caller-saved registers
    popl        %eax                    #
    popl        %edi                    #
    popl        %esi                    # pop callee-saved registers
    popl        %ebx                    #
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
delete_missile_list:                    #
    pushl        %ebp                      # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    #
    pushl        %edi                    # push calle-saved registers
    pushl        %esi                    #
    movl        8(%ebp),%ecx            # ECX<-pointer to missile
    cmpl        $0,%ecx                    # check if missile is NULL
    je               done_delete_missile        # if so, finish
    cmpl         mp1_missile_list,%ecx   # check if missile is head
    je               delete_head                # if so, jump to delete head
    movl          mp1_missile_list,%ebx   # EBX<-missile head
                                        #
traverse_missiles:                        #
    cmpl      %ecx,NEXT(%ebx)            # check if next is the missile
    je            found_prev_missile        # if so, jump to found prev
    movl      NEXT(%ebx),%ebx            # if not, missile = missile.next
    cmpl      $0,%ebx                    # check if NULL
    je            done_delete_missile        # if so, finish
    jmp       traverse_missiles            # else, continue traversing
                                        #
found_prev_missile:                        # EBX holds prev
    movl      NEXT(%ecx),%eax            # EAX<-missile.next
    movl      %eax,NEXT(%ebx)             #
    movl      delete_list,%edi             #
    movl      NEXT(%ebx),%edi           #
    movl      %ebx,delete_list          #
    jmp       done_delete_missile       #
                                        #
delete_head:                            #
    movl      NEXT(%ecx),%eax             #
    movl      %eax,mp1_missile_list      #
    movl      delete_list,%edi             #
    movl      NEXT(%ebx),%edi             #
    movl      %ebx,delete_list          #
    jmp          done_delete_missile          #
                                        #
done_delete_missile:                    #
    popl        %esi                     #
    popl        %edi                     #
    popl        %ebx                     #
    leave                                  # restore frame pointer
    ret                                 # return
#-------------------------------------------------------------------------------
update_missiles:                        #
    pushl       %ebp                          # save old frame pointer
    movl       %esp,%ebp                   # point to new frame
    pushl       %ebx                          #
    pushl       %esi                           # push callee-saved registers
    pushl       %edi                          #
    movl       mp1_missile_list,%ebx    # EBX<-head of missile list
    cmpl       $0,%ebx                          #   
    je              no_more_missiles               # check if list is empty
                                        #
more_missiles:                            #
    pushl       %ebx                           # push arg (missile ptr)
    call       erase_missile_screen        # erase from screen
    addl       $4,%esp                       # pop arg
    pushl       %ebx                          # push arg (missile ptr)
    call       explode_status               # process explosions
    addl       $4,%esp                       # pop arg (missile ptr)
    movl       NEXT(%ebx),%eax              # EAX<-missile.next
    cmpl       $0,%eax                       # check if missile.next is NULL
    je              no_more_missiles               # if it is, end of list
    movl       %eax,%ebx                   # else, missle = missile.next
    jmp              more_missiles               # recurse
                                        #
no_more_missiles:                        #
    popl       %edi                          #
    popl       %esi                           # pop callee-saved registers
    popl       %ebx                           #
    leave                                      # restore frame pointer
    ret                                       # return
#-------------------------------------------------------------------------------
explode_status:                            #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    #
    pushl        %esi                     # push callee-saved registers
    pushl        %edi                    #
    movl        8(%ebp),%ebx            # EBX<-missile pointer
    movl        28(%ebx),%ecx            # ECX<-exploded
    cmpl        $0,%ecx                    #
    je            not_exploding            # if exploded = 0, its not exploding
    jmp            is_exploding            # if exploded != 0, it is exploding
                                        #
not_exploding:                            #
    movl        4(%ebx),%esi            # ESI<-original x coord
    movl        12(%ebx),%edi            # EDI<-x velocity
    addl        %esi,%edi                # EDI<-original+velocity
    movl        %edi,4(%ebx)            # update x coord
    movl        %edi,%edx                # EDX<-new x coord   
    movl        8(%ebx),%esi            # ESI<-original y coord
    movl        16(%ebx),%edi            # EDI<-y velocity
    addl        %esi,%edi                # EDI<-original+velocity
    movl        %edi,8(%ebx)            # update y coord
    shrl        $16,%edi                # shift high bits to low bits (y)
    shrl        $16,%edx                # shift high bits to low bits (x)
                                        #
missile_check_bounds:                     #
    cmpw        $0,%dx                    # 
    jl        to_be_deleted                # if new x coord < 0, delete
    cmpw        $79,%dx                    #
    jg        to_be_deleted                # if new x coord > 79, delete
    cmpw        $0,%di                    #
    jl        to_be_deleted                # if new y coord < 0, delete
    cmpw        $24,%di                    # 
    jg        to_be_deleted                # if new y coord > 24, delete
                                        #    
missile_in_bounds:                         #
    movl        20(%ebx),%eax            # EAX<-dest_x
    movl        24(%ebx),%ecx            # ECX<-dest_y
    cmpw        %dx,%ax                    #
    je            at_dest_x                # check if x = dest_x
    jmp            redraw_missile            # if not, redraw the missile
                                        #
at_dest_x:                                 #
    cmpw        %di,%cx                    # check if y = dest_y
    je            is_exploding            # if so, it should explode
    jmp            redraw_missile             #
                                        #
to_be_deleted:                            #
    pushl        %eax                    #
    pushl        %ecx                    # push caller-saved registers
    pushl        %edx                    #
    pushl        %ebx                    # push arg (missile pointer)
    call         delete_missile_list     # call function
    addl        $4,%esp                    # pop arg (missile pointer)
    popl        %edx                    #
    popl        %ecx                    # pop caller-saved registers
    popl        %eax                    #
    jmp            done_explode_status        #
                                        #
is_exploding:                            #
    pushl       %ecx                        # push caller-saved registers
    pushl       %edx                        # 
    pushl       %ebx                        # push arg (missile pointer)
    call        missile_explode            # call function
    addl       $4,%esp                    # pop arg (missile pointer)
    popl       %edx                        # pop caller-saved registers
    popl       %ecx                        #
    cmpl       $0,%eax                    # if missile_explode returns !0,
    jne              cause_explosion            # it caused an explosion
                                        #
process_explosion:                      #
    subl       $1,28(%ebx)                # decrement exploded 
    jz              to_be_deleted            # if exploded = 0, delete missile
    pushl       %eax                        #                               
    pushl       %ecx                        # push caller-saved registers
    pushl       %edx                        #
    pushl       $64                        # push arg (@)
    movl       8(%ebx),%eax                # EAX<-new y
    shrl       $16,%eax                    # shift high bits to low bits
    andl       $65535,%eax                # ignore high bits
    pushl       %eax                        # push arg (y)
    movl       4(%ebx),%eax                # EAX<-new x
    shrl       $16,%eax                    # shift high bits to low bits
    andl       $65535,%eax                # ignore high bits
    pushl       %eax                        # push arg (x)
    call        print_char                # call function
    addl       $12,%esp                    # pop arguments
    popl       %edx                        #        
    popl       %ecx                        # pop caller-saved registers
    popl       %eax                        # 
    jmp             done_explode_status      #
                                        #
cause_explosion:                         #
    pushl    %eax                        #
    pushl    %ecx                        # push caller-saved registers
    pushl    %edx                        #
    call    mp1_notify_user                # notify - explosion caused!
    popl    %edx                        #     
    popl    %ecx                        # pop caller-saved registers
    popl    %eax                        # 
    jmp     process_explosion            # process the explosion
                                        #
redraw_missile:                            #
    pushl       %eax                        #                               
    pushl       %ecx                        # push caller-saved registers
    pushl       %edx                        #
    pushl       C(%ebx)                    # push arg (.)
    movl       8(%ebx),%eax                # EAX<-y
    shrl       $16,%eax                    # shift high bits to low bits
    andl       $65535,%eax                # ignore high bits
    pushl       %eax                        # push arg (y)
    movl       4(%ebx),%eax                # EAX<-x
    shrl       $16,%eax                    # shift high bits to low bits
    andl       $65535,%eax                # ignore high bits
    pushl       %eax                        # push arg (x)
    call        print_char                # call function
    addl       $12,%esp                    # pop arguments
    popl       %edx                        #        
    popl       %ecx                        # pop caller-saved registers
    popl       %eax                        #
    jmp             done_explode_status      #
                                        #
done_explode_status:                    #
    popl       %edi                        #
    popl       %esi                        # pop callee-saved registers
    popl       %ebx                        #
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------- -----------------------------------------
erase_missile_screen:                     #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                 # point to new frame
    pushl        %ebx                    #
    pushl        %esi                    # push callee-saved registers
    pushl        %edi                    #
    movl        8(%ebp),%ebx            # EBX<-missile pointer
    movl        X(%ebx),%ecx            # ECX<-x coordinate
    movl        Y(%ebx),%edx            # EDX<-y coordinate
    movl        $32,%edi                # EAX<-char (space)
    shrl        $16,%ecx                #
    shrl        $16,%edx                # shift high bits to low bits
    andl        $65535,%ecx                #
    andl        $65535,%edx                # ignore the high bits
    pushl        %edi                    #
    pushl        %edx                    # push arguments
    pushl        %ecx                    #
    call        print_char                # erase missile
    addl        $12,%esp                # pop arguments
    popl        %edi                    #
    popl        %esi                    # pop callee-saved registers
    popl        %ebx                    #
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
redraw_bases:                            #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    # 
    pushl        %esi                    # push callee-saved registers
    pushl        %edi                    #
    movl        base_alive,%eax            # EAX<-base alive flag
    movl        base_alive,%ebx            # EBX<-base alive flag
    shrl        $8,%ebx                    # shift to get base 2 in BL
                                        #
check_base1:                            #
    cmpb        $0,%al                    # check if base 1 is dead
    je            base1_dead                # if dead, draw dead
    jmp            base1_alive                # if alive, draw alive
                                        #
base1_dead:                                #
    movl        $3876,%eax                # draw base 1 dead
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3878,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3880,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3882,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3884,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    jmp            check_base2                #
                                        #
base1_alive:                            #
    movl        $3876,%eax                # draw base 1 alive
    movb        $47,%cl                    #
    call        mp1_poke                #
    movl        $3878,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3880,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3882,%eax                #
    movb        $94,%cl                    #    
    call        mp1_poke                #
    movl        $3884,%eax                #
    movb        $92,%cl                    #
    call        mp1_poke                #
    jmp            check_base2                #
                                        #
check_base2:                            #
    cmpb        $0,%bl                    # check if base 2 is alive
    je            base2_dead                # if dead, draw dead 
    jmp            base2_alive                # if alive, draw alive
                                        #
base2_dead:                                #
    movl        $3916,%eax                # draw base 2 dead
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3918,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3920,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3922,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3924,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #    
    jmp            check_base3                #
                                        #
base2_alive:                            #
    movl        $3916,%eax                # draw base 2 alive
    movb        $47,%cl                    #
    call        mp1_poke                #
    movl        $3918,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3920,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3922,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3924,%eax                #
    movb        $92,%cl                    #
    call        mp1_poke                #
    jmp            check_base3                #
                                        #
check_base3:                            #
    cmpb        $0,%bh                    # check if base 3 is alive
    je                base3_dead                # if dead, draw dead
    jmp               base3_alive                # if alive, draw alive
                                        #
base3_dead:                                #
    movl        $3956,%eax                # draw base 3 dead
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3958,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3960,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3962,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    movl        $3964,%eax                #
    movb        $120,%cl                #
    call        mp1_poke                #
    jmp            done_bases                #
                                        #
base3_alive:                            #
    movl        $3956,%eax                # draw base 3 alive
    movb        $47,%cl                    #
    call        mp1_poke                #    
    movl        $3958,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3960,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3962,%eax                #
    movb        $94,%cl                    #
    call        mp1_poke                #
    movl        $3964,%eax                #
    movb        $92,%cl                    #
    call        mp1_poke                #
    jmp            done_bases                #
                                        #
done_bases:                             #
    leave                                # return frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
redraw_crosshairs:                        #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    #
    pushl        %esi                    # push callee-saved registers
    pushl        %edi                    #
    pushl        $43                        # push arg (+)
    pushl        crosshairs_y            # push arg (y)
    pushl        crosshairs_x            # push arg (x)
    call         print_char                # call function
    addl        $12,%esp                # pop args
    popl        %edi                    #
    popl        %esi                    # pop callee-saved registers
    popl        %ebx                    #
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
print_char:                                #
    pushl        %ebp                    # push frame pointer
    movl        %esp,%ebp                # point to new frame
    pushl        %ebx                    #
    pushl        %esi                    # push callee-saved registers
    pushl        %edi                    #
    movl        16(%ebp),%ecx            # ECX<-char
    movl        12(%ebp),%ebx            # EBX<-y coordinate
    movl        8(%ebp),%eax            # EBX<-x coordinate
    imull         $160,%ebx,%ebx            # EBX<-160*EBX
    imull        $2,%eax,%eax            # EAX<-2*EAX
    addl        %ebx,%eax                 # EAX<-EAX+EBX
    cmpl        $0,%eax                 #
    jl            done_print_char         #
    cmpl        $3998,%eax                 #
    jg            done_print_char         #
    call         mp1_poke                # write character to screen
                                        #
done_print_char:                        #
    popl        %edi                    #
    popl        %esi                    # pop callee-saved registers
    popl        %ebx                    #
    leave                                # restore frame pointer
    ret                                    # return
#------------------------------------------------------------------------------    
# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:                                #
    movl      8(%esp),%ecx                 # ECX<-cmd
    movl      4(%esp),%eax                # EAX<-arg
    cmpl      $0,%ecx                    #        
    jl            invalid_cmd                # if cmd < 0, jump to invalid_cmd
    cmpl      $4,%ecx                    #
    jg            invalid_cmd                # if cmd > 4, jump to invalid_cmd
    jmp           *jump_table(,%ecx,4)      # if cmd is valid, jump to operation
    jmp            done_jumptable            # 
                                        #
invalid_cmd:                             #
    movl      $-1,%eax                    # if invalid, return -1
                                        #
done_jumptable:                         #
    ret                                    # return
                                        #
jump_table:                             #
    .long       mp1_ioctl_startgame       #
    .long       mp1_ioctl_addmissile      #
    .long       mp1_ioctl_movexhairs      #
    .long       mp1_ioctl_getstatus       #
    .long       mp1_ioctl_endgame         #
#--------------------- Functions private to this file --------------------------
mp1_ioctl_startgame:                    #
    pushl       %ebp                         # save old frame pointer
    movl       %esp,%ebp                # point to new frame
    pushl       %ebx                        #
    pushl       %esi                        # push callee-saved registers
    pushl       %edi                        #
    movl       $-1,base_alive            # set all bases to alive
    movl       $0,mp1_score                # set score to 0
    movl       $40,crosshairs_x         # 
    movl       $12,crosshairs_y         # set crosshair to (40,12)
    movl       $0,mp1_missile_list        # set missile_lists to NULL
    popl       %edi                        # 
    popl       %esi                        # pop callee-saved registers
    popl       %ebx                        #
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
mp1_ioctl_addmissile:                    #
    pushl       %ebp                        # save old frame pointer
    movl       %esp,%ebp                # point to new frame
    pushl       %ebx                        #
    pushl       %esi                        # push callee-saved registers
    pushl       %edi                        #
    movl       8(%ebp),%ebx                # EBX<-new missile pointer
    pushl       $33                        # push amount of bytes for argument
    call        mp1_malloc                # allocate that much memory
    addl       $4,%esp                    # pop argument
    movl       %eax,%ecx                # ECX<-newly allocated memory
    cmpl       $0,%eax                    # 
    je              malloc_fail                # if malloc returns NULL, it failed
    pushl       %ecx                        # push caller-saved register
    pushl       $33                        # push amount of bytes
    pushl       %ebx                        # push "from" argument
    pushl       %ecx                        # push "to" argument
    call        mp1_copy_from_user        # translate to kernel space
    addl       $12,%esp                    # pop arguments
    popl       %ecx                        # pop caller-saved register
    cmpl       $0,%eax                    #
    jg              copy_from_user_fail        # if return is nonzero, copy failed
    jmp              missile_add_succ            #
                                        #
malloc_fail:                            #
    popl       %edi                        #    
    popl       %esi                        # pop callee-saved registers
    popl       %ebx                        # 
    movl       $-1,%eax                    # return -1
    leave                                   #
    ret                                 #
                                        #
copy_from_user_fail:                    #
    pushl       %ecx                        # push pointer of memory to be freed
    call       mp1_free                    # free memory
    addl       $4,%esp                    # pop argument
    popl       %edi                        #
    popl       %esi                        # pop callee-saved registers
    popl       %ebx                        #
    movl       $-1,%eax                    # return -1
    leave                                  #    
    ret                                   #
                                        #
missile_add_succ:                         #
    movl       mp1_missile_list,%edi    # EDI<-head
    movl       %edi,NEXT(%ecx)             # new_elt.next = head
    movl       %ecx,mp1_missile_list    # head = new_elt
    popl       %edi                        # 
    popl       %esi                        # pop callee-saved registers
    popl       %ebx                        #
    movl       $0,%eax                    # return 0
    leave                                 #
    ret                                 #
#-------------------------------------------------------------------------------
mp1_ioctl_movexhairs:                    #
    pushl       %ebp                         # save old frame pointer
    movl       %esp,%ebp                # point to new frame
    pushl       %ebx                        #
    pushl       %esi                        # push callee-saved registers
    pushl       %edi                        #
    pushl       %eax                        #
    pushl       %ecx                        # push caller-saved registers
    pushl       %edx                        #
    pushl       $32                        # push argument (space) 
    pushl       crosshairs_y                # push argument (y coord)
    pushl       crosshairs_x                # push argument (x coord)
    call       print_char                # call function
    addl       $12,%esp                    # pop arguments
    popl       %edx                        #
    popl       %ecx                        # pop caller-saved registers
    popl       %eax                        #
    movl       8(%ebp),%eax                 # EAX<-arg
    movw       %ax,%bx                    # put low bits of EAX into EBX
    shrl       $16,%eax                    # put high bits of EAX into low bits 
    addw       %ax,crosshairs_y            # add displacement to crosshairs_y
    cmpw       $0,crosshairs_y            # 
    jl              xhair_edge_y_0            # if crosshairs_y < 0, jump
    cmpw       $24,crosshairs_y            #
    jg              xhair_edge_y_24            # if crosshairs_y > 24, jump
    jmp              check_x_bounds            # else, check x bounds
                                        #
xhair_edge_y_0:                            #
    movw       $0,crosshairs_y            # if crosshairs_y < 0, set to 0
    jmp              check_x_bounds            #
                                        #
xhair_edge_y_24:                        #
    movw       $24,crosshairs_y            # if crosshairs_y > 24, set to 24
    jmp              check_x_bounds            #
                                        #
check_x_bounds:                            #
    addw       %bx,crosshairs_x            # add displacement to crosshairs_x
    cmpw       $0,crosshairs_x            #
    jl              xhair_edge_x_0            # if crosshairs_x < 0, jump    
    cmpw       $79,crosshairs_x            #
    jg              xhair_edge_x_79            # if crosshairs_x > 79, jump
    jmp              done_check_xhair            # else, finish checking
                                        #
xhair_edge_x_0:                            #
    movw       $0,crosshairs_x            # if crosshairs_x < 0, set to 0
    jmp              done_check_xhair            #
                                        #
xhair_edge_x_79:                        #
    movw       $79,crosshairs_x            # if crosshairs_x > 79, set to 79
    jmp              done_check_xhair            #
                                        #
done_check_xhair:                         #
    pushl       %eax                        #
    pushl       %ecx                        # push caller-saved registers
    pushl       %edx                        #
    pushl       $43                        # push argument (+ sign)
    pushl       crosshairs_y                # push argument (y coord)
    pushl       crosshairs_x             # push argument (x coord)
    call        print_char                # call function
    addl       $12,%esp                    # pop arguments
    popl       %edx                        #
    popl       %ecx                        # pop caller-saved registers
    popl       %eax                        #
    popl       %edi                     #
    popl       %esi                     #
    popl       %ebx                     #
    movl       $0,%eax                    # return 0
    leave                                # restore frame pointer
    ret                                    # return
#-------------------------------------------------------------------------------
mp1_ioctl_getstatus:                    #
    pushl       %ebp                        # save old frame pointer
    movl       %esp,%ebp                # point to new frame
    pushl       %ebx                        #
    pushl       %esi                        # push callee-saved registers
    pushl       %edi                        #
    pushl       $4                        # push # bytes to allocate
    call        mp1_malloc                # allocate memory
    addl       $4,%esp                    # pop arg
    cmpl       $0,%eax                    # if NULL, finish
    je           finish_status            #
    movl       base_alive,%ebx            # EBX<-base_alive
    movl       %ebx,%ecx                # ECX<-base_alive
    shrl       $16,%ecx                    #
    xorl       %edx,%edx                # clear EDX
    cmpb       $0,%bl                     #
    je             check_base_2_status         #
                                        #
base_1_alive_status:                     #
    addl       $1,%edx                     #
    shll       $1,%edx                     #
                                        #
check_base_2_status:                     #
    cmpb     $0,%bh                     #
    je          base_3_alive_status         #
                                        #
base_2_alive_status:                     #
    addl     $1,%edx                     #
    shll     $1,%edx                     #
                                        #
check_base_3_status:                     #
    cmpb     $0,%cl                     #
    je          bases_loaded                  #
                                        #
base_3_alive_status:                     #
    addl     $1,%edx                     #
    shll     $1,%edx                      #
                                        #
bases_loaded:                             #
    shll     $16,%edx                     #
    movw     mp1_score,%dx                 #
    movl     %edx,(%eax)                 #
    pushl     $4                         #
    pushl     %eax                         #
    pushl     8(%ebp)                      #
    call      mp1_copy_to_user             #
    addl     $12,%esp                     #
    cmpl     $0,%eax                     #
    jne         copy_failed_status         #
    jmp         finish_status                 #
                                         #
copy_failed_status:                     #
    movl     $-1,%eax                     #
                                        #
finish_status:                             #
    popl    %edi                          #
    popl    %esi                         #
    popl    %ebx                         #
    leave                                 #
    ret                                 #
#-------------------------------------------------------------------------------
mp1_ioctl_endgame:                         #
    pushl    %ebp                         #
    movl    %esp,%ebp                     #
    pushl    %ebx                         #
    pushl    %esi                         #
    pushl    %edi                         #
                                        #
free_mp1_missiles:                         #
    movl    mp1_missile_list,%ebx         #
    cmpl    $0,%ebx                     #
    je        free_delete_list             #
    pushl    %ebx                         #
    call    mp1_free                     # 
    popl    %ebx                         #
    movl    NEXT(%ebx),%ebx             #
                                        #
free_delete_list:                         #
    movl    delete_list,%ebx             #
    cmpl    $0,%ebx                     #
    je        finish_game                 #
    pushl    %ebx                         #
    call    mp1_free                     #    
    popl    %ebx                         #
    movl    NEXT(%ebx),%ebx             #
                                        #
finish_game:                             #
    popl    %ebx                         #
    popl    %esi                         #
    popl    %edi                         #
    leave                                 #
    ret                                 #
#-------------------------------------------------------------------------------

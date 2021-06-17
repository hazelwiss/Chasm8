;   enables debug mode.
;%define DEBUG_MODE

%macro PUSH_ALL_REGS 0
    push rax
    push rbx
    push rcx
    push rdx
    push rbp
    push rsp
    push rdi
    push rsi
%endmacro 

%macro POP_ALL_REGS 0
    pop rsi
    pop rdi
    pop rsp
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    pop rax
%endmacro 

%macro LOAD_X_ARGUMENT_ADR 0
    xor rax, rax 
    mov ax, word[ch8_IR]
    and ax, 0F00h
    shr ax, 8
    add rax, ch8_v
%endmacro

%macro LOAD_Y_ARGUMENT_ADR 0
    xor rbx, rbx
    mov bx, word[ch8_IR]
    and bx, 00F0h
    shr bx, 4
    add rbx, ch8_v
%endmacro

%define STACK_STARTADDRESS 0EA0h
%define DISPLAY_REFRESH 0F00h
%define FLAG_REG byte[ch8_v+0Fh] 


SECTION .data
    ;   jump table
    instr_jump_table dq l_opcode0, l_opcode1, l_opcode2, l_opcode3, l_opcode4, l_opcode5, l_opcode6, l_opcode7,
                     dq l_opcode8, l_opcode9, l_opcodeA, l_opcodeB, l_opcodeC, l_opcodeD, l_opcodeE, l_opcodeF
    fontset:
        .fontset_0 db 0xF0, 0x90, 0x90, 0x90, 0xF0,
        .fontset_1 db 0x20, 0x60, 0x20, 0x20, 0x70,
        .fontset_2 db 0xF0, 0x10, 0xF0, 0x80, 0xF0,
        .fontset_3 db 0xF0, 0x10, 0xF0, 0x10, 0xF0,
        .fontset_4 db 0x90, 0x90, 0xF0, 0x10, 0x10,
        .fontset_5 db 0xF0, 0x80, 0xF0, 0x10, 0xF0,
        .fontset_6 db 0xF0, 0x80, 0xF0, 0x90, 0xF0,
        .fontset_7 db 0xF0, 0x10, 0x20, 0x40, 0x40,
        .fontset_8 db 0xF0, 0x90, 0xF0, 0x90, 0xF0,
        .fontset_9 db 0xF0, 0x90, 0xF0, 0x10, 0xF0,
        .fontset_A db 0xF0, 0x90, 0xF0, 0x90, 0x90,
        .fontset_B db 0xE0, 0x90, 0xE0, 0x90, 0xE0,
        .fontset_C db 0xF0, 0x80, 0x80, 0x80, 0xF0,
        .fontset_D db 0xE0, 0x90, 0x90, 0x90, 0xE0,
        .fontset_E db 0xF0, 0x80, 0xF0, 0x80, 0xF0,
        .fontset_F db 0xF0, 0x80, 0xF0, 0x80, 0x80
    fontset_size equ $-fontset

SECTION .bss
    _memory resb 4096h
    ch8_v resb 16
    ch8_I resd 1
    unused resw 8       ;   padding as to prevent accidental overwrite when moving qword.
    ch8_PC resw 1
    ch8_SP resw 1
    ch8_IR resw 1       ;   instruction register, keeps the current instruction.
    ch8_input resb 16   ;   keyboard input.
    ch8_delay resb 1    ;   delay timer.
    ch8_sound resb 1    ;   sound timer.
    _end_memory resb 0
SECTION .text 
global main
extern memset
extern memcpy
extern rand

;   sdl subroutines.
extern sdl_init
extern sdl_init_window
extern sdl_poll
extern sdl_draw
extern sdl_clear_window
extern wait_timer

;   c subroutines
extern load_rom


;   debug subbroutines
extern print_instr
extern print_memory

main:           ;   program entry.
    sub rsp, 8  ;   alligns the stack.
    ;   basic initialization happens here. SDL, stuff like that.
    ;   sets the chip 8 regsiter values to zero, also zeros memory.
    mov rdi, _memory
    lea rdx, [_end_memory-_memory]
    xor rsi, rsi
    call memset             ;   sets the chip8's internal memory to be filled with zeros.
    mov rdi, _memory
    lea rsi, [fontset]
    mov rdx, fontset_size
    call memcpy
    mov rdi, _memory        ;   moves rdi to point towards memory in case it's changed inside of memset.
    call load_rom           ;   loads a rom file form user input.
    call sdl_init           ;   initializes the SDL context.
    call sdl_init_window    ;   creates the SDL window.
    mov word[ch8_PC], 0200h ;   sets the pc to its initial value.
l_main_loop:    ;   interpreter loop.
                ;   main interpreter logic. Decode, execute cycle stuff like that.
    PUSH_ALL_REGS   ;   pushes all general purpose registers onto stack. since pushad isn't supported for 64 bit, a macro has to do.
                    ;   excludes the r8-r15 regs.
    jmp l_decode
l_exit_interpreter_state:   ;   the label to be jumped to upon finishing an instruction in order to complete the cycle.
    POP_ALL_REGS            ;   pops all general purposes from stack.
    lea rdi, [ch8_input]
    call sdl_poll           ;   poll SDL events.
    lea rdi, [ch8_sound]
    lea rsi, [ch8_delay]
    call wait_timer         ;   sleep process if necessary.
    jmp l_main_loop         ;   repeats.
l_end:
    xor rax, rax
    ret
    
;   decode routine
l_decode:
    xor rax, rax,               ;   makes sure rax is zeroed.
    xor rbx, rbx                ;   makes sure rbx is zeroed.
    mov ax, word[ch8_PC]        ;   loads the current PC value into ax
    mov bx, word[_memory+rax]   ;   loads bx with the current instruction.
    ;   loads the IR memory register with the current instruction. Makes sure it's byte-ordered when host platform
    ;   is little endianess.
    mov byte[ch8_IR], bh       
    mov byte[ch8_IR+1], bl  
    ;   now to increment the pc and execute the instruction.
    add ax, 2
    mov word[ch8_PC], ax        ;   increments pc by 2
    jmp l_execute               ;   jump to execute, now when the instruction is saved within the IR register.

;   execute routine
l_execute:
    xor rax, rax            ;   makes sure rax is zeroed.
    mov al, byte[ch8_IR+1]  ;   load the most significant byte of the current instruction into the al register.
    and al, 0F0h            ;   gets the upper nibble of the most significant byte.
    shr al, 1               ;   swapping the nibbles. Most significant nibble is now zeroed while the least significant gets filled with data.
                            ;   then shift left 2 times to multiply with 4, ending up just shifting right once.
    lea rbx, [instr_jump_table] ;   moves rbx to point at the effective address of the jump table.
    add rax, rbx                ;   moves rax to point towards the instruction to execute in memory.
    ;   prints instruction value during debug.
    %ifdef DEBUG_MODE
        push rax
        xor rbx, rbx 
        mov bx, word[ch8_IR]
        mov rdi, rbx
        xor rax, rax
        mov ax, word[ch8_PC]
        mov rsi, rax
        lea rdx, [ch8_v]
        lea rcx, [ch8_I]
        lea r8, [ch8_SP]
        call print_instr
        pop rax
    %endif
    jmp qword[rax]              ;   jumps to the insturction pointed to by rax.
l_execute_end:
    jmp l_exit_interpreter_state

;   each and every of the chip8's instructions. They're not called as a subroutine as they all share return address.
l_opcode0:
    mov al, byte[ch8_IR]
    cmp al, 0EEh 
    je .skip
    call sdl_clear_window   ;   clears the SDL window.
    jmp l_execute_end
.skip:
    xor rax, rax
    sub word[ch8_SP], 2
    mov ax, word[ch8_SP]
    mov bx, word[_memory+STACK_STARTADDRESS+rax]
    mov word[ch8_PC], bx
    jmp l_execute_end

l_opcode1:
    mov ax, word[ch8_IR]    ;   loads current instruction into ax.
    and ax, 0FFFh           ;   removes the most significant nibble of the upper byte to get immediate address.
    mov word[ch8_PC], ax    ;   moves the address immediate into the PC register.
    jmp l_execute_end       ;   jump back to execution lopop.

l_opcode2:
    xor rax, rax
    mov ax, word[ch8_SP]
    mov bx, word[ch8_PC] 
    mov word[_memory+STACK_STARTADDRESS+rax], bx ;   saves the current PC.
    add word[ch8_SP], 2
    jmp l_opcode1     ;   jumps to the opcode1 to perform the PC change.    

l_opcode3:
    LOAD_X_ARGUMENT_ADR     ;   loads adr of X register into ax.
    mov cl, byte[rax]       ;   X register.
    mov bl, byte[ch8_IR]    ;   loads least significant byte of the instruction.
    cmp cl, bl              ;   if equal, skip next instruction. Otherwise don't.
    jne l_execute_end       ;   skips
    add word[ch8_PC], 2     ;   skips next instruction.
    jmp l_execute_end

l_opcode4:
    LOAD_X_ARGUMENT_ADR     ;   loads adr of X register into ax.
    mov cl, byte[rax]       ;   X register.
    mov bl, byte[ch8_IR]    ;   loads least significant byte of the instruction.
    cmp cl, bl              ;   if not equal, skip next instruction. Otherwise don't.
    je l_execute_end        ;   skips
    add word[ch8_PC], 2     ;   skips next instruction.
    jmp l_execute_end

l_opcode5:
    LOAD_X_ARGUMENT_ADR     ;   loads adr of X register into ax.
    LOAD_Y_ARGUMENT_ADR     ;   loads adr of Y register into bx.
    mov cl, byte[rax]       ;   X register.
    mov dl, byte[rbx]       ;   Y register.
    cmp cl, dl              ;   if equal, skip next instruction. Otherwise don't.
    jne l_execute_end       ;   skips
    add word[ch8_PC], 2     ;   skips next instruction.
    jmp l_execute_end

;   further documentation will be sparse unless it's deemed necessary.
l_opcode6:
    LOAD_X_ARGUMENT_ADR
    mov bl, byte[ch8_IR]
    mov byte[rax], bl
    jmp l_execute_end

l_opcode7:
    LOAD_X_ARGUMENT_ADR
    mov bl, byte[ch8_IR]
    add byte[rax], bl
    jmp l_execute_end

l_opcode8:
    ;   decodes the least significant nibble of the least significant byte of the instruction to determine logic.
    LOAD_X_ARGUMENT_ADR
    LOAD_Y_ARGUMENT_ADR
    xor rcx, rcx
    mov cl, byte[ch8_IR]
    and cl, 0Fh
    xor rdi, rdi
    mov rdi, rcx
    mov cl, byte[rax]    ;  loads X register value into cl.
    xor rdx, rdx
    mov dl, byte[rbx]    ;  loads Y register value into dl.
    cmp rdi, 0
    je .op0
    cmp rdi, 1
    je .op1
    cmp rdi, 2
    je .op2
    cmp rdi, 3
    je .op3
    cmp rdi, 4
    je .op4
    cmp rdi, 5
    je .op5
    cmp rdi, 6
    je .op6
    cmp rdi, 7
    je .op7
    cmp rdi, 0Eh
    je .opE
    jmp l_execute_end
.op0:
    ;   sets X to the value of Y.
    mov byte[rax], dl 
    jmp l_execute_end
.op1:
    ;   sets X to the value of X or Y.
    or cl, dl
    mov byte[rax], cl
    jmp l_execute_end
.op2:
    ;   sets X to the value of X and Y.
    and cl, dl
    mov byte[rax], cl
    jmp l_execute_end
.op3:  
    ;   sets X to the value of X xor Y.
    xor cl, dl
    mov byte[rax], cl
    jmp l_execute_end
.op4:  
    ;   sets X to the value of X + Y, also stores the carry flag into the flag register.
    add cl, dl
    mov FLAG_REG, 0
    adc FLAG_REG, 0
    mov byte[rax], cl 
    jmp l_execute_end
.op5: 
    ;   sets X to the value of X - Y, also stores the carry flag into the flag register.
    sub cl, dl
    mov FLAG_REG, 0
    adc FLAG_REG, 0
    mov byte[rax], cl
    jmp l_execute_end
.op6:
    ;   stores the least significant bit of X into the flag register, then logically shifts X right once.
    mov dl, cl
    and dl, 1
    mov FLAG_REG, dl
    shr cl, 1
    mov byte[rax], cl
    jmp l_execute_end
.op7:
    ;   sets X to the value of Y - X, also stores the carry flag into the flag register.
    sub dl, cl
    mov FLAG_REG, 0
    adc FLAG_REG, 0
    mov byte[rax], dl  
    jmp l_execute_end
.opE:
    ;   stores the most significant bit of X into the flag register, then logically shifts X left once.
    mov dl, cl
    and dl, 80h         ;   potentially shift right 7 times?
    shr dl, 7
    mov FLAG_REG, dl
    shl cl, 1
    mov byte[rax], cl
    jmp l_execute_end

l_opcode9:
    LOAD_X_ARGUMENT_ADR     
    LOAD_Y_ARGUMENT_ADR     
    mov cl, byte[rax]       
    mov dl, byte[rbx]       
    cmp cl, dl              ;   if not equal, skip next instruction. Otherwise don't.
    je l_execute_end        
    add word[ch8_PC], 2     
    jmp l_execute_end

l_opcodeA:
    mov ax, word[ch8_IR]
    and ax, 0FFFh
    mov word[ch8_I], ax
    jmp l_execute_end

l_opcodeB:
    mov ax, word[ch8_IR]   
    and ax, 0FFFh  
    mov rsi, qword[ch8_v]
    and rsi, 00FFh    
    add rax, rsi     
    mov word[ch8_PC], ax    
    jmp l_execute_end       

l_opcodeC:
    call rand
    mov rbx, 255
    xor rdx, rdx
    div rbx ;   remainder is stored in RDX
    LOAD_X_ARGUMENT_ADR
    mov byte[rax], dl
    jmp l_execute_end

l_opcodeD:
    LOAD_X_ARGUMENT_ADR
    LOAD_Y_ARGUMENT_ADR
    xor rcx, rcx 
    xor rdx, rdx
    mov cl, byte[rax]
    mov dl, byte[rbx]
    xor rax, rax
    xor rbx, rbx
    mov al, byte[ch8_IR]
    and al, 0x0F
    mov bx, word[ch8_I]
    mov rdi, rax
    mov rsi, rdx
    mov rdx, rcx
    lea rcx, [_memory+rbx]
    lea r8, [ch8_v+0xF]
    call sdl_draw           ;   draws the SDL window and computes stuff.
    jmp l_execute_end

l_opcodeE:
    LOAD_X_ARGUMENT_ADR
    xor rcx, rcx
    mov cl, byte[rax]
    mov bl, byte[ch8_IR]
    cmp bl, 09Eh
    je .case0
    cmp bl, 0A1h
    je .case1
    jmp l_execute_end
.case0:
    cmp byte[ch8_input+rcx], 0   ;   1 = pressed, 0 = not pressed
    je l_execute_end
    add word[ch8_PC], 2
    jmp l_execute_end
.case1:
    cmp byte[ch8_input+rcx], 1   ;   1 = pressed, 0 = not pressed
    je l_execute_end
    add word[ch8_PC], 2
    jmp l_execute_end

l_opcodeF:
    LOAD_X_ARGUMENT_ADR
    xor rcx, rcx
    mov cl, byte[rax]
    mov bl, byte[ch8_IR]
    cmp bl, 007h
    je .case0 
    cmp bl, 00Ah
    je .case1
    cmp bl, 015h 
    je .case2 
    cmp bl, 018h
    je .case3 
    cmp bl, 01Eh
    je .case4 
    cmp bl, 029h
    je .case5 
    cmp bl, 033h
    je .case6
    cmp bl, 055h
    je .case7
    cmp bl, 065h
    je .case8
    jmp l_execute_end
.case0:
    mov bl, byte[ch8_delay]
    mov byte[rax], bl
    jmp l_execute_end
.case1:
    cmp qword[ch8_input], 0
    jne .skip
    sub byte[ch8_PC], 2
    jmp l_execute_end
.skip:
    lea r8, ch8_input
    mov r9, 0
.beg:
    cmp r9, 16
    je .end
    cmp byte[ch8_input+r9], 0
    jne .end
    inc r9
    jmp .beg 
.end:
    mov rdx, r9
    mov byte[rax], dl 
    jmp l_execute_end
.case2:
    mov byte[ch8_delay], cl
    jmp l_execute_end
.case3:
    mov byte[ch8_sound], cl
    jmp l_execute_end
.case4:
    and cx, 00FFh
    add word[ch8_I], cx
    jmp l_execute_end
.case5:
    mov byte[ch8_I+1], 0
    mov byte[ch8_I], cl
    jmp l_execute_end
.case6:
    LOAD_X_ARGUMENT_ADR
    mov r8, 100
    mov r9, 10
    xor rbx, rbx
    mov bx, word[ch8_I]
    mov r10, rbx
    xor rcx, rcx
    mov cl, byte[rax]
    xor rax, rax
    mov ax, cx
    mov rbx, r8
    xor rdx, rdx
    div bx
    mov byte[_memory+r10], al
    mov ax, cx
    xor rdx, rdx
    div bx
    mov rax, rdx
    mov rbx, r9
    xor rdx, rdx
    div bx  
    mov byte[_memory+r10+1], al
    mov rax, rcx
    xor rdx, rdx
    div bx
    mov byte[_memory+r10+2], dl
    jmp l_execute_end
.case7:
    LOAD_X_ARGUMENT_ADR
    xor rcx, rcx
    mov cx, word[ch8_I]
    lea rdi, [_memory+rcx]
    lea rsi, [ch8_v]
    lea rdx, [rax]
    sub rdx, rsi
    add rdx, 1
    call memcpy
    jmp l_execute_end
.case8:
    LOAD_X_ARGUMENT_ADR
    xor rcx, rcx
    mov cx, word[ch8_I]
    lea rdi, [ch8_v]
    lea rsi, [_memory+rcx]
    lea rdx, [rax]
    sub rdx, rdi
    add rdx, 1
    call memcpy
    jmp l_execute_end
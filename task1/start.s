section .rodata
    newline db 10, 0

section .bss
    Infile resd 1
    Outfile resd 1
    encoder_buffer resb 1

section .text
    global _start
    global system_call
    global main
    extern strlen

_start:
    pop    dword ecx    ; ecx = argc
    mov    esi,esp      ; esi = argv
    ;; lea eax, [esi+4*ecx+4] ; eax = envp = (4*ecx)+esi+4
    mov     eax,ecx     ; put the number of arguments into eax
    shl     eax,2       ; compute the size of argv in bytes
    add     eax,esi     ; add the size to the address of argv 
    add     eax,4       ; skip NULL at the end of argv
    push    dword eax   ; char *envp[]
    push    dword esi   ; char* argv[]
    push    dword ecx   ; int argc
    call    main        ; int main( int argc, char *argv[], char *envp[] )
    mov     ebx,eax
    mov     eax,1
    int     0x80
    nop
        
system_call:
    push    ebp             ; Save caller state
    mov     ebp, esp
    sub     esp, 4          ; Leave space for local var on stack
    pushad                  ; Save some more caller state
    mov     eax, [ebp+8]    ; Copy function args to registers: leftmost...        
    mov     ebx, [ebp+12]   ; Next argument...
    mov     ecx, [ebp+16]   ; Next argument...
    mov     edx, [ebp+20]   ; Next argument...
    int     0x80            ; Transfer control to operating system
    mov     [ebp-4], eax    ; Save returned value...
    popad                   ; Restore caller state (registers)
    mov     eax, [ebp-4]    ; place returned value where caller can see it
    add     esp, 4          ; Restore caller state
    pop     ebp             ; Restore caller state
    ret                     ; Back to caller

main:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi
    push    edi

    ; Initialize file descriptors
    mov     dword [Infile], 0      ; STDIN
    mov     dword [Outfile], 1     ; STDOUT

    ; argc is at [ebp+8], argv is at [ebp+12]
    ; Note: _start pushed (envp, argv, argc). 
    ; Stack when main is called:
    ; [ebp] = old ebp
    ; [ebp+4] = return address
    ; [ebp+8] = argc
    ; [ebp+12] = argv
    ; [ebp+16] = envp

    mov     ecx, [ebp+8]   ; argc
    mov     esi, [ebp+12]  ; argv
    xor     edi, edi       ; loop counter i = 0

arg_loop:
    cmp     edi, ecx
    jge     encode_start   ; if i >= argc, start encoding

    ; Get argv[i]
    mov     ebx, [esi + edi*4]
    
    ; Print argument to stderr (Task 1.A "debug printout")
    ; Calculate length
    push    ecx             ; Save argc
    push    ebx             ; Push string pointer for strlen
    call    strlen
    add     esp, 4
    pop     ecx             ; Restore argc

    ; Write(2, argv[i], len)
    mov     edx, eax        ; length
    mov     eax, 4          ; sys_write
    mov     ecx, ebx        ; buffer (argv[i])
    mov     ebx, 2          ; fd = stderr
    int     0x80

    ; Write newline
    mov     eax, 4
    mov     ebx, 2
    mov     ecx, newline
    mov     edx, 1
    int     0x80

    ; Check for flags in argv[i]
    mov     ebx, [esi + edi*4] ; Reload pointer
    cmp     byte [ebx], '-'
    jne     next_arg

    cmp     byte [ebx+1], 'i'
    je      open_input
    
    cmp     byte [ebx+1], 'o'
    je      open_output
    
    jmp     next_arg

open_input:
    ; Open file for reading
    ; -i<filename> so filename starts at ebx+2
    add     ebx, 2
    mov     eax, 5          ; sys_open
    mov     ecx, 0          ; O_RDONLY
    int     0x80
    
    test    eax, eax
    js      exit_error
    mov     [Infile], eax
    jmp     next_arg

open_output:
    ; Open file for writing
    ; -o<filename> so filename starts at ebx+2
    add     ebx, 2
    mov     eax, 5          ; sys_open
    mov     ecx, 0x241      ; O_WRONLY | O_CREAT | O_TRUNC
    mov     edx, 0644o      ; mode
    int     0x80
    
    test    eax, eax
    js      exit_error
    mov     [Outfile], eax
    jmp     next_arg

next_arg:
    inc     edi
    jmp     arg_loop

encode_start:
    ; Read-Modify-Write Loop
    
read_char:
    mov     eax, 3          ; sys_read
    mov     ebx, [Infile]
    mov     ecx, encoder_buffer
    mov     edx, 1
    int     0x80
    
    cmp     eax, 0
    je      exit_program    ; EOF or 0 bytes read
    js      exit_error      ; Error

    ; Encode logic
    mov     al, [encoder_buffer]
    cmp     al, 'A'
    jl      write_char
    cmp     al, 'Z'
    jg      write_char
    
    ; It is between 'A' and 'Z', add 3
    add     byte [encoder_buffer], 3

write_char:
    mov     eax, 4          ; sys_write
    mov     ebx, [Outfile]
    mov     ecx, encoder_buffer
    mov     edx, 1
    int     0x80
    
    jmp     read_char

exit_program:
    mov     eax, 1          ; sys_exit
    xor     ebx, ebx        ; status 0
    int     0x80

exit_error:
    mov     eax, 1
    mov     ebx, 0x55
    int     0x80


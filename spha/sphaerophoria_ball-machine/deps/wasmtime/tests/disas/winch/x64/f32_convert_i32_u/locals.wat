;;! target = "x86_64"
;;! test = "winch"

(module
    (func (result f32)
        (local i32)  

        (local.get 0)
        (f32.convert_i32_u)
    )
)
;; wasm[0]::function[0]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       movq    8(%rdi), %r11
;;       movq    (%r11), %r11
;;       addq    $0x18, %r11
;;       cmpq    %rsp, %r11
;;       ja      0x6e
;;   1b: movq    %rdi, %r14
;;       subq    $0x18, %rsp
;;       movq    %rdi, 0x10(%rsp)
;;       movq    %rsi, 8(%rsp)
;;       movq    $0, (%rsp)
;;       movl    4(%rsp), %ecx
;;       movl    %ecx, %ecx
;;       cmpq    $0, %rcx
;;       jl      0x4e
;;   44: cvtsi2ssq %rcx, %xmm0
;;       jmp     0x68
;;   4e: movq    %rcx, %r11
;;       shrq    $1, %r11
;;       movq    %rcx, %rax
;;       andq    $1, %rax
;;       orq     %r11, %rax
;;       cvtsi2ssq %rax, %xmm0
;;       addss   %xmm0, %xmm0
;;       addq    $0x18, %rsp
;;       popq    %rbp
;;       retq
;;   6e: ud2

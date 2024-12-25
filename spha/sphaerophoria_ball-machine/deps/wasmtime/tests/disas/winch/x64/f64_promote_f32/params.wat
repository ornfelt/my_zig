;;! target = "x86_64"
;;! test = "winch"

(module
    (func (param f32) (result f64)
        (local.get 0)
        (f64.promote_f32)
    )
)
;; wasm[0]::function[0]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       movq    8(%rdi), %r11
;;       movq    (%r11), %r11
;;       addq    $0x18, %r11
;;       cmpq    %rsp, %r11
;;       ja      0x42
;;   1b: movq    %rdi, %r14
;;       subq    $0x18, %rsp
;;       movq    %rdi, 0x10(%rsp)
;;       movq    %rsi, 8(%rsp)
;;       movss   %xmm0, 4(%rsp)
;;       movss   4(%rsp), %xmm0
;;       cvtss2sd %xmm0, %xmm0
;;       addq    $0x18, %rsp
;;       popq    %rbp
;;       retq
;;   42: ud2

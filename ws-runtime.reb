Rebol [
    Title: "Whitespace Interpreter Runtime"
    File: %ws-runtime.reb

    Type: module
    Name: Whitespace-Runtime

    Description: --[
        This (ab)uses the PARSE dialect to act as an interpreter where
        the parsing position is the program counter.  It leverages that
        PARSE has the ability to mark and seek input positions in a
        random-access fashion.
    ]--
]

import %ws-common.reb


=== RUNTIME VIRTUAL MACHINE OPERATIONS ===

; 0 - no output besides program output (print statements)
; 1 - print what phase the system is running in
; 2 - show individual instructions
; 3 - show beginning and end series positions for each step
;
; !!! Current export mechanism for changing values means that the importing
; module gets a copy on import and doesn't see changes after that.  This is
; fine for blocks or objects that are passed by reference, but not things
; like positions that change or immediates like verbose.  The importer must
; access these through `vm: import %ws-runtime.reb` and then `vm.verbose`
;
verbose: 0

; We allow you to execute a series starting at any position.  This would allow
; for running a whitespace program embedded in something with a header of
; some kind (for instance) without copying to a new series.  But at the moment
; that means indices must be calculated as the offset from this beginning.
;
; !!! See notes on verbose for why these aren't exported, access with `vm.xxx`
;
program-start: ~
instruction-start: ~
instruction-end: ~
pass: 1
max-steps: null

; !!! The module mechanisms for seeing changes in exported variables are
; under review.  In the meantime, the below are series, maps, and functions
; and are okay to export.

export stack: []  ; start out with an empty stack

export callstack: []  ; callstack is separate from data stack

export heap: to map! []  ; a map is probably not ideal

export labels: to map! []  ; maps Label strings to program character indices

export category-rules: []  ; CATEGORY from %ws-dialect.reb adds to this list

; 1. DEBASE makes bytes, we must pad to a multiple of 8 bits.  Better way?
;
; 2. Rebol2, R3-Alpha, Red DEBASE gives back a result in big endian:
;
;        >> debase:base "1111111100000001" 2
;        == #{FF01}
;
;        >> decode [BE +] #{FF01}
;        == 65281
;
whitespace-number-to-int: func [
    text "whitespace encoded number (SPACE => 0, TAB => 1)"
        [text!]
][
    let sign: either space = first text [1] [-1]  ; first char indicates sign

    let bin: copy next text
    replace bin space "0"
    replace bin tab "1"

    let pad: unspaced array:initial (8 - modulo (length of bin) 8) #"0"  ; [1]
    return sign * decode [BE +] debase:base unspaced [pad bin] 2  ; [2]
]

export lookup-label-offset: func [label [text!]] [
    return select labels label else [
        fail ["RUNTIME ERROR: Jump to undefined Label" mold label]
    ]
]


=== PARSE-BASED VIRTUAL MACHINE ===

; Synthesized product of this rule is the number decoded as an INTEGER!
;
export Number: [
    let encoded: across some [space | tab], elide lf (
        whitespace-number-to-int encoded  ; ^-- elide so ACROSS is rule result
    )
]

; According to the spec, labels are simply [lf] terminated lists of spaces and
; tabs.  We don't want to use a Number rule for them--though--because they
; can be unreasonably long.
;
export Label: [
    across some [space | tab], elide lf  ; elide so ACROSS is rule result
]


export interpreter-rule: [
    program-start: <here>

    let execution-steps: 0

    while [not <end>] [
        (if max-steps and (execution-steps > max-steps) [
            print ["MORE THAN" max-steps "INSTRUCTIONS EXECUTED"]
            quit 1
        ])

        instruction-start: <here>  ;  current parse position is start address

        ; Try the rules added by CATEGORY as alternates.  This uses the ANY
        ; combinator, which takes BLOCK! as a synthesized argument.  (BLOCK!
        ; has a reserved purpose when used as a rule, for sequencing by
        ; default and alternates only with |.  ANY does alternates and does
        ; not require a |.)
        ;
        let instruction: [any (category-rules) | (fail "UNKNOWN OPERATION")]

        instruction-end: <here>  ; also capture position at end of instruction

        ; === EXECUTE VM CODE ===

        ; GROUP! of code in parentheses evaluates to next location to jump to.
        ;
        seek (
            let jump-position: null

            if verbose >= 3 [
                print [
                    "S:" offset? program-start instruction-start
                    "E:" offset? program-start instruction-end
                    "->"
                    mold copy:part instruction-start instruction-end
                ]
            ]

            if 'mark-location = instruction.1 [  ; labels marked on first pass
                if pass = 1 [
                    if verbose >= 2 [
                        print mold instruction
                    ]

                    ensure null eval instruction  ; null for "don't jump"
                ]
            ] else [
                if pass = 2 [  ; most instructions run on the second pass
                    if verbose >= 2 [
                        print mold instruction
                    ]

                    jump-position: eval instruction  ; null is no jump

                    execution-steps: execution-steps + 1
                ]
            ]

            maybe jump-position  ; SEEK sees void as don'ot jump
        )
    ]
]

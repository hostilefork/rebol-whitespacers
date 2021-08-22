Rebol [
    Title: {Whitespace Interpreter Runtime}
    File: %ws-runtime.reb

    Type: module
    Name: Whitespace-Runtime

    Description: {
        This (ab)uses the PARSE dialect to act as an interpreter where
        the parsing position is the program counter.  It leverages that
        PARSE has the ability to mark and seek input positions in a
        random-access fashion.
    }
]

=== TEST USERMODE PARSER COMBINATORS ===

; Because the whitespace interpreter is an intellectual exercise, we are
; more concerned about testing cutting-edge prototypes than trying to
; perform well.  Redefine UPARSE to be PARSE, because they will converge.

parse: :uparse
parse*: :uparse*
parse?: :uparse?


=== RUNTIME VIRTUAL MACHINE OPERATIONS ===

; 0 - no output besides program output (print statements)
; 1 - print what phase the system is running in
; 2 - show individual instructions
; 3 - show beginning and end series positions for each step
;
verbose: 0

; start out with an empty stack
stack: []

; callstack is separate from data stack
callstack: []

; a map is probably not ideal
heap: make map! []

; from Label # to program character index
labels: make map! []

; The CATEGORY operation will add rule definitions to this list.
;
category-rules: []

whitespace-number-to-int: func [
    text "whitespace encoded number (SPACE => 0, TAB => 1)"
        [text!]
][
    let sign: either space = first text [1] [-1]  ; first char indicates sign

    let bin: copy next text
    replace/all bin space "0"
    replace/all bin tab "1"

    ; DEBASE makes bytes, we must pad to a multiple of 8 bits.  Better way?
    ;
    let pad: unspaced array/initial (8 - modulo (length of bin) 8) #"0"
    return sign * to-integer debase/base unspaced [pad bin] 2
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
    encoded: across some [space | tab], elide lf (
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

pass: 1

max-steps: null

whitespace-vm-rule: [
    ; capture start of program
    program-start: <here>

    ; initialize count
    (execution-steps: 0)

    ; begin matching parse patterns
    while [
        not <end>

        (
            if max-steps and (execution-steps > max-steps) [
                print ["MORE THAN" max-steps "INSTRUCTIONS EXECUTED"]
                quit 1
            ]
        )

        ; Try the rules added by CATEGORY as alternates.  This uses the ANY
        ; combinator, which takes a BLOCK! as a synthesized argument.  (BLOCK!
        ; has a reserved purpose when used as a rule, for sequencing by
        ; default and alternates only with |.  ANY does alternates and does
        ; not require a |.)
        ;
        instruction-start: <here>  ;  current parse position is start address
        [
            instruction: any (category-rules) | (fail "UNKNOWN OPERATION")
        ]
        instruction-end: <here>  ; also capture position at end of instruction

        ; execute the VM code and optionally give us debug output
        (
            ; This debugging output is helpful if there are malfunctions
            if verbose >= 3 [
                print [
                    "S:" offset? program-start instruction-start
                    "E:" offset? program-start instruction-end
                    "->"
                    mold copy/part instruction-start instruction-end
                ]
            ]

            ; default to whatever is next, which is where we
            ; were before this code
            next-instruction: instruction-end

            ; !!! The original implementation put the functions to handle the
            ; opcodes in global scope, so when an instruction said something
            ; like [jump-if-zero] it would be found.  Now the functions are
            ; inside one of the category objects.  As a temporary measure to
            ; keep things working, just try binding the instruction in all
            ; the category objects.
            ;
            ; !!! Also, this isn't going to give you an ACTION!, it gives an
            ; OBJECT! which has an action as a member.  So you have to pick
            ; the action out of it.  Very ugly...fix this soon!

            word: take instruction

            word: any [
                in Stack-Manipulation word
                in Arithmetic word
                in Heap-Access word
                in Flow-Control word
                in IO word
            ] else [
                fail "instruction WORD! not found in any of the categories"
            ]

            ; !!! Furthering the hackishness of the moment, we bind to an
            ; action in the object with a field name the same as the word.
            ; So `push.push`, or `add.add`.  See OPERATION for a description
            ; of why we're doing this for now.
            ;
            word: non null in get word word
            ensure action! get word
            insert instruction ^word

            either 'mark-location == word [
                if (pass == 1) [
                    if verbose >= 2 [
                        print ["(" mold instruction ")"]
                    ]

                    ; the first pass does the Label markings...
                    ensure null do instruction
                ]
            ][
                if (pass == 2) [
                    if verbose >= 2 [
                        print ["(" mold instruction ")"]
                    ]

                    ; most instructions run on the second pass...
                    result: do instruction

                    if not null? result [
                        ; if the instruction returned a value, use
                        ; as the offset of the next instruction to execute
                        next-instruction: skip program-start result
                    ]

                    execution-steps: execution-steps + 1
                ]
            ]
        )

        ; Set the parse position to whatever we set in the code above
        seek (try next-instruction)
    ]
]

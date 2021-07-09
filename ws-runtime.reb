Rebol [
    Title: {Whitespace Interpreter Runtime}
    File: %ws-runtime.reb

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

binary-string-to-int: func [s [text!] <local> pad] [
    ; debase makes bytes, so to use it we must pad to a
    ; multiple of 8 bits.  better way?
    pad: unspaced array/initial (8 - modulo (length of s) 8) #"0"
    return to-integer debase/base unspaced [pad s] 2
]

whitespace-number-to-int: func [w [text!] <local> bin] [
    ; first character indicates sign
    sign: either space == first w [1] [-1]

    ; rest is binary value
    bin: copy next w
    replace/all bin space "0"
    replace/all bin tab "1"
    replace/all bin lf ""
    return sign * (binary-string-to-int bin)
]

lookup-label-offset: func [label [text!]] [
    return select labels label else [
        fail ["RUNTIME ERROR: Jump to undefined Label" mold label]
    ]
]


=== PARSE-BASED VIRTUAL MACHINE ===

; if the number rule matches, then param will contain the
; integer value of the decoded result
Number: [
    encoded: across [some [space | tab] lf] (
        param: whitespace-number-to-int encoded
    )
]

; According to the spec, labels are simply [lf] terminated lists of spaces and
; tabs.  We don't want to use a Number rule for them--though--because they
; can be unreasonably long.
;
Label: [
    param: across [some [space | tab] lf]
]

pass: 1

max-execution-steps: 1000

whitespace-vm-rule: [
    ; capture start of program
    program-start: <here>

    ; initialize count
    (execution-steps: 0)

    ; begin matching parse patterns
    while [
        not end

        (
            if (execution-steps > max-execution-steps) [
                print ["MORE THAN" execution-steps "INSTRUCTIONS EXECUTED"]
                quit 1
            ]
        )

        instruction-start: <here>  ;  current parse position is start address
        [
            Stack-Manipulation.rule
            | Arithmetic.rule
            | Heap-Access.rule
            | Flow-Control.rule
            | IO.rule
            | (fail "UNKNOWN OPERATION")
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
        seek (next-instruction)
    ]
]

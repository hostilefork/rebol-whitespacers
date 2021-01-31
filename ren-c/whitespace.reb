Rebol [
    Title: "Whitespace Intepreter"
    Purpose: "Whitespace Language Written as a Rebol 3 Parse Dialect"

    Author: "Hostile Fork"
    Home: http://github.com/hostilefork/whitespacers/
    License: 'mit

    File: %whitespace.r
    Date: 10-Jul-2010
    Version: 0.2.0

    ; Header conventions: http://www.rebol.org/one-click-submission-help.r
    Type: 'fun
    Level: 'intermediate

    Description: {
        This is an interpreter for the Whitespace language:

        http://compsoc.dur.ac.uk/whitespace/
    }

    Usage: {
        Run it.  Program is currently hardcoded into a variable, but
        I'll change it to take command line parameters.  Also, I should
        add a switch to generate documentation.
    }

    History: [
        0.1.0 [8-Oct-2009 {Private release to R3 Chat Group for commentary}]

        0.2.0 [10-Jul-2010 {Public release as part of a collection of
        whitespace interpreters in various languages}]
    ]
]


;
; CONTROL SEQUENCE DEFINITIONS
;
; This really shouldn't count in the size of the program, because it's
; just the specification:
;
;     http://compsoc.dur.ac.uk/whitespace/tutorial.php
;

Stack-Manipulation: [
    IMP: [space]

    description: {
        Stack manipulation is one of the more common operations, hence the
        shortness of the IMP [space].
    }

    push: [
        command: [space Number]
        description: {Push the number onto the stack}
    ]
    duplicate-top: [
        command: [lf space]
        description: {Duplicate the top item on the stack}
    ]
    duplicate-indexed: [
        command: [tab space Number]
        description: {
            Copy the nth item on the stack (given by the argument)
            onto the top of the stack
        }
    ]
    swap-top-2: [
        command: [tab tab]
        description: {Swap the top two items on the stack}
    ]
    discard-top: [
        command: [lf lf]
        description: {Discard the top item on the stack}
    ]
    slide-n-values: [
        command: [tab lf Number]
        description: {Slide n items off the stack, keeping the top item}
    ]
]

Arithmetic: [
    IMP: [tab space]

    description: {
        Arithmetic commands operate on the top two items on the stack, and
        replace them with the result of the operation. The first item pushed
        is considered to be left of the operator.

        The copy and slide instructions are an extension implemented in
        Whitespace 0.3 and are designed to facilitate the implementation of
        recursive functions. The idea is that local variables are referred to
        using [space tab space], then on return, you can push the return
        value onto the top of the stack and use [space tab lf] to discard the
        local variables.
    }

    add: [
        command: [space space]
        description: {Addition}
    ]

    subtract: [
        command: [space tab]
        description: {Subtraction}
    ]

    multiply: [
        command: [space lf]
        description: {Multiplication}
    ]

    divide: [
        command: [tab space]
        description: {Integer Division}
    ]

    modulo: [
        command: [tab tab]
        description: {Modulo}
    ]
]

Heap-Access: [
    IMP: [tab tab]
    description: {
        Heap access commands look at the stack to find the address of items
        to be stored or retrieved. To store an item, push the address then the
        value and run the store command. To retrieve an item, push the address
        and run the retrieve command, which will place the value stored in
        the location at the top of the stack.
    }

    store: [
        command: [space]
        description: {Store}
    ]

    retrieve: [
        command: [tab]
        description: {Retrieve}
    ]
]

Flow-Control: [
    IMP: [lf]
    description: {
        Flow control operations are also common. Subroutines are marked by
        labels, as well as the targets of conditional and unconditional jumps,
        by which loops can be implemented. Programs must be ended by means of
        [lf lf lf] so that the interpreter can exit cleanly.
    }

    mark-location: [
        command: [space space Label]
        description: {Mark a location in the program}
    ]

    call-subroutine: [
        command: [space tab Label]
        description: {Call a subroutine}
    ]

    jump-to-label: [
        command: [space lf Label]
        description: {Jump unconditionally to a Label}
    ]

    jump-if-zero: [
        command: [tab space Label]
        description: {Jump to a Label if the top of the stack is zero}
    ]

    jump-if-negative: [
        command: [tab tab Label]
        description: {Jump to a Label if the top of the stack is negative}
    ]

    return-from-subroutine: [
        command: [tab lf]
        description: {End a subroutine and transfer control back to the caller}
    ]

    end-program: [
        command: [lf lf]
        description: {End the program}
    ]
]

IO: [
    IMP: [tab lf]
    description: {
        Finally, we need to be able to interact with the user. There are IO
        instructions for reading and writing numbers and individual characters.
        With these, string manipulation routines can be written (see examples
        to see how this may be done).

        The read instructions take the heap address in which to store the
        result from the top of the stack.
    }

    output-character-on-stack: [
        command: [space space]
        description: {Output the character at the top of the stack}
    ]

    output-number-on-stack: [
        command: [space tab]
        description: {Output the number at the top of the stack}
    ]

    read-character-to-location: [
        command: [tab space]
        description: {
            Read a character and place it in the location given by the top
            of the stack
        }
    ]

    read-number-to-location: [
        command: [tab tab]
        description: {
            Read a number and place it in the location given by the top of
            the stack
        }
    ]
]


;
; RUNTIME VIRTUAL MACHINE OPERATIONS
;

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

push: func [value [integer!]] [
    insert stack value
    return null
]

duplicate-top: func [] [
    insert stack first stack
    return null
]

duplicate-indexed: func [index [integer!]] [
    insert stack pick stack param
    return null
]

swap-top-2: func [] [
    move/part stack 1 1
    return null
]

discard-top: func [] [
    take stack
    return null
]

slide-n-values: func [n [integer!]] [
    take/part next stack n
    return null
]

do-arithmetic: func [operator [word!]] [
    ; note the first item pushed is the left of the operation.
    ; could do infix except Rebol's modulo is prefix (mod a b)

    insert stack do reduce [
        operator second stack first stack
    ]
    take/part next stack 2
    return null
]

do-heap-store: [
    ; hmmm... are value and address left on the stack?
    ; the spec does not explicitly say they are removed
    ; but the spec is pretty liberal about not mentioning it
    value: take stack
    address: take stack
    pos: select heap address
    either pos [
        poke pos 1 value
    ][
        repend heap [value address]
    ]

    take/part stack 2
    return null
]

do-heap-retrieve: [
    ; again, the spec doesn't explicitly say to remove from stack
    address: take stack
    value: select heap address
    print ["retrieving" value "to stack from address:" address]
    insert stack value
    return null
]

lookup-label-offset: func [label [integer!]] [
    address: select labels label
    if null? address [
        print ["RUNTIME ERROR: Jump to undefined Label #" label]
        quit
    ]
    return address
]

mark-location: func [label [integer!] address [integer!]] [
    pos: select labels label
    either pos [
        poke pos 1 address
    ][
        repend labels [label address]
    ]
    return null
]

call-subroutine: func [current-offset [integer!]] [
    insert callstack current-offset
    return lookup-label-offset param
]

jump-to-label: func [] [
    return lookup-label-offset param
]

jump-if-zero: func [] [
    ; must pop stack to make example work
    if zero? take stack [
        return lookup-label-offset param
    ]
    return null
]

jump-if-negative: func [] [
    ; must pop stack to make example work
    if 0 > take stack [
        return lookup-label-offset param
    ]
    return null
]

return-from-subroutine: func [] [
    if empty? callers [
        print "RUNTIME ERROR: return with no callstack!"
        quit
    ]
    return take callstack
]


; spec didn't say we should pop the stack when we output
; but the sample proves we must!

output-character-on-stack: func [] [
    print [as issue! first stack]
    take stack
    return null
]

output-number-on-stack: func [] [
    print [first stack]
    take stack
    return null
]


;
; REBOL PARSE DIALECT FOR WHITESPACE LANGUAGE
;

; if the number rule matches, then param will contain the
; integer value of the decoded result
Number: [
    copy encoded [some [space | tab] lf] (
        param: whitespace-number-to-int encoded
    )
]

; according to the spec, labels are simply [lf] terminated
; lists of spaces and tabs.  So treating them as Numbers is fine.
Label: Number

pass: 1

max-execution-steps: 1000
debug-steps: true
extended-debug-steps: false

whitespace-vm-rule: [
    ; capture start of program
    program-start:

    ; initialize count
    (execution-steps: 0)

    ; begin matching parse patterns
    any [ 1 [
        ; capture current parse position as start of instruction
        instruction-start:

        (
            if (execution-steps > max-execution-steps) [
                print ["MORE THAN" execution-steps "INSTRUCTIONS EXECUTED"]
                quit
            ]
        )

        Stack-Manipulation/IMP [
            Stack-Manipulation/push/command (
                instruction: compose [push (param)]
            )

            | Stack-Manipulation/duplicate-top/command (
                instruction: [duplicate-top]
            )

            | Stack-Manipulation/duplicate-indexed/command (
                instruction: compose [duplicate-indexed (param)]
            )

            | Stack-Manipulation/swap-top-2/command (
                instruction: [swap-top-2]
            )

            | Stack-Manipulation/discard-top/command (
                instruction: [discard-top]
            )

            | Stack-Manipulation/slide-n-values/command (
                instruction: compose [slide-n-values (param)]
            )
        ]

        | Arithmetic/IMP [
            Arithmetic/add/command (
                instruction: [do-arithmetic 'add]
            )

            | Arithmetic/subtract/command (
                instruction: [do-arithmetic 'subtract]
            )

            | Arithmetic/multiply/command (
                instruction: [do-arithmetic 'multiply]
            )

            | Arithmetic/divide/command (
                instruction: [do-arithmetic 'divide]
            )

            | Arithmetic/modulo/command (
                instruction: [do-arithmetic 'mod]
            )
        ]

        | Heap-Access/IMP [
            Heap-Access/store/command (
                instruction: [do-heap-store]
            )

            | Heap-Access/retrieve/command (
                instruction: [do-heap-retrieve]
            )
        ]

        | Flow-Control/IMP [
            Flow-Control/mark-location/command (
                ; This special instruction is ignored, unless it's the
                ; first pass...
                instruction: compose [mark-location (param)]
            )

            | Flow-Control/call-subroutine/command (
                ; the call subroutine command must be told of the
                ; current parse location (a.k.a. program counter)
                ; so it can put it in the callstack
                instruction: compose [
                    call-subroutine (offset? instruction-start program-start)
                ]
            )

            | Flow-Control/jump-to-label/command (
                instruction: [jump-to-label]
            )

            | Flow-Control/jump-if-zero/command (
                instruction: [jump-if-zero]
            )

            | Flow-Control/jump-if-negative/command (
                instruction: [jump-if-negative]
            )

            | Flow-Control/return-from-subroutine/command (
                instruction: [return-from-subroutine]
            )

            | Flow-Control/end-program/command (
                instruction: [end-program]
            )
        ]

        | IO/IMP [
            IO/output-character-on-stack/command (
                instruction: [output-character-on-stack]
            )

            | IO/output-number-on-stack/command (
                instruction: [output-number-on-stack]
            )

            ; input routines not implemented yet

            | IO/read-character-to-location/command (
                print "READ NOT IMPLEMENTED"
            )

            | IO/read-number-to-location/command (
                print "WRITE NOT IMPLEMENTED"
            )
        ]
    ]
        ; Capture the current parse position at end of instruction
        instruction-end:

        ; execute the VM code and optionally give us debug output
        (
            ; This debugging output is helpful if there are malfunctions
            if extended-debug-steps [
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

            either 'mark-location == first instruction [
                if (pass == 1) [
                    if debug-steps [
                        print ["(" mold instruction ")"]
                    ]

                    ; now we capture the end of this instruction...
                    repend instruction [offset? program-start instruction-end]

                    ; the first pass does the Label markings...
                    do instruction
                ]
            ] [
                if (pass == 2) [
                    if debug-steps [
                        print ["(" mold instruction ")"]
                    ]

                    ; most instructions run on the second pass...
                    either 'end-program == first instruction [
                        next-instruction: tail program-start
                    ][
                        result: do instruction

                        if not null? result [
                            ; if the instruction returned a value, use
                            ; as the offset of the next instruction to execute
                            next-instruction: skip program-start result
                        ]
                    ]

                    execution-steps: execution-steps + 1
                ]
            ]
        )

        ; Set the parse position to whatever we set in the code above
        :next-instruction
    ]
]


;
; SAMPLE PROGRAM
;
; Here is an annotated example of a program which counts from 1
; to 10, outputting the current value as it goes.
;
; This program was given as an example in the whitespace docs:
;
;     http://compsoc.dur.ac.uk/whitespace/tutorial.php
;
; Note that space, tab, lf are defined in Rebol.  The UNSPACED
; operation turns this into a bona-fide string.  But it's "easier
; to read" (or at least, to add comments) when we start out as a
; block of symbols we reduce to characters.
;

program: unspaced [

    ; Put a 1 on the stack
    space space space tab lf

    ; Set a Label at this point
    lf space space space tab space space  space space tab tab lf

    ; Duplicate the top stack item
    space lf space

    ; Output the current value
    tab lf space tab

    ; Put 10 (newline) on the stack...
    space space space tab space tab space lf

    ; ...and output the newline
    tab lf space space

    ; Put a 1 on the stack
    space space space tab lf

    ; Addition. This increments our current value.
    tab space space space

    ; Duplicate that value so we can test it
    space lf space

    ; Push 11 onto the stack
    space space space tab space tab tab lf

    ; Subtraction. So if we've reached the end, we have a zero on the stack.
    tab space space tab

    ; If we have a zero, jump to the end
    lf tab space space tab space space  space tab space tab lf

    ; Jump to the start
    lf space lf space tab space  space space space tab tab lf

    ; Set the end Label
    lf space space space tab space  space space tab space tab lf

    ; Discard our accumulator, to be tidy
    space lf lf

    ; Finish!
    lf lf lf
]


;
; QUICK CHECK FOR VALID INPUT
;

separator: "---"

print "WHITESPACE INTERPRETER FOR PROGRAM:"
print separator
print mold program
print separator

;
; LABEL SCANNING PASS
;
; We have to scan the program for labels before we run it
; Also this tells us if all the constructions are valid
; before we start running
;

print "LABEL SCAN PHASE"

pass: 1
unless parse program whitespace-vm-rule [
    print "INVALID INPUT"
    quit
]

print mold labels
print separator

;
; PROGRAM EXECUTION PASS
;
; The Rebol parse dialect has the flexibility to do arbitrary
; seeks to locations in the input.  This makes it possible to
; apply it to a language like whitespace
;

pass: 2
either parse program whitespace-vm-rule [
    print "Program End Encountered"
    print ["stack:" mold stack]
    print ["callstack:" mold callstack]
    print ["heap:" mold heap]
][
    print "UNEXPECTED TERMINATION (Internal Error)"
]

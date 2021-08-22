Rebol [
    Title: "Whitespace Interpreter"
    Purpose: "Whitespace Language Written as a Rebol 3 Parse Dialect"

    Author: "Hostile Fork"
    Home: http://github.com/hostilefork/whitespacers/
    License: mit

    File: %whitespace.reb
    Date: 31-Jan-2019
    Version: 0.3.0

    ; Header conventions: http://www.rebol.org/one-click-submission-help.r
    Type: fun
    Level: intermediate

    Description: {
        This is an interpreter for the Whitespace language in the Ren-C branch
        of the Rebol 3 language:

        http://compsoc.dur.ac.uk/whitespace/

        What makes it somewhat unique is that it does some fairly accessible
        bending of the the language itself so that it acts like a language
        that was designed for making interpreters for languages that are
        "Whitespace-like".

        Due to being specification-driven in a homoiconic language (where data
        is code and code is data), it gains advantages in things like
        documentation generation.
    }

    Usage: {
        Run with the argument of a file that you wish to process.  The
        extension determines the handling:

        .ws  - An "official" whitespace program, where the instructions are the
               actual ASCII codes for SPACE, TAB, and LF.

        .wsw - Format based on the actual *words* `space`, `tab` and `lf`.
               Semicolons are used for comments to end of line.

        (.wsa for Whitespace Assembler format is not yet supported)
    }

    History: [
        0.1.0 [8-Oct-2009 {Private release to R3 Chat Group for commentary}]

        0.2.0 [10-Jul-2010 {Public release as part of a collection of
        whitespace interpreters in various languages}]

        0.3.0 [31-Jan-2019 {Converted to Ren-C with more ambitious concept
        of dialecting the spec blended with the instruction handling code.}]
    ]
]


do %ws-runtime.reb  ; declarations the stack and other structures
do %ws-dialect.reb  ; defines the CATEGORY and OPERATION used below


=== CONTROL SEQUENCE DEFINITIONS ===

; http://compsoc.dur.ac.uk/whitespace/tutorial.php

Stack-Manipulation: category [
    IMP: [space]

    description: {
        Stack manipulation is one of the more common operations, hence the
        shortness of the IMP [space].
    }

    push: operation [
        {Push the number onto the stack}
        space [value: Number]
    ][
        insert stack value
    ]

    duplicate-top: operation [
        {Duplicate the top item on the stack}
        lf space
    ][
        insert stack first stack
    ]

    duplicate-indexed: operation [
        {Copy Nth item on the stack (given by the arg) to top of stack}
        tab space [index: Number]
    ][
        insert stack pick stack index + 1
    ]

    swap-top-2: operation [
        {Swap the top two items on the stack}
        lf tab
    ][
        move/part stack 1 1
    ]

    discard-top: operation [
        {Discard the top item on the stack}
        lf lf
    ][
        take stack
    ]

    slide-n-values: operation [
        {Slide n items off the stack, keeping the top item}
        tab lf [n: Number]
    ][
        take/part next stack n
    ]
]


do-arithmetic: func [operator [word!]] [
    ; note the first item pushed is the left of the operation.

    let right: take stack
    let left: take stack
    insert stack do reduce [  ; we could also `reeval operator left right`
        operator left right
    ]
]


Arithmetic: category [
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

    add: operation [
        {Addition}
        space space
    ][
        do-arithmetic 'add
    ]

    subtract: operation [
        {Subtraction}
        space tab
    ][
        do-arithmetic 'subtract
    ]

    multiply: operation [
        {Multiplication}
        space lf
    ][
        do-arithmetic 'multiply
    ]

    divide: operation [
        {Integer Division}
        tab space
    ][
        do-arithmetic 'divide
    ]

    modulo: operation [
        {Modulo}
        tab tab
    ][
        do-arithmetic 'modulo
    ]
]


Heap-Access: category [
    IMP: [tab tab]

    description: {
        Heap access commands look at the stack to find the address of items
        to be stored or retrieved. To store an item, push the address then the
        value and run the store command. To retrieve an item, push the address
        and run the retrieve command, which will place the value stored in
        the location at the top of the stack.
    }

    store: operation [
        {Store}
        space
    ][
        let value: take stack  ; spec does not explicitly specify removal
        let address: take stack  ; (same)
        heap.(address): value
    ]

    retrieve: operation [
        {Retrieve}
        tab
    ][
        let address: take stack  ; spec does not explicitly specify removal
        let value: select heap address
        insert stack value
    ]
]


Flow-Control: category [
    IMP: [lf]

    description: {
        Flow control operations are also common. Subroutines are marked by
        labels, as well as the targets of conditional and unconditional jumps,
        by which loops can be implemented. Programs must be ended by means of
        [lf lf lf] so that the interpreter can exit cleanly.
    }

    mark-location: operation [
        {Mark a location in the program}
        space space [label: Label]
        <local> address  ; could use LET, but test expanded spec feature
    ][
        ; Capture the position *after* this instruction.  We calculate
        ; relative to program-start in case the whitespace data did not start
        ; right at the beginning.  Must add 1 to be in the Redbol 1-based
        ; series indexing mode (what PARSE's SEEK expects to use)
        ;
        address: 1 + offset? program-start instruction-end
        labels.(label): address
    ]

    call-subroutine: operation [
        {Call a subroutine}
        space tab [label: Label]
    ][
        ; Call subroutine must be able to find the current parse location
        ; (a.k.a. program counter) so it can put it in the callstack.
        ;
        let current-offset: offset? program-start instruction-end
        insert callstack current-offset
        return lookup-label-offset label
    ]

    jump-to-label: operation [
        {Jump unconditionally to a Label}
        space lf [label: Label]
    ][
        return lookup-label-offset label
    ]

    jump-if-zero: operation [
        {Jump to a Label if the top of the stack is zero}
        tab space [label: Label]
    ][
        ; must pop stack to make example work
        if zero? take stack [
            return lookup-label-offset label
        ]
    ]

    jump-if-negative: operation [
        {Jump to a Label if the top of the stack is negative}
        tab tab [label: Label]
    ][
        ; must pop stack to make example work
        if 0 > take stack [
            return lookup-label-offset label
        ]
    ]

    return-from-subroutine: operation [
        {End a subroutine and transfer control back to the caller}
        tab lf
    ][
        return take callstack else [
            fail "RUNTIME ERROR: return with no callstack!"
        ]
    ]

    end-program: operation [
        {End the program}
        lf lf
    ][
        ; Requesting to jump to the address at the end of the program will be
        ; the same as reaching it normally, terminating the PARSE interpreter.
        ;
        return length of program-start
    ]
]


IO: category [
    IMP: [tab lf]

    description: {
        Finally, we need to be able to interact with the user. There are IO
        instructions for reading and writing numbers and individual characters.
        With these, string manipulation routines can be written (see examples
        to see how this may be done).

        The read instructions take the heap address in which to store the
        result from the top of the stack.

        Note: spec didn't say we should pop the stack when we output, but
        the sample proves we must!
    }

    output-character-on-stack: operation [
        {Output the character at the top of the stack}
        space space
    ][
        ; Note: ISSUE! is being merged with CHAR! to be something called TOKEN!
        ; So `#a` acts as what `#"a"` was in historical Rebol.  This is a work
        ; in progress and the renaming has not yet been done.
        ;
        write-stdout make issue! first stack
        take stack
    ]

    output-number-on-stack: operation [
        {Output the number at the top of the stack}
        space tab
    ][
        ; When a number is written out, there is no newline.  So we use
        ; WRITE-STDOUT of the string conversion instead of PRINT.
        ;
        write-stdout to text! first stack
        take stack
    ]

    read-character-to-location: operation [
        {Read a character to the location given by the top of the stack}
        tab space
    ][
        ; !!! see notes above about ISSUE!/CHAR! duality, work-in-progress
        ;
        let char: ask issue! else [fail "Character Input Was Required"]
        let address: take stack
        heap.(address): codepoint of char
    ]

    read-number-to-location: operation [
        {Read a number to the location given by the top of the stack}
        tab tab
    ][
        let address: take stack
        let num: ask integer! else [fail "Integer Input Was Required"]
        heap.(address): num
    ]
]


=== PROCESS COMMAND-LINE ARGUMENTS ===

verbose: 0
strict: false
filename: null

; Note that system.script.args is the arguments given to the script, e.g. if
; you ran it from an interpreter with:
;
;     >> do/args %whitespace.reb ["--verbose" "1" "examples/tutorial.ws"]
;
; The system.options.args would reflect the arguments the interpreter itself
; had been started up with.  These are the same when running the script from
; the command line.
;
parse system.script.args [while [not <end> ||
    ["-v" | "--verbose"]
        verbose: [
            "0" (0) | "1" (1) | "2" (2) | "3" (3)
            | (fail "--verbose must be 0, 1, 2, or 3")
        ]
    |
    "--strict" (strict: true)
    |
    "--max-steps" max-steps: into text! [integer!]
    |
    into text! [
        ["--" bad: <here>]
        (fail ["Unknown command line option:" bad])
    ]
    |
    (if filename [
        fail "Only one filename allowed on command line at present"
    ])
    filename: [
        into text! [file! | url!]  ; try decoding as FILE! or URL! first
        | to-file/ text!  ; fall back to converting string TO-FILE
    ]
]]
else [
    fail "Invalid command line parameter"
]

if not filename [
    fail "No input file given"
]


=== LOAD THE SOURCE INTO PROGRAM VARIABLE ===

program: parse filename [
    thru [
        ".ws" <end> (as text! read filename)
        | ".wsw" <end> (unspaced load filename)  ; "whitespace words"
        | ".wsa" <end> (fail "WSA support not implemented yet")
    ]
] else [
    if strict [
        fail "Only `.ws`, `.wsa`, and `.wsw` formats supported in strict mode"
    ]
    as text! read filename  ; tolerate
]


=== REMOVE NON-WHITESPACE CHARACTERS FROM PROGRAM ===

; The spec of the whitespace language is supposed to skip over non-whitespace.
; If those characters are left in the program, it is a fairly high overhead
; for all the code which does decoding to filter them out.  Pre-filter.

remove-each ch program [
    all [ch != space, ch != tab, ch != lf]
]


=== QUICK CHECK FOR VALID INPUT ===

separator: "---"

if verbose >= 1 [
    print "WHITESPACE INTERPRETER FOR PROGRAM:"
    print separator
    print mold program
    print separator
]


=== LABEL SCANNING PASS ===

; We have to scan the program for labels before we run it
; Also this tells us if all the constructions are valid
; before we start running

if verbose >= 1 [
    print "LABEL SCAN PHASE"
]

pass: 1
parse program whitespace-vm-rule else [
    fail "INVALID INPUT"
]

if verbose >= 1 [
    print mold labels
    print separator
]


=== PROGRAM EXECUTION PASS ===

; The Rebol parse dialect has the flexibility to do arbitrary
; seeks to locations in the input.  This makes it possible to
; apply it to a language like whitespace

pass: 2
parse program whitespace-vm-rule else [
    fail "UNEXPECTED TERMINATION (Internal Error)"
]

if verbose >= 1 [
    print "Program End Encountered"
    print ["stack:" mold stack]
    print ["callstack:" mold callstack]
    print ["heap:" mold heap]
]

quit 0  ; signal success to calling shell via 0 exit code

Rebol [
    Title: {Whitespacer Implementation Dialect}
    File: %ws-dialect.reb

    Description: {
        Our goal is to streamline the implementation by bending Ren-C into
        something that feels like *a programming language designed specially
        for writing whitespace implementations*.  This methodology for putting
        the parts of the language to new uses is called "dialecting".
    }
]


category: func [
    return: [object!]
    definition [block!]
    <local> obj
][
    ; We want the category to create an object, but we don't want the fields of
    ; the object to be binding inside the function bodies defined in the
    ; category.  e.g. just because the category has an ADD operation, we don't
    ; want to overwrite the binding of Rebol's ADD which we would use.
    ;
    ; !!! This is part of a broad current open design question, being actively
    ; thought through:
    ;
    ; https://forum.rebol.info/t/1442
    ;
    ; It should have a turnkey solution like what this code is doing.  We just
    ; don't know exactly what to call it.

    ; First make an empty object with all the SET-WORD!s at the top level
    ;
    obj: make object! collect [
        for-each item definition [
            keep try ^(match set-word! item)
        ]
        keep [rule:]  ; we're going to add a rule
        keep [~unset~]
    ]

    ; Now, run a block which is a copy where all the SET-WORD!s are bound
    ; into the object, but only those top level set-words...nothing else.
    ;
    do map-each item definition [
        (in obj try match set-word! item) else [item]
    ]

    ; We should really know which things are operations to ask them for their
    ; rule contribution.  But just assume any OBJECT! is an operation.
    ;
    obj.rule: compose [
        (obj.imp)

        collect any @(collect [
            for-each [key val] obj [
                if key == 'rule [continue]  ; what we're setting...
                if object? val [
                    keep/line ^val.rule
                ]
            ]
        ])
    ]

    ; The category-rules list used by the runtime is run with an ANY rule, so
    ; it's just a list of alternative rules...no `|` required.
    ;
    append category-rules ^obj.rule

    return obj
]

operation: enfixed func [
    return: [object!]
    'name [set-word!]
    spec [block!]
    body [block!]
    <local> args param-name param-type pos
][
    args: copy []  ; arguments to generated FUNC are gleaned from the spec

    ; We want the operation to be a function (and be able to bind to it as
    ; if it is one).  But there's additional information we want to glue on.
    ; Historical Rebol doesn't have the facility to add data fields to
    ; functions as if they were objects (like JavaScript can).  But Ren-C
    ; offers a connected "meta" object.  We could make `some-func.field`
    ; notation access the associated meta fields, though this would be
    ; an inconsistent syntax.
    ;
    ; Temporarily just return an object, but name the action inside it the
    ; same thing as what we capture from the callsite as the SET-WORD!.
    ;
    ; Note: Since this operation is quoting the SET-WORD! on the left, the
    ; evaluator isn't doing an assignment.  We have to do the SET here.
    ;
    set name uparse spec [gather [
        emit description: [text!
            | (fail "First item of OPERATION spec must be TEXT! description")
        ]

        ; The rule's job is to match a whitespace sequence and generate a
        ; corresponding instruction block.  So we translate something like
        ; PUSH's specification for what comes after the IMP ([space]):
        ;
        ;    [space [value: Number]]  ; extracted from OPERATION spec
        ;
        ; ...into a rule for processing the input code:
        ;
        ;    [collect [keep @push space keep Number]]
        ;
        ; Which if it matches, will synthesize a block:
        ;
        ;    [push 10]
        ;
        ; Notice that patterns like `space` just match and do not contribute to
        ; the output (so no reason to KEEP anything).  But rules like `Label`
        ; do add parameters, and we want that to get KEEP'd...as with the
        ; decoded 10 integer above.
        ;
        ; There's two layers of COLLECT going on here, because we're using
        ; PARSE of the spec to build the rule.  So it has to KEEP those KEEP
        ; instructions!  It's easier than it sounds...  :-)
        ;
        ; !!! Performance note: examining the rule above, it would be more
        ; efficient to wait to emit the instruction name until the first
        ; value-synthesizing parameter:
        ;
        ;    [collect [space keep @push keep Number]]
        ;
        ; That way you don't reach the KEEP unless it was a space.  Review.

        emit rule: collect [
            ;
            ; The instruction block starts with the instruction's word name.
            ; Have the rule we're making keep that first (not a rule match,
            ; just a synthesized-from-thin-air @word...)
            ;
            keep (compose [keep @(as word! name)])

            while any @[
                ;
                ; If we hit the end, we're done processing the spec
                ;
                [<end>, stop]

                ; If we hit a tag, assume the parameters are finished and we're
                ; defining things for the function spec (<local>s, <static>s)
                ;
                [ahead tag!, append/ (args) across to <end>, stop]

                ; Plain words specify the characters, just add them to the rule
                ; for matching purposes but don't capture them.
                ;
                [keep ^['space | 'tab | 'lf]]

                ; Named parameters are in blocks, like `[location: Label]`.
                [
                    into block! [
                        param-name: to/ (word!) set-word!
                        param-type: ['Label | 'Number]
                    ]

                    ; We want the result of decoding kept as parameters to the
                    ; built instruction (e.g. KEEP the product of the Label
                    ; rule is 10 in [push 10]).  We actually want `keep Label`.
                    ;
                    keep (compose [keep (param-type)])

                    ; Add the name as a parameter to the function we are
                    ; generating that will be receiving this decoded argument.
                    ; Give it a type, e.g. `value [integer!]`
                    ;
                    (append args compose [
                        (param-name) (
                            either param-type = 'Label [[text!]] [[integer!]]
                        )
                    ])
                ]

                ; When nothing matches, it's an unexpected thing in the spec.
                ; Raise an error.
                [
                    pos: <here>
                    (fail ["Malformed operation parameter:" mold pos.1])
                ]
            ]
        ]

        ; Having figured out the number of arguments and their names implied
        ; by the whitespace language spec, make the implementation function
        ; that will be triggered by decoded rules.
        ;
        ; for `push: operation ...` this will be `push.push`, reasoning above
        ;
        ; !!! We add RETURN NULL here to make that the default if a jump
        ; address is not returned.  However, using a return value may not be
        ; the ideal way of doing this (vs. calling a JUMP-TO method on some
        ; object representing the virtual machine).  Review this especially
        ; in light of implications for hooked RETURNs being called implicitly:
        ;
        ; https://forum.rebol.info/t/1656
        ;
        emit (name): (func args compose [(as group! body), return null])
    ]]
]

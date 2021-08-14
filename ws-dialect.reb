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
        any (engroup collect [
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
    <with> param
    <local> groups args sw t
][
    args: copy []  ; arguments to generated FUNC are gleaned from the spec
    groups: copy []  ; used in the COMPOSE of the instruction's arguments

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
    set name make object! compose [
        description: ensure text! first spec

        command: collect [
            for-next pos next spec [
                any [
                    all [  ; Whitespace operations can take `Number` or `Label`
                        block? pos.1
                        parse? pos.1 [sw: set-word!, t: word!]
                        find [Number Label] ^t
                        keep ^t
                        elide if not empty? groups [
                            fail "Mechanism for > 1 operation parameter TBD"
                        ]
                        append args ^(to word! sw)
                        append groups [(param)]
                    ]
                    all [  ; Words specifying the characters
                        find [space tab lf] ^pos.1
                        keep ^pos.1
                    ]
                    all [  ; If we hit a tag, assume we're starting FUNC spec
                        tag? pos.1
                        break
                    ]
                    fail ["Malformed operation parameter:" mold pos.1]
                ]
            ]
        ]

        (elide group*: if not empty? args ['(param)])

        ; for `push: operation ...` this will be `push.push`, reasoning above
        ;
        ; !!! We add RETURN NULL here to make that the default if a jump
        ; address is not returned.  However, using a return value may not be
        ; the ideal way of doing this (vs. calling a JUMP-TO method on some
        ; object representing the virtual machine).
        ;
        (name) func args compose [((body)), return null]

        rule: compose [
            ((command)) (compose/deep '(
                compose [(to word! name) ((groups))]  ; instruction
            ))
        ]
    ]
]

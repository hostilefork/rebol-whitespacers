Rebol [
    Title: "Common Definitions for Whitespace Scripts"
    File: %ws-common.reb

    Type: Module
    Name: Whitespace-Common

    Description: {
        With the advent of modularization, you are not supposed to push
        declarations into the "global" contexts like `lib` or `user`.
        So to make definitions that are seen by all the whitespace
        script they need to be in a module that they all import.
    }
]

=== TEST USERMODE PARSER COMBINATORS ===

; Because the whitespace interpreter is an intellectual exercise, we are
; more concerned about testing cutting-edge prototypes than trying to
; perform well.  Redefine UPARSE to be PARSE, because they will converge.

export parse: :uparse
export parse*: :uparse*
export parse?: :uparse?

Rebol [
    title: "Common Definitions for Whitespace Scripts"
    file: %ws-common.r

    type: module
    name: Whitespace-Common

    description: --[
        With the advent of modularization, you are not supposed to push
        declarations into the "global" contexts like `lib` or `user`.
        So to make definitions that are seen by all the whitespace
        script they need to be in a module that they all import.
    ]--
]

; Previously this redefined PARSE to UPARSE, but that is now standard.

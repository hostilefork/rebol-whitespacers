Rebol [
    Title: --[Whitespace Script IO Validator]--
    File: %check-io.reb

    Description: --[
        This is for feeding a whitespace script's input and output files and
        making sure the output matches what was expected for the input.  It
        drives the process using the CALL facility...feeding data in and out
        through pipe mechanics.  This is useful due to being cross-platform,
        so doing shell-specific commands for diffing etc. are not necessary.

        Unfortunately, the whitespace sample programs from the reference
        interpreter seem to have standardized on the Windows line ending
        convention of CR LF.  This is considered a "foreign" codec by Ren-C:

          https://rebol.metaeducation.com/t/fight-for-the-future-cr-lf/1264

        In order to check these outputs correctly on POSIX as well as Windows,
        BINARY! is used instead of TEXT!, so the CR values don't trigger
        errors and are checked unambiguously.
    ]--
]

input: #{}
expected: #{}

filename: null

parse system.script.args [while [not <end>] [
    "--in" input: read/ to-file/ text!
    |
    "--out" expected: read/ to-file/ text!
    |
    subparse bad: text! ["--" (fail ["Unknown option:" bad])]
    |
    (if filename [fail "Only one filename permitted"])
    filename: <any>  ; let whitespace.reb interpret (may be URL!, FILE!, etc.)
]]

actual: #{}  ; use BINARY! to avoid text translations

call/input/output [
    (system.options.boot) whitespace.reb (filename)
] input actual

print as text! actual

if expected <> actual [
    print "!!! OUTPUT MISMATCH, RECEIVED:"
    print ^actual
    print "!!! EXPECTED:"
    print ^expected
    quit 1
]

quit 0

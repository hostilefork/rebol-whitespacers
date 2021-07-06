## Rebol (Ren-C) Whitespace Interpreter

This is an interpreter for the Whitespace language, using the Ren-C branch
of Rebol3:

  https://en.wikipedia.org/wiki/Whitespace_(programming_language)

  https://github.com/metaeducation/ren-c

Although Whitespace was invented as a joke (or at least, released on April
Fool's Day), making a working implementation has much of the spirit of a
"real" programming task.  The existence of implementations in Haskell, Ruby,
Perl, C++, and Python mean it is possible to take a real look at the contrast
in how you can approach the problem.

  https://github.com/wspace/corpus/

## Specified In Terms of a "Whitespace Dialect"

Any sensible implementation of a task like this will be somewhat table-driven.
Otherwise you will end up with unmaintainable spaghetti code.

But the Ren-C implementation attempts to do something novel by first bending
the Rebol language itself so that it becomes customized to seem like
*a language designed for implementing whitespace interpreters*.   

A dialect is made as a library which defines a CATEGORY and OPERATION.  This
allows the `whitespace.reb` code to be written in a way that naturally
mirrors the specification.

Here is a small piece of that from the "Stack Manipulation" category:

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

        ...
    ]

This shows a novel way of defining the PUSH function, where the category
supplies an IMP prefix (`space`).  The operation definition says PUSH is
signified by the pattern of a second `space`, after which it will extract
something matching the whitespace pattern for a number into a variable called
`value`.  The body of the function is then able to use the decoded value in the
runtime behavior when this instruction is seen. 

It's certainly possible to imagine creating such a language from scratch.  But
the promise (pipe dream?) of Rebol-based languages is to make this bend well
within reach of a layperson.  And since code-is-data and data-is-code (as in
Lisp), the aspiration is that none of the specification need go to waste...the
strings in the operation could be reflected as help.  In Ren-C the experience
is often characterized as trying to be "The Minecraft of Programming".

The devil is in the details, of course.  There are still plenty of open
questions that have been nagging Rebol derivatives due to its pariah status as
"the most freeform programming language ever invented".  Hard problems persist
in variable binding and datatype semantics.  Yet it does show some promise.

## PARSE-Based Virtual Machine

As an added gimmick for this implementation, it uses Rebol's PARSE dialect
for more than just analyzing the whitespace sequences.  It's also the virtual
machine!!!

It uses the fact that when you give the parser input to process, you can
programmatically move the parser position--back to something you've already
parsed, or forward to something you haven't seen yet.  Consequently it can be
used as a program counter!  This happens to work for the whitespace VM, though
it's probably not the best solution.  It's kind of a pun, and only done to show
an axis of flexibility in PARSE.

## Historical R3-Alpha Version Included

An early exercise for @hostilefork within a couple months of knowing Rebol's
"R3-Alpha" was to try to write a whitespace interpreter.  That code is not
particularly notable when compared with the current version.  But the experiment
is being kept alive in this repository as a test of R3-Alpha/Rebol2/Red
emulation.

## Discuss On The Forum

Discussions on this and other topics are conducted on the Ren-C Forum:

https://forum.rebol.info/

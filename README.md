# zigdoku

A simple sudoku solver that I wrote to learn more about [constraitprogrammin](https://en.wikipedia.org/wiki/Constraint_programming). 
Heavily inspired by [this blogpost](https://www.boristhebrave.com/2020/04/13/wave-function-collapse-explained/) from [BorisTheBrave](https://twitter.com/boris_brave).


# running

Without any arguments, the program will fill an empty sudoku board:

```
$ zig build
$ ./zig-out/bin/zigdoku

┌───────┬───────┬───────┐
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
├───────┼───────┼───────┤
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
├───────┼───────┼───────┤
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
│ * * * │ * * * │ * * * │
└───────┴───────┴───────┘
┌───────┬───────┬───────┐
│ 3 9 6 │ 2 1 8 │ 4 7 5 │
│ 2 5 8 │ 4 7 6 │ 1 3 9 │
│ 7 4 1 │ 3 9 5 │ 8 2 6 │
├───────┼───────┼───────┤
│ 8 3 7 │ 6 5 4 │ 9 1 2 │
│ 4 2 9 │ 1 3 7 │ 6 5 8 │
│ 1 6 5 │ 9 8 2 │ 3 4 7 │
├───────┼───────┼───────┤
│ 6 7 3 │ 5 4 9 │ 2 8 1 │
│ 9 8 4 │ 7 2 1 │ 5 6 3 │
│ 5 1 2 │ 8 6 3 │ 7 9 4 │
└───────┴───────┴───────┘
```

Given an input file describing the board, it will solve the puzzle:
```
$ cat input
___6____3
8____5___
___4__52_
____72___
_76__4___
5423__8__
_3814__95
7___3____
_2__683_7

$ ./zig-out/bin/zigdoku input
┌───────┬───────┬───────┐
│ * * * │ 6 * * │ * * 3 │
│ 8 * * │ * * 5 │ * * * │
│ * * * │ 4 * * │ 5 2 * │
├───────┼───────┼───────┤
│ * * * │ * 7 2 │ * * * │
│ * 7 6 │ * * 4 │ * * * │
│ 5 4 2 │ 3 * * │ 8 * * │
├───────┼───────┼───────┤
│ * 3 8 │ 1 4 * │ * 9 5 │
│ 7 * * │ * 3 * │ * * * │
│ * 2 * │ * 6 8 │ 3 * 7 │
└───────┴───────┴───────┘
┌───────┬───────┬───────┐
│ 2 5 4 │ 6 9 1 │ 7 8 3 │
│ 8 6 3 │ 7 2 5 │ 9 4 1 │
│ 1 9 7 │ 4 8 3 │ 5 2 6 │
├───────┼───────┼───────┤
│ 3 8 1 │ 9 7 2 │ 6 5 4 │
│ 9 7 6 │ 8 5 4 │ 1 3 2 │
│ 5 4 2 │ 3 1 6 │ 8 7 9 │
├───────┼───────┼───────┤
│ 6 3 8 │ 1 4 7 │ 2 9 5 │
│ 7 1 5 │ 2 3 9 │ 4 6 8 │
│ 4 2 9 │ 5 6 8 │ 3 1 7 │
└───────┴───────┴───────┘⏎

```

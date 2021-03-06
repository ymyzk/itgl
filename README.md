# itgl

[![Build Status](https://travis-ci.org/ymyzk/itgl.svg?branch=master)](https://travis-ci.org/ymyzk/itgl)

A type inference algorithm implementation for Implicitly Typed Gradual Language

## THIS PROJECT IS ARCHIVED
A new *interpreter* of the ITGL is available at [ymyzk/lambda-dti](https://github.com/ymyzk/lambda-dti).

## Usage
### Compile & Run interpreter
```shell
omake
./src/main/main
```

### Run unit tests
```shell
omake test
```

## Requirements
- OCaml 4.01+
- OMake
- Menhir
- OUnit2

## References
- [Principal Type Schemes for Gradual Programs. In Proc. of ACM POPL, 2015.](http://www.cs.ubc.ca/~rxg/ptsgp.pdf)

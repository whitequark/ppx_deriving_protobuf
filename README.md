[@@deriving protobuf]
=====================

_deriving protobuf_ is a [ppx_deriving][pd] plugin that generates
[Google Protocol Buffers][pb] serializers and deserializes
from an OCaml type definition.

Sponsored by [Evil Martians](http://evilmartians.com).
_protoc_ export sponsored by [MaxProfitLab](http://maxprofitlab.com/).

[pd]: https://github.com/whitequark/ppx_deriving
[pb]: https://developers.google.com/protocol-buffers/

Installation
------------

_deriving protobuf_ can be installed via [OPAM](https://opam.ocaml.org):

    $ opam install ppx_deriving_protobuf

Usage
-----

In order to use _deriving protobuf_, require the package `ppx_deriving_protobuf`.

Syntax
------

_deriving protobuf_ is not a replacement for _protoc_ and it does not attempt to generate
code based on _protoc_ definitions. Instead, it generates code based on OCaml type
definitions. It can also generate input files for _protoc_.

_deriving protobuf_-generated serializers are derived from the structure of the type
and several attributes: `@key`, `@encoding`, `@bare` and `@default`. Generation
of the serializer is triggered by a `@@[deriving Protobuf]` attribute attached
to the type definition.

_deriving protobuf_ generates two functions per type:

``` ocaml
type t = ... [@@deriving protobuf]
val t_from_protobuf : Protobuf.Decoder.t -> t
val t_to_protobuf   : t -> Protobuf.Encoder.t -> unit
```

In order to deserialize a value of type `t` from bytes `message`, use:

``` ocaml
let output = Protobuf.Decoder.decode_exn t_from_protobuf message in
...
```

In order to serialize a value `input` of type `t`, use:

``` ocaml
let message = Protobuf.Encoder.encode_exn t_to_protobuf input in
...
```

### Records

A record is the most obvious counterpart for a Protobuf message. In a record, every
field must have an explicitly defined key. For example, consider this _protoc_
definition and its _deriving protobuf_ equivalent:

``` protoc
message SearchRequest {
  required string query = 1;
  optional int32 page_number = 2;
  optional int32 result_per_page = 3;
}
```

``` ocaml
type search_request = {
  query           : string     [@key 1];
  page_number     : int option [@key 2];
  result_per_page : int option [@key 3];
} [@@deriving protobuf]
```

_deriving protobuf_ recognizes and maps `option` to optional fields, and
`list` and `array` to repeated fields.

### Optional and default fields

A `[@default]` attribute attached to a required field converts it to an optional
field; if the field is not present, its value is assumed to be the default one,
and conversely, if the value of the field is same as the default value, it is
not serialized:

``` protoc
message Defaults {
  optional int32 results = 1 [default = 10];
}
```

``` ocaml
type defaults = {
  results : int [@key 1] [@default 10];
}
```

Note that _protoc_'s default behavior is to assign a type-specific default value
to optional fields missing from message, i.e. `0` to integer fields, `""` to
string fields, and so on. With _deriving protobuf_, optional fields are represented
with the `option` type; it is possible to emulate _protoc_'s behavior by explicitly
specifying `int [@default 0]`, etc.

### Integers

Unlike _protoc_, _deriving protobuf_ allows a much more flexible mapping between
wire representations of integral types and their counterparts in OCaml.
Any combination of the known integral types (`int`, `int32`, `int64`,
`Int32.t`, `Int64.t`, `Uint32.t` and `Uint64.t`) and wire representations
(`varint`, `zigzag`, `bits32` and `bits64`) is valid. The wire representation
is specified using the `@encoding` attribute.

For example, consider this _protoc_ definition and a compatible _deriving protobuf_ one:

``` protoc
message Integers {
  required int32   bar = 1;
  required fixed64 baz = 2;
}
```

``` ocaml
type integers = {
  bar : Uint64.t [@key 1] [@encoding `varint];
  baz : int      [@key 2] [@encoding `bits64];
}
```

When parsing or serializing, the values will be appropriately extended or truncated.
If a value does not fit into the narrower type used for serialization or deserialization,
`Decoder.Error Decoder.Overflow` or `Encoder.Error Encoder.Overflow` is raised.

The following table summarizes equivalence between integral types of _protoc_
and encodings of _deriving protobuf_:

| Encoding | _protoc_ type                |
| -------- | ---------------------------- |
| varint   | int32, int64, uint32, uint64 |
| zigzag   | sint32, sint64               |
| bits32   | fixed32, sfixed32            |
| bits64   | fixed64, sfixed64            |

By default, OCaml types use the following encoding:

| OCaml type       | Encoding | _protoc_ type  |
| ---------------- | -------- | -------------- |
| int              | varint   | int32 or int64 |
| int32 or Int32.t | bits32   | sfixed32       |
| Uint32.t         | bits32   | fixed32        |
| int64 or Int64.t | bits64   | sfixed64       |
| Uint64.t         | bits64   | fixed64        |

Note that no OCaml type maps to zigzag-encoded `sint32` or `sint64` by default.
It is necessary to use <code>[@encoding `zigzag]</code> explicitly.

### Floats

Similarly to integers, `float` maps to _protoc_'s `double` by default,
but it is possible to specify the encoding explicitly:

``` protoc
message Floats {
  required float  foo = 1;
  required double bar = 2;
}
```

``` ocaml
type floats = {
  foo : float [@key 1] [@encoding `bits32];
  bar : float [@key 2];
} [@@deriving protobuf]
```

### Booleans

`bool` maps to _protoc_'s `bool` and is encoded on wire using `varint`:

``` protoc
message Booleans {
  required bool bar = 1;
}
```

``` ocaml
type booleans = {
  bar : bool [@key 1];
} [@@deriving protobuf]
```

### Strings and bytes

All of `string`, `String.t`, `bytes` and `Bytes.t` map to _protoc_'s `string` or
`bytes` and are encoded on wire using `bytes`:

Note that unlike _protoc_, which has an additional invariant that the contents of
a `string` must be valid UTF-8 text, _deriving protobuf_ does not have this invariant.
However, you still should observe it in your programs.

``` protoc
message Strings {
  required string bar = 1;
  required bytes  baz = 2;
}
```

``` ocaml
type strings = {
  bar : string [@key 1];
  baz : bytes  [@key 2];
} [@@deriving protobuf]
```

### Tuples

A tuple is treated in exactly same way as a record, except that keys are derived
automatically starting at 1. The definition of `search_request` above could be
rewritten as:

``` ocaml
type search_request' = string * int option * int option
[@@deriving protobuf]
```

Additionally, a tuple can be used in any context where a scalar value is expected;
in this case, it is equivalent to an anonymous inner message:

``` protoc
message Nested {
  message StringFloatPair {
    required string str = 1;
    required float  flo = 2;
  }
  required int32 foo = 1;
  optional StringFloatPair bar = 2;
}
```

``` ocaml
type nested = {
  foo : int                     [@key 1];
  bar : (string * float) option [@key 2];
} [@@deriving protobuf]
```

### Variants

An OCaml variant types is normally mapped to an entire Protobuf message by _deriving protobuf_,
as opposed to _protoc_, which maps an `enum` to a simple `varint`. This is done because
OCaml constructors can have arguments, but _protoc_'s `enum`s can not.

Note that even if a type doesn't have any constructor with arguments, it is still mapped
to a message, because it would not be possible to extend the type later with a constructor
with arguments otherwise.

Every constructor must have an explicitly specified key; if the constructor has one argument,
it is mapped to an optional field with the key corresponding to the key of the constructor
plus one. If there is more than one argument, they're treated like a tuple.

Consider this example:

``` protoc
message Variant {
  enum T {
    A = 1;
    B = 2;
    C = 3;
    D = 4;
  }
  message C {
    required string foo = 1;
    required string bar = 2;
  }
  message D {
    required string s1 = 1;
    required string s2 = 2;
  }
  required T t = 1;
  optional int32 b = 3; // (B = 2) + 1
  optional C c = 4; // (C = 3) + 1
  optional D d = 5; // (D = 4) + 1
}
```

``` ocaml
type variant =
| A                              [@key 1]
| B of int                       [@key 2]
| C of string * string           [@key 3]
| D of {s1: string ; s2: string} [@key 4]
[@@deriving protobuf]
```

Note that decoder considers messages which contain more than one optional field
invalid and rejects them.

In order to achieve better compatibility with _protoc_, it is possible to embed
a variant where no constructors have arguments without wrapping it in a message:

``` protoc
enum BareVariant {
  A = 1;
  B = 2;
}
message Container {
  required T value = 1;
}
```

``` ocaml
type bare_variant =
| A [@key 1]
| B [@key 2]
and container = {
  value : bare_variant [@key 1] [@bare];
} [@@deriving protobuf]
```

In practice, if a variant has no constructors with arguments, additional two
functions are generated with the following signatures:

``` ocaml
type t = A | B | ... [@@deriving protobuf]
val t_from_protobuf_bare : Protobuf.Decoder.t -> t
val t_to_protobuf_bare   : Protobuf.Encoder.t -> t -> unit
```

These functions do not expect additional framing; they just parse or serialize
a single `varint`.

### Polymorphic variants

Polymorphic variants are handled in exactly same way as regular variants. However,
you can also embed them directly, like tuples, in which case the semantics is
the same as defining an alias for the variant and then using that type.

This feature can be combined with the `[@bare]` annotation to create a useful
shorthand:

``` protoc
message Packet {
  enum Type {
    REQUEST = 1;
    REPLY   = 2;
  }
  required Type  type  = 1;
  required int32 value = 2;
}
```

``` ocaml
type packet = {
  type  : [ `Request [@key 1] | `Reply [@key 2] ] [@key 1] [@bare];
  value : int [@key 2];
} [@@deriving protobuf]
```

### Type aliases

A type alias (statement of form `type a = b`) is treated by _deriving protobuf_ as
a definition of a message with one field with key 1:

``` protoc
message Alias {
  required int32 val = 1;
}
```

``` ocaml
type alias = int [@@deriving protobuf]
```

### Nested messages

When _deriving protobuf_ encounters a non-scalar type, it generates a call to
the serialization or deserialization function corresponding to the full path
to the type.

Consider this definition:

``` ocaml
type foo = bar * Baz.Quux.t [@@deriving protobuf]
```

The generated deserializer code will refer to `bar_from_protobuf` and
`Baz.Quux.t_from_protobuf`; the serializer code will call `bar_to_protobuf`
and `Baz.Quux.t_to_protobuf`.

### Packed fields

Types which are encoded as `varint`, `bits32` or `bits64`, that is, numeric
fields or bare variants, can be declared as "packed" with the `[@packed]` attribute,
in which case the serializer emits a more compact representation. Only _protoc_ newer
than 2.3.0 will recognize this representation. Note that the deserializer
understands it regardless of the presence of `[@packed]` attribute.

``` protoc
message Packed {
  repeated int32 elem = 1 [packed=true];
}
```

``` ocaml
type packed = int list [@key 1] [@packed] [@@deriving protobuf]
```

### Parametric polymorphism

_deriving protobuf_ is able to handle polymorphic type definitions. In this case,
the serializing or deserializing function will accept one additional argument
for every type variable; correspondingly, the value of this argument will be
passed to serializer or deserializer of any nested parametric type.

Consider this example:

``` ocaml
type 'a mylist =
| Nil                    [@key 1]
| Cons of 'a * 'a mylist [@key 2]
[@@deriving protobuf]
```

Here, the following functions will be generated:

``` ocaml
val mylist_from_protobuf : (Protobuf.Decoder.t -> 'a) -> Protobuf.Decoder.t ->
                           'a mylist
val mylist_to_protobuf   : (Protobuf.Decoder.t -> 'a -> unit) -> Protobuf.Decoder.t ->
                           'a mylist -> unit
```

An example usage would be:

``` ocaml
type a = int [@@deriving protobuf]

let get_ints message =
  let decoder = Protobuf.Decoder.of_bytes message in
  mylist_from_protobuf a_from_protobuf decoder
```

It's also possible to specify concrete types as parameters; in this case, _deriving protobuf_
will infer the serializer/deserializer functions automatically. For example:

``` ocaml
(* Combining two samples above *)
type b = a mylist [@@deriving protobuf]
```

Error handling
--------------

Both serializers and deserializers rigorously verify their input data. The only
possible exception that can be raised during serialization is
`Protobuf.Encoder.Failure`, and during deserialization is `Protobuf.Decoder.Failure`.

### Decoder errors

The decoder attempts to annotate its failures with useful location information,
but only if that wouldn't cost too much in terms of performance and complexity.

In general, as long as you're using the same protocol on both sides, deserialization
or should never raise. The errors would mainly arise when interoperating
with code generated by _protoc_ that doesn't observe OCaml-specific invariants,
or when handling malicious input.

It discerns these types of failure (represented with `Decoder.Failure` exception):

  * `Incomplete`: the message was truncated or using invalid wire format. Frame
    overruns are likely to produce this as well.
  * `Overlong_varint`: a `varint` greater than 2⁶⁴-1 was encountered.
  * `Malformed_field`: an invalid wire type was encountered.
  * `Overflow fld`: an integer field in the message contained a value outside
    the range of the corresponding type, e.g. a `varint` field corresponding
    to `int32` contained `0xffffffff`.
  * `Unexpected_payload (fld, kind)`: a key corresponding to field `fld`
    had a wire type incompatible with the specified encoding, e.g.
    a `varint` wire type for a nested message.
  * `Missing_field fld`: a required field `fld` was missing from the message.
  * `Malformed_variant fld`: a variant `fld` contained a key not corresponding
    to any defined constructor.

The decoder errors refer to fields via so-called "paths"; a path corresponds
to the OCaml syntax for referring to a type, field or constructor, but can
contain additional `/<number>` (e.g. `/0`) component for an immediate tuple.

For example, the `string` field will have the path `Foo.r.ra/1`:

``` ocaml
(* foo.ml *)
type r = {
  ra: (int * string) option [@key 1];
} [@@deriving protobuf]
```

### Encoder errors

The encoder discerns these types of failure (represented with `Encoder.Failure`
exception):

  * `Overflow fld`: an integer value was outside the range of its corresponding
    encoding, e.g. a `int64` containing `0xffffffffffff` was serialized to
    `bits32`.

The encoder errors use the same "path" convention as decoder errors.

Extending protocols
-------------------

In real-world applications, implementations using multiple versions of the same
protocol must coexist. Protocol Buffers offer an imperfect and sometimes
complicated, but very powerful and practical solution to this problem.

The wire protocol is designed in a way that allows to safely extend it if
one follows a set of constraints.

### Always

Any of the following changes may be applied to either the sender or receiver
of the message without breaking protocol:

  * Adding an optional field to a record, or an optional element to a tuple,
    or an optional argument to a constructor **with multiple arguments**.
  * Converting an optional field, tuple element or constructor argument
    into a repeated one.
  * Converting an optional field, tuple element or constructor argument
    into a required field with a default value, or vice versa.
  * Converting a repeated field, tuple element or constructor argument
    into an optional one (this is not recommended, as it silently ignores
    some of input data).
  * Turning an alias into a record that has a field marked `[@key 1]`.
  * Turning an alias into a tuple where the first element is the former
    type of the alias (this is not recommended for reasons of code clarity).

### Never

When communicating bidirectionally, violating any of the following constraints
always results in exceptions or receiving garbage data:

  * Never change `[@key]` or `[@encoding]` annotations; never add or remove
    `[@bare]` annotation.
  * Never change primitive (i.e. excluding `list`, `option` or `array` qualifiers)
    types of existing fields, tuple elements or constructor arguments.
  * Never remove required fields, tuple elements or constructor arguments.
  * Never replace a primitive type of a field, tuple element or constructor argument
    with a tuple, even if the first element of the replacing tuple is
    the former primitive type.
  * Never add arguments to an argument-less variant constructor, or vice versa.

The following sections list some exceptions to this rule when the communication
is unidirectional.

### On sender

Any of the following changes may be applied exclusively to the sender
without breaking the existing receivers:

  * Adding a required field, tuple element, or argument to a constructor
    **with multiple arguments**.
  * Converting an optional or repeated field, tuple element or constructor
    argument into a required one.
  * Replacing an integer type with a narrower one while preserving
    the encoding (it's a good idea to add the `[@encoding]` annotation
    explicitly).
  * Adding a variant constructor, but never actually sending it.

### On receiver

Any of the following changes may be applied exclusively to the receiver
without losing the ability to decode messages from existing senders:

  * Removing a required field, tuple element, or argument to a constructor
    **with more than two arguments**.
  * Replacing an integer type with a wider one while preserving the encoding
    (it's a good idea to add the `[@encoding]` annotation explicitly).

Protoc export
-------------

_deriving protobuf_ can export message types in _proto2_ language, the format
that _protoc_ accepts; _protoc_ version 2.6 or later is required.

To enable _protoc_ export, pass a `protoc` option to _deriving protobuf_:

```
(* foo.ml *)
type msg = ... [@@deriving protobuf { protoc }]
```

Compiling this file will create a file called `Foo.protoc` (note the capitalization)
in a directory adjacent to `foo.ml`; if you are using ocamlbuild and `foo.ml`
is located in directory `src/`, the file will be generated at `_build/src/Foo.protoc`.
This can be customized by providing a path explicitly, e.g.
`[@@deriving protobuf { protoc = "Bar.protoc" }]`; the path is interpreted
relative to the source file.

The mapping between OCaml types and _protoc_ messages is straightforward.

OCaml modules become _protoc_ packages with the same name.
A nested module, e.g. `module Bar` in our `foo.ml`, becomes a nested package,
`Foo.Bar`; it will be emitted in a file `Foo.Bar.protoc`, placed adjacent to
`Foo.protoc`, since _protoc_ requires every package to reside in its own file.

OCaml records and their fields become _protoc_ messages and fields with
the same name:

``` ocaml
type msg = {
  name:  string [@key 1];
  value: int    [@key 2];
} [@@deriving protobuf { protoc }]
```

``` protoc
message msg {
  required string name = 1;
  required int64 value = 2;
}
```

OCaml variants and their constructors become _protoc_ messages and fields
with the same name; additionally generated are a nested enum called
`_tag` whose constants have the same name as constructors with `_tag`
appended, and a field named `tag` with the type `_tag`:

``` ocaml
type msg =
| A [@key 1]
| B of string [@key 2]
[@@deriving protobuf { protoc }]
```

``` protoc
message msg {
  enum _tag {
    A_tag = 1;
    B_tag = 2;
  }

  required _tag tag = 1;
  oneof value {
    string B = 3;
  }
}
```

OCaml tuples become _protoc_ messages with the same name whose fields
are called `_N` with `N` being the field index:

``` ocaml
type msg = int * string
[@@deriving protobuf { protoc }]
```

``` protoc
message msg {
  required int64 _0 = 1;
  required string _1 = 2;
}
```

OCaml aliases become _protoc_ messages with one field called `_`:

``` ocaml
type msg = int
[@@deriving protobuf { protoc }]
```

``` protoc
message msg {
  required int64 _ = 1;
}
```

Sometimes, a single toplevel OCaml type definition has to be translated
into several messages, e.g. when a field or a constructor contains a tuple
or a polymorphic variant. In this case, such messages become nested messages
whose name is the name of the field or constructor with `_` prepended:

``` ocaml
type msg = {
  field: int * string [@key 1]
}
[@@deriving protobuf { protoc }]
```

``` protoc
message msg {
  message _field {
    required int64 _0 = 1;
    required string _1 = 2;
  }

  required _field field = 1;
}
```

Normally, when a type from another module is referenced, _deriving protobuf_
automatically generates the corresponding _protoc_ `import` directive:

``` ocaml
type imported = Other.msg
[@@deriving protobuf { protoc }]
```

``` protoc
import "Other.protoc";
message imported {
  required Other.msg _ = 1;
}
```

However, when a type is referenced that was defined in a module defined earlier
in the same file, the produced `import` directive is incorrect.
(_deriving protobuf_ does not have an accurate model of OCaml's module scoping.)
In this case, the `protoc_import` option can help:

``` ocaml
(* foo.ml *)
module Bar = struct
  type msg = int [@@deriving protobuf { protoc }]
end

type alias = Bar.msg
[@@deriving protobuf { protoc; protoc_import = ["Foo.Bar.protoc"] }]
```

``` protoc
// Foo.protoc
package Foo;
import "Foo.Bar.protoc";
message alias {
  required Bar.msg _ = 1;
}
```

``` protoc
// Foo.Bar.protoc
package Foo.Bar;
message msg {
  required int64 _ = 1;
}
```

Compatibility
-------------

Protocol Buffers specification [suggests][optional] that if a message contains
multiple instances of a `required` or `optional` nested message, those nested
messages should be merged. However, there is no concept of "merging messages"
accessible to _deriving protobuf_, and this feature can be considered harmful anyway:
it is far too forgiving of invalid input. Thus, _deriving protobuf_ doesn't implement
this merging.

_deriving protobuf_ is more strict than _protoc_ with numeric types; it raises
`Failure (Overflow fld)` rather than silently truncate values. It is thought
that accidentally losing 32th or 64th bit with OCaml's `int` type would be
a common error without this countermeasure.

Everything else should be entirely compatible with _protoc_.

[optional]: https://developers.google.com/protocol-buffers/docs/encoding#optional

API Documentation
-----------------

The documentation for internal API is available at
[GitHub pages](http://whitequark.github.io/ppx_deriving_protobuf/).

License
-------

[MIT](LICENSE.txt)

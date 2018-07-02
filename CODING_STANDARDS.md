The following coding standards are in place to assist in shared development of the Chapel Hypergraph Library (CHGL). Following these standards will ease code readability and maintenance. While modifications and suggestions are welcome, please consult the development team to get concurrence prior to making changes.

Single Namespace
================

As the Chapel language itself is within a single namespace, CHGL can also be used as a single namespace via ``use CHGL;``. However, sub-modules can be used individually when only portions of the library are required. E.g., ``use CHGL.Components;``

CamelCase
=========

Generally, use CamelCase or camelCase instead of separating_with_underscores. Specific rules follow below:

* Modules, records, classes, and types are UpperCamelCase
* Methods and variables are lowerCamelCase

Private vs Public
=================

As Chapel currently does not have access modifiers, by convention CHGL prefixes private members with an underscore. Direct use of prefixed members will result in undefined behavior. For example ``publicMethod()`` vs ``_privateMethod()``.

Method Names and Part-of-Speech
===============================

One of the nice things about a well-designed method names is that it's easy to mentally translate from a method call into a sentence. For example, myNode.accept(someThing) can be translated into "myNode, please accept someThing". In order for this to work, method names that represent an action should generally be a verb.

Module, record, class, type, variable and parameter names are nouns. Accessor methods can be named using a noun. E.g., student.height() fits into that category.

Module Naming vs Type Naming
============================

Names should use the convention of making the module name a more specific/spelled out version of the type names, in particular when the module contains only one type.  Examples:

* class Block is in module BlockDist
* class BigInt can be in module BigInteger
* class Barrier can be in module TaskBarrier

Whitespace
==========

The following whitespace rules apply:

* Use tabs instead of spaces for code block indentation, allowing developers to set their own IDE's preferred tab width. 
* No line length requirements outside of requesting lines be a length that generally remains easily readable.
* Newlines should use the Unix/Linux ``\n`` character instead of Windows ``\r\n``
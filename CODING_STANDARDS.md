Single Namespace
================

Style guide should note many of these decisions are there to aid developers in working with the fact that Chapel is single-namespace language.

CamelCase
=========

Generally, prefer CamelCase or camelCase to separating_with_underscores.

Style of Identifier Names
=========================

* Modules should be CamelCase, starting with an uppercase letter
* Types should be CamelCase or lowercase. User-defined types should generally start with an uppercase letter and be CamelCase (e.g. RandomStream,Timer). Internal types can be lowercase (e.g. int, domain,bigint)
  * ? Alternative option? Value types start with lower case, class types start with uppercase?
* Methods should be camelCase and start with a lowercase letter
* Variables should be camelCase or CamelCase.
  * Q: Should constant variables or params have a different rule?

Method Names and Part-of-Speech
===============================

One of the nice things about a well-designed method names is that it's easy to mentally translate from a method call into a sentence. For example, myNode.accept(someThing) can be translated into "myNode, please accept someThing". In order for this to work, method names that represent an action should generally be a verb.

Field names can be nouns. Some methods are sortof accessors or similar to them. In that case I don't have a problem with using a noun. I think that student.height() fits into that category.

In the case of replicand, I don't have a problem with A.replicand because it's arguably accessing a property of A. What is some evidence that it's a "property" rather than an "action"?

* it's accessing something fundamentally stored in the data structure (A replicated array might be viewed as consisting of replicands...)
* It returns something that makes sense as the LHS of an assignment statement

In other words, if I was writing complete English sentences in my programming, A.replicand would be a noun phrase that I would presumably then want to do something else with using a verb. A.replicand.split() for an arbitrary example, has reasonable code-to-English properties.

Module Naming vs Type Naming
============================

When creating a module that mainly exists to define a single type, how should one choose the type name and the module name?

I think we should use the convention of making the module name a more specific/spelled out version. Examples:

* class Block is in module BlockDist
* class BigInt can be in module BigInteger
* class Barrier can be in module TaskBarrier

I think that this is a useful and reasonable convention because the module name seems to me to be more likely to be visible as introductory material:

* at the top of a file, in a 'use' statement
* in the module documentation pages

And, at the same time, I would expect the module name to appear fewer times in user code than the class name. Thus it is less troublesome for the module name to be longer.
# Task::Popular
[Introduction](#introduction)    
[Module Listing](#modules-in-this-distribution)  
[Date of Compilation](#date-of-compilation)  
[Problems](#problems)  
[Updates and Algorithm](#updates-and-algorithm)

## Introduction

The developers of Perl6 decided early on that the implementation
of the language (eg. Rakudo) would be available with a bare minimum of "core" modules.
Some modules are essential, such as Test, or the module manager (previously `panda`, currently `zef`).

The intention is for users / user groups to contribute distributions that meet a specific topic area.
Rakudo is available in a package called `Rakudo Star` with a minimal number of modules.

However, for someone coming to Perl6 for the first time, there is a natural question as to which
modules 'should' be installed first to provide the dependencies most other modules will need.
Since 'should' can be quite subjective, and space is a limited resource, there no solution for newcomers has yet been agreed.

Another problem (at the time of writing) is that Perl6 has a rapidly expanding Ecosystem (available modules),
whilst the language itself
continues to evolve. This means that modules which were well-tested and useful at one moment in time are being
replaced by other modules or get out of date. Consequently, any list of 'necessary' modules has to
be monitored on a regular basis.

This distribution list takes another, data driven, approach.

Some modules provide common functionality, and so are `use`d or **cited** by other modules in the Ecosystem.
Consequently, by chosing a set of modules that are
frequently used, it can be fairly safely assumed they will be regularly maintained. Failures in these modules will affect other modules.

This list uses [Citation Indices](http://finanalyst.github.io/ModuleCitation/) to identify the 30 modules most recursively popular modules in the Ecosystem.

## Modules in this distribution

| Module Name | Recursive Citation Index | Module Description |
|---| :---: | :--- |

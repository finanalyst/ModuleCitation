# Task::Popular
[Introduction](#introduction)    
[Module Listing](#modules-in-this-distribution)  
[Date of Compilation](#date-of-compilation)  
[Problems](#problems)  
[Updates and Algorithm](#updates-and-algorithm)

## Introduction

The developers of Perl6 decided that the implementation
of the language (eg. Rakudo) would be available with a bare minimum of "core" modules.
Some modules are essential, such as Test, or the module manager (previously `panda`, currently `zef`).

The intention is for users / user groups to contribute distributions that meet a specific topic area.
Rakudo itself is available in a package called `Rakudo Star` with a minimal number of modules.

This distribution list takes another, data driven, approach.

Modules are intended to provide common functionality, and so are `use`d or **cited** by other modules in the Ecosystem. A set of modules that are
frequently used can be fairly safely assumed will be regularly maintained. Failures in these modules will affect many other modules, and there will be pressure to get them fixed. 

This list uses [Citation Indices](http://finanalyst.github.io/ModuleCitation/) to identify the 30 modules most recursively popular modules in the Ecosystem.

## Modules in this distribution

| Module Name | Recursive Citation Index | Module Description |
|---| :---: | :--- |

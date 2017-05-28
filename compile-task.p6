#!/usr/bin/env perl6
use v6.c;
use lib 'lib';
use ModuleCitation;

my ModuleCitation $mc .=new;
$mc.compile-popular-task;

#!/usr/bin/env perl6
use v6.c;
use lib 'lib';
use ModuleCitation;

my ModuleCitation $mc .= new;
$mc.get-latest-project-file;
$mc.update;
$mc.update-csv-files;
$mc.generate-html;

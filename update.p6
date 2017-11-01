#!/usr/bin/env perl6
use v6.c;
use lib 'lib';
use ModuleCitation;

sub MAIN( Bool :$v=False ) {
  my ModuleCitation $mc .= new( :verbose($v));
#  $mc.get-latest-project-file;
  $mc.update;
  $mc.update-csv-files;
  $mc.generate-html;
}

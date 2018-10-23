#!/usr/bin/env perl6
use v6.c;
use lib 'lib';
use ModuleCitation;

sub MAIN( Bool :verbose(:$v) = True ) {
  my ModuleCitation $mc .= new;
  $mc.verbose = $v;
  $mc.get-latest-project-files;
  note "A json or ecosystem error occurred. Check log." unless $mc.update;
  $mc.update-csv-files;
  $mc.generate-html;
}

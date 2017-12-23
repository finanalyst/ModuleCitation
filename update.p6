#!/usr/bin/env perl6
use v6.c;
use lib 'lib';
use ModuleCitation;

sub MAIN( Bool :$v=True ) {
  my ModuleCitation $mc .= new( :verbose($v));
  $mc.get-latest-project-files;
  until ( $mc.update or $++ > 5 ) {};
  # if update returns false, there is a problem with a downloaded file, so try to download again.
  # try 5 times and then give up
  $mc.update-csv-files;
  $mc.generate-html;
}

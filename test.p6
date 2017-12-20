use v6.c;

class Something {
  method action(--> Bool ) {
    die 'not ok';
  }

}
use Test;

my Something $hi .= new();

lives-ok { $hi.action }, "we're OK";

done-testing;

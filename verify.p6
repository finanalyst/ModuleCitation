use v6.c;
use lib 'lib';
use ModuleCitation;
use JSON::Fast;

my $json = from-json('data-2017-11-02.json'.IO.slurp);
my ModuleCitation $mc .= new(:verbose);
$mc.add-date('2017-11-02', $json);

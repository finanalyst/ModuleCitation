use v6;
use Test;
use ModuleCitation;
use JSON::Tiny;

my $data = q:to/DATA/;
{ "abc":{ "nqp":"*","Test":"1 "
	},
  "cds": {
	},
  "edf": {"cds":"1"
	},
  "www":{ "abc":"9","cds":"0"
	},
  "nqp":{
	},
  "Test":{"edf":"3"
	},
  "ddd":{ "cds":"2", "bad":"2"
        },
  "__date": "123456789"
}
DATA

my $mc = ModuleCitation.new(:citing( from-json $data ));
isa-ok $mc , ModuleCitation, "MC created with citing" ;
is-deeply $mc.ecosystem.sort, <abc cds edf www nqp Test ddd>.sort, 'Ecosystem keys right';
is $mc.date, "123456789", 'date caught';

lives-ok { $mc.citations-from( 'xyz' ) }, 'Non-ecosystem module (simple) lives but is added to non-ecosystem';
is $mc.non-ecosystem.keys.elems, 1, 'bad module keys increased';
is-deeply $mc.non-ecosystem.keys, ('xyz', ), 'bad module added to non-ecosystem list';

lives-ok { $mc.citations-from( 'zzz', :recursive(True)) }, 'Non-ecosystem module (recursion)';
is $mc.non-ecosystem.keys.elems, 2, 'new bad module added';
is-deeply $mc.non-ecosystem.keys.sort, <xyz zzz>, 'bad module name added to non-ecosystem list';
lives-ok { $mc.citations-from( 'ddd', :recursive(True)) }, 'Non-ecosystem recursive citation';
is $mc.non-ecosystem.keys.elems, 3, 'new recursive bad module added';
is-deeply $mc.non-ecosystem.keys.sort, <bad xyz zzz>, 'bad module name added to non-ecosystem list';

is $mc.citations-from( 'cds'), (), 'simple (non-recursive) citing on module without ancestors returns empty list';
is-deeply |$mc.citations-from( 'edf' ), <cds>, 'simple citing on module with one level ancestor returns list';
is-deeply $mc.citations-from( 'abc').flat.sort , <nqp Test>.sort, 'simple does not cite recursive structure';

is $mc.citations-from( 'cds',:recursive(True) ), (), 'recursive citing on module without ancestors returns empty list';
is-deeply |$mc.citations-from( 'edf',:recursive(True) ), <cds>, 'recursive citing on module with one level ancestor returns list';
is-deeply $mc.citations-from( 'abc',:recursive(True) ).flat.sort , <nqp Test edf cds>.sort, 'recursive cites recursive structure';
$mc.limit = 2;
dies-ok { $mc.citations-from( 'abc',:recursive(True) ).flat.sort }, 'recursive abyss hit';



done-testing;

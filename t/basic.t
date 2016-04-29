use v6;
use Test;
use Test::Output;

use ModuleCitation;

my $data = q:to/DATA/;
{ "abc":{ "nqp":"*","Test":"1"
	},
  "cds": {
	},
  "edf": {"cds":"1"
	},
  "www":{ "abc":"9","cds":"0"
	},
  "nqp":{"edf":"1","cds":"12" 
	},
  "Test":{"edf":"3"
	},
  "ddd":{ "cds":"2", "bad":"2"
        },
  "__date": "2016-12-13T00:00:00Z"
}
DATA

my $mc = ModuleCitation.new(:in-string( $data ));
isa-ok $mc , ModuleCitation, "MC created with citing" ;

is $mc.citing.perl, '{:Test(${:edf("3")}), :abc(${:Test("1"), :nqp("*")}), :bad($()), :cds(${}), :ddd(${:bad("2"), :cds("2")}), :edf(${:cds("1")}), :nqp(${:cds("12"), :edf("1")}), :www(${:abc("9"), :cds("0")})}', 'Citing is correct';

is-deeply $mc.ecosystem.sort, <abc cds edf www nqp ddd>.sort, 'Ecosystem keys right and \'Test\' eliminated';
is-deeply $mc.non-ecosystem.keys, ('bad', ), 'bad module automatically added to non-ecosystem list when parsing citing';

is $mc.date, "2016-12-13T00:00:00Z", 'date caught';

is-deeply $mc.citations-from( 'www' ).sort, ('abc','cds').sort, 'Simple method works';
is-deeply |$mc.citations-from( 'abc' ), <nqp>, 'Simple method works and \'Test\' not counted';
is-deeply $mc.citations-from( 'www', :mode<recursive> ).flat.sort, ("abc", "cds", "cds", "cds", "edf", "nqp").sort, 'Recursive method works';

lives-ok { $mc.citations-from( 'xyz' ) }, 'Non-ecosystem module (simple) lives but is added to non-ecosystem';
is $mc.non-ecosystem.keys.elems, 2, 'bad module keys increased';
is-deeply $mc.non-ecosystem.keys, <bad xyz>, 'bad module added to non-ecosystem list';

lives-ok { $mc.citations-from( 'zzz', :mode<recursive> ) }, 'Non-ecosystem module (recursion)';
is $mc.non-ecosystem.keys.elems, 3, 'new bad module added';

is-deeply $mc.non-ecosystem.keys.sort, <bad xyz zzz>, 'bad module name added to non-ecosystem list';
lives-ok { $mc.citations-from( 'ddd', :mode<recursive>) }, 'Non-ecosystem recursive citation';
is $mc.non-ecosystem.keys.elems, 3, 'new recursive bad module added';
is-deeply $mc.non-ecosystem.keys.sort, <bad xyz zzz>, 'bad module name added to non-ecosystem list';

is-deeply $mc.citations-from( 'cds'), Nil, 'simple (non-recursive) citing on module without ancestors returns empty list';
is-deeply |$mc.citations-from( 'edf' ), <cds>, 'simple citing on module with one level ancestor returns list';

is $mc.citations-from( 'cds',:mode<recursive> ), (), 'recursive citing on module without ancestors returns empty list';
is-deeply |$mc.citations-from( 'edf',:mode<recursive> ), <cds>, 'recursive citing on module with one level ancestor returns list';
is-deeply $mc.citations-from( 'abc',:mode<recursive> ).flat.sort , <nqp edf cds cds>.sort, 'recursive cites recursive structure';
$mc.limit = 2;
stderr-like { $mc.citations-from( 'abc',:mode<recursive> ).flat.sort }, / Recursion \s* limit .* passed /, 'recursive abyss hit';

is $mc.tot-modules, 6, 'number of modules correct';

is $mc.tot-cited, 4, 'number of cited modules is correct';

done-testing;

# testing for Initialisation
use v6.c;
use Test;
use Test::Output;
use lib 'lib';
use File::Directory::Tree;

for <tmp tmp/db tmp/arc > {
  mktree $_ unless $_.IO.d;
  empty-directory $_;
}

temp $*CWD ~= '/tmp';

#--MARKER-- Test 1
use-ok 'ModuleCitation', "module loads";
use ModuleCitation;
my ModuleCitation $mc;

#--MARKER-- Test 2
dies-ok { $mc .= new() }, "dies without config file";

'config.json'.IO.spurt: q:to/CONF/;
{
    "database-name": "ndb",
     "ecosystem-urls":["www.domain.org",],
     ""
}
CONF

#--MARKER-- Test 3
dies-ok { $mc .= new() }, "dies with bad config file";

'config.json'.IO.spurt: q:to/CONF/;
{
  "database-name": "citations",
  "ecosystem-urls": {
      "ecosys": {
          "date": "2000-01-01",
          "url": "http://ecosystem-api.p6c.org/projects.json"
      },
      "cpan6": {
          "date": "2017-10-17",
          "url": "https://raw.githubusercontent.com/ugexe/Perl6-ecosystems/master/cpan.json"
      }
  },
  "archive-directory": "arc",
  "target-directory": "db",
  "html-template": "../CitationTemplate.tmpl",
  "html-directory": "html",
  "logfile": "citations.log",
  "top-limit": "10",
  "task-popular-directory": "popular",
  "task-popular-number": "30"
}
CONF

#--MARKER-- Test 4
lives-ok { $mc .= new() }, "object created with config";

#--MARKER-- Test 5
is $mc.configuration<database-name>, "citations", "configures ok";
#--MARKER-- Test 6
ok "$*CWD/{$mc.configuration<target-directory>}/{$mc.configuration<database-name>}.sqlite3".IO.f,
  "database is created";
my $sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT name FROM sqlite_master WHERE type='table'
  STATEMENT
$sth.execute;
#--MARKER-- Test 7
is-deeply $sth.allrows, (['projectfiles'], ['cited']), "correct tables";

#--MARKER-- Test 8
nok $mc.configuration<logfile>.IO.f, "No log file on initiation";

$mc.log("Test the log  file");
#--MARKER-- Test 9
ok $mc.configuration<logfile>.IO.f, "Log file created";

"$*CWD/../t-data/test-ok.json".IO.copy: "$*CWD/{$mc.configuration<archive-directory>}/projects_ecosys_2001-01-01T1234Z.json";
my $rv;
#--MARKER-- Test 10
lives-ok { $rv = $mc.update }, "update routine lives";
#--MARKER-- Test 11
ok $rv, "update gives normal return to test file";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT module, simple FROM cited WHERE system=2 ORDER BY module
  STATEMENT
$sth.execute;
my @res= $sth.allrows;
#--MARKER-- Test 12
is-deeply @res.Seq, (["TotalCited", 5], ["TotalEcosystem", 23], ["TotalXEcosystem", 1]), "date in db with test-ok.json as expected";
# transfer some files to archive-directory
for "$*CWD/../t-data".IO.dir( test => /'projects'/ ) { .copy: "$*CWD/{$mc.configuration<archive-directory>}/{ .subst(/^ .* '/' /,'') }" };
#--MARKER-- Test 13
lives-ok { $rv = $mc.update }, "adds test files to database";
#--MARKER-- Test 14
nok $rv, "an update error should be detected";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(date) as 'Num' FROM projectfiles where date='2015-11-20'
  STATEMENT
$sth.execute;
#--MARKER-- Test 15
is $sth.row(:hash)<Num>, 5, "Correct number of duplicate files";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(type) as 'Num' FROM projectfiles
  WHERE date='2015-11-20' AND type='duplicate'
  STATEMENT
$sth.execute;
#--MARKER-- Test 16
is $sth.row(:hash)<Num>, 4, "Correct number of files marked 'duplicate'";

$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(type) as 'Num' FROM projectfiles
  WHERE date='2017-10-25' AND type='ecosys-err'
  STATEMENT
$sth.execute;
#--MARKER-- Test 17
is $sth.row(:hash)<Num>, 1, "Incomplete ecosystem detected for 2017-10-25";

diag "create project files with depends errors to be trapped";
"$*CWD/{$mc.configuration<archive-directory>}/projects_0_2015-01-01.json".IO.spurt(q:to/PROJ/);
  [{
      "depends": [],
      "provides": {
          "Acme::Meow": "lib/Acme/Meow.pm"
      },
      "name": "Acme::Meow",
      "version": "*"
  }, {
      "version": "*",
      "name": "JSON::Tiny",
      "provides": {
          "JSON::Tiny::Actions": "lib/JSON/Tiny/Actions.pm",
          "JSON::Tiny::Grammar": "lib/JSON/Tiny/Grammar.pm",
          "JSON::Tiny": "lib/JSON/Tiny.pm"
      },
      "depends": []
  }]
  PROJ

$mc.verbose = True;
#--MARKER-- Test 18
output-like { $mc.update }, /'Filename' .* 'doesn\'t match pattern'/, "filename error trapped";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT type FROM projectfiles WHERE filename='projects_0_2015-01-01.json'
  STATEMENT
$sth.execute;
#--MARKER-- Test 19
is-deeply $sth.allrows, (['name-err'],), "Name error is caught";

$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(type) as Err FROM projectfiles WHERE type='name-err'
  STATEMENT
$sth.execute;
#--MARKER-- Test 20
is $sth.row(:hash)<Err>,1, "One file labled with name error";

"$*CWD/{$mc.configuration<archive-directory>}/projects_ecosys_2001-01-02T1235Z.json".IO.spurt(q:to/PROJ/);
  [{
      "depends": ["JSON::Tiny"],
      "provides": {
          "Acme::Meow": "lib/Acme/Meow.pm"
      },
      "name": "Acme::Meow",
      "version": "*"
  }, {
      "version": "*",
      "name": "JSON::Tiny",
      "provides": {
          "JSON::Tiny::Actions": "lib/JSON/Tiny/Actions.pm",
          "JSON::Tiny::Grammar": "lib/JSON/Tiny/Grammar.pm",
          "JSON::Tiny": "lib/JSON/Tiny.pm"
      },
      "depends": []
  }, {
      "depends": [],
      "name": "Testing",
      "version": "*",
      "provides": {
          "Testing": "lib/Testing.pm",
          "JSON::Tiny": "lib/JSON/Tiny.pm"
      }
  }]
  PROJ

$mc.verbose=True;
#--MARKER-- Test 21
output-like { $mc.update } , /'Data for' .+ 'added to cited'/, 'Two modules providing same sub-module are allowed';

"$*CWD/{$mc.configuration<archive-directory>}/projects_ecosys_2001-02-01T1235Z.json".IO.spurt(q:to/PROJ/);
  [{
      "depends": ["JSON::Tiny"],
      "provides": {
          "Acme::Meow": "lib/Acme/Meow.pm"
      },
      "name": "Acme::Meow",
      "version": "*"
  }, {
      "version": "*",
      "name": "JSON::Tiny",
      "provides": {
          "JSON::Tiny::Actions": "lib/JSON/Tiny/Actions.pm",
          "JSON::Tiny::Grammar": "lib/JSON/Tiny/Grammar.pm",
          "JSON::Tiny": "lib/JSON/Tiny.pm"
      },
      "depends": []
  }, {
      "depends": []
      "name": "Testing",
      "version": "*",
      "provides": {
          "Testing": "lib/Testing.pm",
          "JSON::Tiny": "lib/JSON/Tiny.pm"
      }
  }]
  PROJ

#--MARKER-- Test 22
  output-like { $mc.update } , /'JSON error reading'/, 'JSON error is caught and logged';
  $sth = $mc.dbh.prepare(q:to/STATEMENT/);
    SELECT type FROM projectfiles WHERE filename='projects_ecosys_2001-02-01T1235Z.json'
    STATEMENT
  $sth.execute;
#--MARKER-- Test 23
  is-deeply $sth.allrows, (['json-err'],), "Json error is marked in database";
  "$*CWD/{$mc.configuration<archive-directory>}/projects_ecosys_2001-02-02T1235Z.json".IO.spurt(q:to/PROJ/);
    [{
        "depends": ["JSON::Tiny"],
        "provides": {
            "Acme::Meow": "lib/Acme/Meow.pm"
        },
        "name": "Acme::Meow",
        "version": "*"
    }, {
        "version": "*",
        "name": "JSON::Tiny",
        "provides": {
            "JSON::Tiny::Actions": "lib/JSON/Tiny/Actions.pm",
            "JSON::Tiny::Grammar": "lib/JSON/Tiny/Grammar.pm",
            "JSON::Tiny": "lib/JSON/Tiny.pm"
        },
        "depends": ["hoopla"]
    },{
        "depends": ["Acme::Meow"],
        "provides": {
            "Acme::Meow": "lib/Acme/Meow.pm"
        },
        "name": "hoopla",
        "version": "*"
    }]
    PROJ
#--MARKER-- Test 24
    output-like { $mc.update } , /'Tarjan strongly connected components found'/, 'Tarjan caught and logged';
    $sth = $mc.dbh.prepare(q:to/STATEMENT/);
      SELECT type FROM projectfiles WHERE filename='projects_ecosys_2001-02-02T1235Z.json'
      STATEMENT
    $sth.execute;
#--MARKER-- Test 25
    is-deeply $sth.allrows, (['tarjan-err'],), "Tarjan error is marked in database";
    "$*CWD/{$mc.configuration<archive-directory>}/projects_ecosys_2001-02-03T1235Z.json".IO.spurt(q:to/PROJ/);
      [{
          "depends": ["JSON::Tiny"],
          "provides": {
              "Acme::Meow": "lib/Acme/Meow.pm"
          },
          "name": "Acme::Meow",
          "version": "*"
      }, {
          "version": "*",
          "name": "JSON::Tiny",
          "provides": {
              "JSON::Tiny::Actions": "lib/JSON/Tiny/Actions.pm",
              "JSON::Tiny::Grammar": "lib/JSON/Tiny/Grammar.pm",
              "JSON::Tiny": "lib/JSON/Tiny.pm"
          },
          "depends": ["hoopla"]
      },
      {
        "name" : "SemVer",
        "source-url" : "http://www.cpan.org/authors/id/T/TY/TYIL/Perl6/SemVer-0.1.1.tar.gz",
        "perl" : "6.c",
        "resources" : [
      null
        ],
        "depends" : [
      null
        ],
        "tags" : [ ],
        "provides" : {
          "SemVer" : "lib/SemVer.pm6"
        },
        "version" : "0.1.1",
        "meta-version" : 1,
        "description" : "Class representing a semantic version",
        "authors" : "Patrick Spek <p.spek@tyil.email>"
      }
      ]
      PROJ
#--MARKER-- Test 26
      output-like { $mc.update } , /'Add <projects_ecosys_2001-02-03T1235Z.json> to projectsfile as valid'/, 'Zero depends Ok';

done-testing;

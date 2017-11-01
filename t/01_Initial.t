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
  "ecosystem-urls": [
    "http://ecosystem-api.p6c.org/projects.json",
    "https://raw.githubusercontent.com/ugexe/Perl6-ecosystems/master/cpan.json"
  ],
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

$mc.log("My test");
#--MARKER-- Test 9
ok $mc.configuration<logfile>.IO.f, "Log file created";

#--MARKER-- Test 10
lives-ok { $mc.get-latest-project-file }, "getting new project file";
my @list = dir $mc.configuration<archive-directory>;
#--MARKER-- Test 11
is @list.elems, 2, "two files downloaded";

#--MARKER-- Test 12
lives-ok { $mc.update }, "update routine lives";
# transfer some files to archive-directory
for "$*CWD/../t-data".IO.dir( test => /'projects'/ ) { .copy: "$*CWD/{$mc.configuration<archive-directory>}/{ .subst(/^ .* '/' /,'') }" };
#--MARKER-- Test 13
lives-ok { $mc.update}, "adds test files to database";

$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(date) as 'Num' FROM projectfiles where date='2015-11-20'
  STATEMENT
$sth.execute;
my %similar = $sth.row(:hash);
#--MARKER-- Test 14
ok %similar<Num> == 5, "Correct number of duplicate files";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(valid) as 'Num' FROM projectfiles
  WHERE date='2015-11-20' AND valid='Duplicate'
  STATEMENT
$sth.execute;
%similar = $sth.row(:hash);
#--MARKER-- Test 15
ok %similar<Num> == 4,"Correct number of files marked 'duplicate'";

done-testing;

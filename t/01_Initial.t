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

use-ok 'ModuleCitation', "module loads";
use ModuleCitation;
my ModuleCitation $mc;

dies-ok { $mc .= new() }, "dies without config file";

'config.json'.IO.spurt: q:to/CONF/;
{
    "database-name": "ndb",
     "ecosystem-urls":["www.domain.org",],
     ""
}
CONF

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

lives-ok { $mc .= new() }, "object created with config";
is $mc.configuration<database-name>, "citations", "configures ok";
ok "$*CWD/{$mc.configuration<target-directory>}/{$mc.configuration<database-name>}.sqlite3".IO.f,
  "database is created";
my $sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT name FROM sqlite_master WHERE type='table'
  STATEMENT
$sth.execute;
is-deeply $sth.allrows, (['projectfiles'], ['cited']), "correct tables";

nok $mc.configuration<logfile>.IO.f, "No log file on initiation";

$mc.log("My test");
ok $mc.configuration<logfile>.IO.f, "Log file created";

lives-ok { $mc.get-latest-project-file }, "getting new project file";
my @list = dir $mc.configuration<archive-directory>;
ok @list[0].f, "file downloaded";

lives-ok { $mc.update }, "adds one file to database";
# transfer some files to archive-directory
for "$*CWD/../t-data".IO.dir( test => /'projects'/ ) { .copy: "$*CWD/{$mc.configuration<archive-directory>}/{ .subst(/^ .* '/' /,'') }" };
lives-ok { $mc.update}, "adds several files to database";

$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(date) as 'Num' FROM projectfiles where date='2015-11-20'
  STATEMENT
$sth.execute;
my %similar = $sth.row(:hash);
ok %similar<Num> == 5, "Correct number of duplicate files";
$sth = $mc.dbh.prepare(q:to/STATEMENT/);
  SELECT count(valid) as 'Num' FROM projectfiles
  WHERE date='2015-11-20' AND valid='Duplicate'
  STATEMENT
$sth.execute;
%similar = $sth.row(:hash);
ok %similar<Num> == 4,"Correct number of files marked 'duplicate'";

done-testing;

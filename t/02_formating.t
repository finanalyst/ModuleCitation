# testing for Initialisation
use v6.c;
use Test;
use Test::Output;
use lib 'lib';
use File::Directory::Tree;

mktree 'tmp/html' unless 'tmp/html'.IO.d;
empty-directory 'tmp/html';

temp $*CWD ~= '/tmp';

use ModuleCitation;
my ModuleCitation $mc .=new();

lives-ok {$mc.update-csv-files }, "update csv method lives";
ok 'html/GraphFile_AllModules.csv'.IO.f, "All mods file created";
ok 'html/GraphFile_simple.csv'.IO.f, "Simple mods file created";
ok 'html/GraphFile_recursive.csv'.IO.f, "Recursive mods file created";

lives-ok { $mc.generate-html }, "Html generate method lives";
ok 'html/index.html'.IO.f, "Index file is created in html directory";

# my ModuleCitation $newmc .= new(:verbose);
# $newmc.dbh.do(q:to/STATEMENT/);
#   DELETE FROM projectfiles
#   WHERE date='2015-11-20'
#   STATEMENT
# stdout-like { $newmc.update }, / 'Adding' .*? 'to cited table' /, "Logging message goes to Stdout when verbose is on";

done-testing;

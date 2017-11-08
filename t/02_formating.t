use v6.c;
use Test;
use Test::Output;
use lib 'lib';
use File::Directory::Tree;
use JSON::Fast;

for <tmp/html tmp/popular > {
  mktree $_ unless $_.IO.d;
  empty-directory $_;
}

# transfer some files to test directories
for <readme.start.md readme.end.md> { copy( "t-data/$_", "tmp/$_" )  };
copy( "t-data/META6.json", "tmp/popular/META6.json" );

do {
  temp $*CWD ~= '/tmp';

  use ModuleCitation;
  my ModuleCitation $mc .=new();

#--MARKER-- Test 1
  lives-ok {$mc.update-csv-files }, "update csv method lives";
#--MARKER-- Test 2
  ok 'html/GraphFile_AllModules.csv'.IO.f, "All mods file created";
#--MARKER-- Test 3
  ok 'html/GraphFile_simple.csv'.IO.f, "Simple mods file created";
#--MARKER-- Test 4
  ok 'html/GraphFile_recursive.csv'.IO.f, "Recursive mods file created";

#--MARKER-- Test 5
  lives-ok { $mc.generate-html }, "Html generate method lives";
#--MARKER-- Test 6
  ok 'html/index.html'.IO.f, "Index file is created in html directory";

#--MARKER-- Test 7
  lives-ok { $mc.compile-popular-task }, "Method compile-popular-task lives";
#--MARKER-- Test 8
  ok 'popular/README.md'.IO.f, "Readme is created";

$mc.verbose=True;
  $mc.dbh.do(q:to/STATEMENT/);
    DELETE FROM projectfiles
    WHERE date='2015-11-20'
    STATEMENT
#--MARKER-- Test 9
stdout-like { $mc.update }, / 'Adding data for' .* 'to projectsfile table' /, "Logging message goes to Stdout when verbose is on";

diag "testing the depends structure";
$mc.verbose=False;
my $err;
my %mods;
#--MARKER-- Test 10
lives-ok { ($err, %mods) = $mc.analyse-dep( from-json(q:to/END/) ) }, "analyse-dep method lives";
  [
    "Sereal:auth<cpan:*>:ver(1..*)",
    "JSON::Fast",
    [ "Archive::Compress", "Archive::Zlib" ]
  ]
  END
#--MARKER-- Test 11
is $err, '', 'No errors on plain list';
#--MARKER-- Test 12
is %mods.elems, 4, 'found 4 modules';
($err, %mods) = $mc.analyse-dep( from-json(q:to/END/));
  {
    "runtime": {
      "requires": [
        "Sereal:auth<cpan:*>:ver(1..*)",
        "JSON::Fast"
      ],
      "recommends": [
        "JSON::Pretty"
      ]
    },
    "build": {
      "requires": [
        "System::Info"
      ]
    },
    "test": {
      "requires": [
        "File::Temp"
      ]
    }
  }
  END
#--MARKER-- Test 13
is $err, '', 'hash version parses';
($err, %mods) = $mc.analyse-dep(from-json(q:to/END/));
  [
    {
      "name": "archive:from<native>",
      "hints": {
        "by-kernel.name": {
          "win32": {
            "url": "http://www.p6c.org/~jnthn/libarchive/libarchive.dll",
            "checksum": {"sha-256": "E6836E32802555593AEDAFE1CC00752CBDA"},
            "target": "resources/libraries/"
          }
        }
      }
    }
  ]
  END
#--MARKER-- Test 14
is $err,'','array with hints ok';
($err, %mods) = $mc.analyse-dep(from-json(q:to/END/));
  {
    "runtime": [
      {
        "name": "svm:from<native>",
        "hints": {
          "source": {
            "builder": "MakeFromJSON",
              "build": {
                "src-dir": "src",
                "makefile-variables": {
                  "VERSION": "3.22",
                  "svm": {"resource": "libraries/svm"}
                }
             }
          }
        }
      }
    ]
  }
  END
#--MARKER-- Test 15
is $err,'','hash with info ok';

# depends field from App::Cpan6
($err, %mods) = $mc.analyse-dep(from-json(q:to/END/));
  {
    "test": {
      "requires": [
        "Test::META"
      ]
    },
    "runtime": {
      "recommends": [
        "git:from<bin>"
      ],
      "requires": [
        "Config",
        "Config::Parser::toml",
        "JSON::Fast",
        "Template::Mustache",
        "MIME::Base64",
        "File::Temp",
        "curl:from<bin>",
        "tar:from<bin>"
      ]
    }
  }
  END
#--MARKER-- Test 16
  is $err, '', 'real test works';

  diag "Downloading from internet";
  my @list = dir $mc.configuration<archive-directory>;
  my $old-num = @list.elems;
  $mc.verbose = False;
#--MARKER-- Test 17
  lives-ok { $mc.get-latest-project-files }, "getting new project files";
  @list = dir $mc.configuration<archive-directory>;
#--MARKER-- Test 18
  is @list.elems, $old-num + 2, "two new files downloaded";

}

empty-directory 'tmp';
shell('rmdir tmp');
done-testing;

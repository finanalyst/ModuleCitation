#!/usr/bin/env perl6
use v6.c;
use JSON::Fast;

=begin pod
  Extract module base-names from a valid depends structure
  provide list of valid modules, valid being
  - module is in depends list
  - module is one of alternatives in depends list
  - module is the 'name' part of a HASH element
  - module is in 'requires' or 'recommends' elements of HASH structure
  assign meta data for each valid module based on adverbs

  Two depends structures
  - Array of elements
  - Hash of Sections

  Element is
  - module name
  - Array of module names (equivalents)
  - Hash of information about module, with module name in 'name' field

  Section is Hash of
  - 'requires' points to Array of elements
  - 'recommends' points to Array of elements
  - other information fields
=end pod

my regex base-name { \w [<-[:]>|| '::' ] * }; # a module contains at least one word character or :: but not a single :
my regex adverb {
  ':' $<a-name>=(\w+)
    [ \( ~ \) $<a-val>= (.+?)
    |  \< ~ \> $<a-val>= (.+?)
#    |      '<<' ~ '>>' $<a-val>= (.+)
#    | \« ~ \» $<a-val>= (.+)
    ]  }; # an adverb starts with ':', contains at least one word char and has a value delimited  by brackets
my regex module { <base-name> <adverb>* }; # full spec is a base-name and [no] adverbs

my %deps = (); # set up a test array of depends
%deps<a> = from-json(q:to/END/);
  [
    "Sereal:auth<cpan:*>:ver(1..*)",
    "JSON::Fast",
    [ "Archive::Compress", "Archive::Zlib" ]
  ]
  END
%deps<b> = from-json(q:to/END/);
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
%deps<c> = from-json(q:to/END/);
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
%deps<d> = from-json(q:to/END/);
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
# depends field from App::Cpan6
%deps<e> = from-json(q:to/END/);
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

my $err-msg;
my %modules;
for %deps.kv -> $k, $dep-str {
  say "\ntest $k";
  ($err-msg, %modules) = analyse-dep($dep-str);
  dd %modules;
  $err-msg.say;
}

sub analyse-dep( $dep-str --> List ) {
  my %mods = ();
  my $err = 'Errors: ';
  given $dep-str.WHAT.^name {
    when 'Array' {
      for $dep-str.list -> $spec {
        given $spec.WHAT.^name {
          when 'Str' { # a simple module name
            if $spec ~~ /<module>/ {
              my %v = ();
              for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
              %mods{ $<module><base-name> } = %v;
            } else { $err ~= "Wrong module pattern: $spec\n"}
          }
          when 'Array' { # a list of module names, which are alternatives
            for $spec.list -> $elem {
              if $elem ~~ /<module>/ {
                my %v = ();
                for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                %mods{ $<module><base-name> } = %v;
              } else { $err ~= "Wrong module pattern: $elem\n"}
            }
          }
          when 'Hash' { # an element contains hints as well as the Module name
            with $spec<name> { # ignore any hash element not containing an module name
              if $spec<name> ~~ /<module>/ { # only need the information in the name field
                  my %v = ();
                  for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                  %mods{ $<module><base-name> } = %v;
                } else { $err ~= 'Wrong module pattern: ' ~ $spec<name> ~ "\n" }
              }
            }
          default {
            $err ~= 'Unknown module pattern: ' ~ $spec ~ "\n";
          }
        }
      }
    }
    when 'Hash' {
      for $dep-str.kv -> $phase, $phase-spec {
        for <requires recommends> -> $act { #ignore other fields
          next without $phase-spec{$act};
          for $phase-spec{$act}.list -> $spec {
            given $spec.WHAT.^name {
              when 'Str' { # a simple module name
                if $spec ~~ /<module>/ {
                  my %v = ();
                  for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                  %mods{ $<module><base-name> } = %v;
                } else {  $err ~= "Wrong module pattern: $spec\n"}
              }
              when 'Array' { # a list of module names, which are alternatives
                for $spec.list -> $elem {
                  if $elem ~~ /<module>/ {
                    my %v = ();
                    for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                    %mods{ $<module><base-name> } = %v;
                  } else { $err ~= "Wrong module pattern: $elem\n" }
                }
              }
              when 'Hash' { # an element contains hints as well as the Module name
                with $spec<name> { # ignore any hash element not containing an module name
                  if $spec<name> ~~ /<module>/ { # only need the information in the name field
                      my %v = ();
                      for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                      %mods{ $<module><base-name> } = %v;
                    } else { $err ~= 'Wrong module pattern: ' ~ $spec<name> ~ "\n"}
                  }
                }
              default {
                $err ~= 'Unknown module pattern: ' ~ $spec ~ "\n";
              }
            }
          }
        }
      }
    }
  }
  return ($err, %mods);
}

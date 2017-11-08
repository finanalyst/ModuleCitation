use v6.c;
my @core=<Test zef NativeCall>;
my @subs = <JSON::Tiny JSON::Fast Test Helpful>;
my %alias= <JSON::Fast JSON::Actions FutureActions> Z=> <JSON::Tiny JSON::Tiny Useful>;
my @res = #map { %alias{$_} // $_ },
#  grep { any @core },
#  @subs;
  gather for @subs { take %alias{$_ } // $_ unless $_ eq any @core }
dd @res;

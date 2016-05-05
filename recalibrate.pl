#! env perl6

use JSON::Fast;
my %citing;
my %citing_old;
my $name;

for dir( './archive', test=> / ^ CitationData / ) -> $file {
    say "processing $file";
    %citing = ();
    %citing_old = from-json($file.IO.slurp );
    for %citing_old.kv -> $mod , $dep {
        say "\tModule: <$mod> -> ",$dep.gist;
        unless $dep.WHAT ~~ Hash {
            %citing{$mod} = $dep;
            next
        }
        if $mod ~~ / ^ [ <-[:]> || '::' ] * / {
            $name = $/;
            my %ndeps;
            say "\t\t$mod -> $name";
            for %($dep).kv -> $k, $v {
                if $k ~~ / ^ [ <-[:]> || '::' ] * / {
                    %ndeps{$/} = $v; 
                    say "\t\t\t$k -> $/"; #/
                } else { warn "In file <$file> dependent module $k skipped" }
            }
            %citing{$name} = %ndeps;
        } else { warn "In file <$file> module $mod skipped" }
    }
    $file.IO.spurt: to-json(%citing);
}


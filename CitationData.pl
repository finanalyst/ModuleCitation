#!/usr/bin/env perl6
#
#Takes in the Citation data produced by CitationGather
#Calculates the Citation number, Citation index, and Citation placement for each of the last NNN dates
# The output csv is given the same name as the last date used.

use ModuleCitation;

multi MAIN ( Int :$max-dates = -1, Int :$top = 50  ) {

    my @Citationfiles = dir( './archive', test=> / ^ CitationData / ).sort;
    my $files = ($max-dates < 0 or @Citationfiles.elems < $max-dates) ?? @Citationfiles.elems !! $max-dates;

    my $mc;
    
    my %citPlaces;
    my @citIndicies;
    my $pos;
    
    for ( 1 .. $files ).reverse -> $d {
        @citIndicies = ();
        $pos = $files - $d;
        say "Processing filename {$pos + 1}\: {@Citationfiles[* - $d]}";
        $mc = ModuleCitation.new( :in-string( @Citationfiles[* - $d].IO.slurp ) ); 

        for $mc.ecosystem -> $mod {
                @citIndicies.push: [ $mod, 
                        |( gather for $mc.parts { 
                                take 100 * $mc.citations{$mod}{ $_ } / $mc.tot-cited ;
                        } )
                ]
        }

        for $mc.parts.kv -> $k, $part {
                for @citIndicies.sort(*.[$k + 1]).reverse.[0 ..^ $top] -> @v { 
                        %citPlaces{ $part }<data>{ @v[0] }[ $pos ] = @v[$k+1] ;
                }
                %citPlaces{$part}<ModulesCited>[$pos] = $mc.tot-cited;
                %citPlaces{$part}<AllModules>[$pos] = $mc.tot-modules;
                %citPlaces{$part}<Date>[$pos] = $mc.date.Date;
        }
    }
    my @modules;
    my @meta =  <Date ModulesCited AllModules> ;
    for $mc.parts -> $part { 
        @modules = %citPlaces{$part}<data>.keys.sort ;
        my $fh = open "../git_html/GraphFile_$part\.csv", :w; # $mc is currently holding the last date
        $fh.say( join( ',', @meta, @modules ) );
        for 0..^ $files -> $d { 
            $fh.say( @meta.map( { %citPlaces{$part}{$_}[$d] } ).join(',') , ',', 
                     @modules.map( { %citPlaces{$part}<data>{$_}[$d]:exists ?? %citPlaces{$part}<data>{$_}[$d] !! 'NaN' } ).join(',')
                    );
        }
        $fh.close;
    }
    
}
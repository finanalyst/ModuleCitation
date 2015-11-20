#!/usr/bin/env perl6
#
#Takes in the Citation data produced by CitationGather
#Calculates the Citation number, Citation index, and Citation placement

use ModuleCitation;

multi MAIN ( Int :$top = 50, Int :$col = 2, Bool :$textfile = True, Bool :$html = False, Bool :$screen = True, Int :$rowtotal = 50) {

	use JSON::Fast;

	my @Citationfiles = dir( './archive', test=> / ^ CitationData / ).sort;

	my $mc = ModuleCitation.new( :citing( from-json @Citationfiles[*-1].IO.slurp ) );
	my %cited;

	for $mc.ecosystem -> $citer {
		next unless $mc.citing{$citer}.keys;
		for <simple recursive> -> $part { 
			for $mc.citations-from( $citer, :recursive( ?($part ~~ m/ recur /) ) ).flat -> $cited { 
				%cited{$part}{ $cited }{ $citer } = 1 ; 
				# instead of a SetHash. If the element exists, it will be replaced
			}
		}
	}
	
	my %citNumbers;
	my %citPlaces;
	my @citIndicies;
	my $total-cited;
	my $row = $top % $col;
	$row++ while $row * $col < $top;

	my $all-modules = +$mc.ecosystem;
	my $max-name = %cited.keys.map( { slip( %cited{$_}.keys ) } )>>.chars.max; # longest name in both sections of cited

	for %cited.kv -> $part, %cited-part { 
		%citNumbers{ $part } = hash( gather for %cited-part.sort>>.kv -> ($mod, $list) {
				take $mod => +$list.keys;
			} )
	}

	$total-cited = +(%citNumbers<simple>.keys);
	# simple and recursive totals should be the same

	for $mc.ecosystem -> $mod {
		@citIndicies.push: [ $mod, 
			|( gather for $mc.parts { 
				take 100 * ( 
					%citNumbers{ $_ }{ $mod }:exists ?? 
						%citNumbers{ $_ }{ $mod } / $total-cited 
						!! 0
				)	
			} )
		]
	}

	for 0 .. 1 -> $part {
		for @citIndicies.sort(*.[$part+1]).reverse.kv -> $n, @v { 
			%citPlaces{ @v[0] }[2 * $part  ] = $n + 1 ;
			%citPlaces{ @v[0] }[2 * $part+1] = @v[$part + 1];
		}
	}

	if $screen {
		say "Date gathered               = { $mc.date }";
		say "Ecosystem compliant modules = $all-modules";
		printf "Modules cited               =%4d\n", $total-cited;
		printf "Cited / Compliant modules   =%6.2f%%\n", 
			100 * $total-cited / $all-modules ;
	

		for  $mc.parts.kv -> $npart, $part {
			say "\nCitation Index of Top $top modules, sorted in $part order";
			for 0 ..^ $col -> $c { printf("%-{$max-name}s   Simple     Recursive ",'Module') };
			print("\n");
			for 0 ..^ $col -> $c { printf("%-{$max-name}s  #  Index     #  Index ",'------') };
			print("\n");
			my @modules = @citIndicies.sort( *.[$npart + 1] ).reverse.map( *.[0] );
			for 0 ..^ $row -> $r {
				for 0 ..^ $col -> $c {
					my $n = $c * $row + $r;
					if $n < $top {
						printf("%-{$max-name}s% 4d:%6.2f % 4d:%6.2f ",
					       		@modules[$n],
							%citPlaces{@modules[$n]}[0], 
							%citPlaces{@modules[$n]}[1],
							%citPlaces{@modules[$n]}[2],
							%citPlaces{@modules[$n]}[3]
					     	 );
				       }
				}
				print("\n");
			}
		}
		say "Note: Citation index = <# times cited by any module> / <# cited modules> x 100";
		if $mc.non-ecosystem.keys.elems {
			temp $max-name = $mc.non-ecosystem.keys>>.chars.max;
			say "\nModules are cited that are not in a top-line module in the ecosystem. They are:";
			for $mc.non-ecosystem.keys -> $cited {
				printf("%-{$max-name}s is cited by %s\n", $cited, %cited<simple>{$cited}.keys.join( ', ' ) );
			}
			say "Reason: module may be in a \"depends\" list, but actually in a sub-directory of another top-line module";
		}
	}

	if $textfile {
		say "Summary output to: Citation_{$mc.date}.dat";
	
		my $fh = open "Citation_{$mc.date}.dat", :w;
		$fh.say("Date gathered               = { $mc.date }");
	        $fh.say("Ecosystem compliant modules = $all-modules");
		$fh.print(sprintf("Modules cited               =%4d\n", $total-cited));
		$fh.print(sprintf("Cited / Compliant modules   =%6.2f%%\n", 
			100 * $total-cited / $all-modules ));
	
		for $mc.parts.kv -> $npart, $part {
			$fh.say( "\nCitation Index of Top $top modules, sorted in $part order" );
			for 0 ..^ $col -> $c { $fh.print(sprintf("%-{$max-name}s   Simple     Recursive ",'Module')) };
			$fh.print("\n");
			for 0 ..^ $col -> $c { $fh.print(sprintf("%-{$max-name}s  #  Index     #  Index ",'------')) };
			$fh.print("\n");
			my @modules = @citIndicies.sort( *.[$npart + 1] ).reverse.map( *.[0] );
			$fh.print("\n");
			for 0 ..^ $row -> $r {
				for 0 ..^ $col -> $c {
					my $n = $c * $row + $r;
					if $n < $top {
						$fh.print(sprintf("%-{$max-name}s% 4d:%6.2f % 4d:%6.2f ",
					       		@modules[$n],
							%citPlaces{@modules[$n]}[0], 
							%citPlaces{@modules[$n]}[1],
							%citPlaces{@modules[$n]}[2],
							%citPlaces{@modules[$n]}[3]
					     	 ));
				       }
				}
				$fh.print("\n");
			}
		}
		$fh.say("\nNote: Citation index = <# times cited by any module> / <# cited modules> x 100");
		if $mc.non-ecosystem.keys.elems {
			$fh.say( "\nModules are cited that are not top-line modules in the ecosystem. They are:");
			for $mc.non-ecosystem.keys -> $cited {
				$fh.print(sprintf("%-{$max-name}s is cited by %s\n", $cited, %cited<simple>{$cited}.keys.join( ', ' ) ));
			}
			$fh.say("Reason: module may be in a \"depends\" list, but actually in a sub-directory of another top-line module");
		}
	} # end of text output
	# output in HTML
	#
	if $html {
		say "\nProcessing HTML files\n";

		use HTML::Template;
		my $template = HTML::Template.from_file( 'CitationTemplate.tmpl' );
		my %params = N_MOD => $all-modules, 
			N_CIT => $total-cited, 
			PC_CIT => sprintf("%6.2f%%",100 * $total-cited / $all-modules), 
			DATE => $mc.date.Date.Str,
			N_ROWS => $rowtotal;

		
		my @errors;
		my @citPlaces_s = @citIndicies.sort(*.[1]).reverse.map( *.[0] );
		my @citPlaces_r = @citIndicies.sort(*.[2]).reverse.map( *.[0] );

		for 0 ..^ $rowtotal -> $n {
			%params<modules>.push( %( 
				:s_name(  sprintf("%s",    @citPlaces_s[$n]                ) ), 
				:s_s_ord( sprintf("% 3d",   %citPlaces{@citPlaces_s[$n]}[0] ) ), 
				:s_s_sim( sprintf("%6.2f", %citPlaces{@citPlaces_s[$n]}[1] ) ), 
				:s_r_ord( sprintf("% 3d",   %citPlaces{@citPlaces_s[$n]}[2] ) ), 
				:s_r_rec( sprintf("%6.2f", %citPlaces{@citPlaces_s[$n]}[3] ) ), 
				:r_name(  sprintf("%s",    @citPlaces_r[$n]                ) ), 
				:r_s_ord( sprintf("% 3d",   %citPlaces{@citPlaces_r[$n]}[0] ) ), 
				:r_s_sim( sprintf("%6.2f", %citPlaces{@citPlaces_r[$n]}[1] ) ),
				:r_r_ord( sprintf("% 3d",   %citPlaces{@citPlaces_r[$n]}[2] ) ), 
				:r_r_rec( sprintf("%6.2f", %citPlaces{@citPlaces_r[$n]}[3] ) )
			));
		}
		if +$mc.non-ecosystem.keys > 0 {
			%params<ErrorsExist> = Bool::True;
			for $mc.non-ecosystem.keys -> $mod {
				%params<ErrorLoop>.push: %( :ModName( $mod ), :CitedBy( %cited<simple>{$mod}.keys.join(', ') ) );
			}
		} else {
			%params<ErrorsExist> = Bool::False ;
		}
		$template.with_params( %params );
		"index.html".IO.spurt: $template.output;
	}


		
};



multi MAIN ( Any ) { 
	say "Got { @*ARGS }.\n", q:to/USAGE/;
		Useage: CitationProcess.pl [--top=nn] [--col=nn] [--sort='module'|'simple'|'recursive'] [--textfile=no]
			top (default 50) is the number listed
			col (default 2) is the number of output columns
			sort (default 'simple') is the sort order for the summary table
			textfile (default yes) leaves a text file with the summary table sorted both ways in the current directory
		USAGE
	exit;
}


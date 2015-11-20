class ModuleCitation {
#The citation number of a module is the number of citing modules for which it is a cited module
#The citation index of a module is the fraction as a percentage of the citation number of the 
#  number of cited modules. The total number of modules in the ecosystem will rise faster than cited modules
#The citation placing of a module is the position of the module when the citation indices are listed in descending order
#
#Cited modules that are not in the ecosystem are counted into the citations but are added to an non-ecosystem list
#
	has %.citing;
	has DateTime $.date .= new(%!citing<__date>:delete);
	has @.ecosystem = %!citing.keys.grep({ ! m/^ __ / }).map( { .trim } ).sort;
	has %.non-ecosystem;
	has @.parts = <simple recursive>;
	has $.limit is rw = 50;
	# a simple minded avoidance of recursion abyss. Should check for citing loops.
	# eg. mod1 'requires' mod2 'requires' .... 'requires' mod1.

	method citations-from ( Str $citer, Int :$lev = 0, Bool :$recursive = False ) {
		unless %.citing{$citer}:exists or $citer eq 'Test' { # recursively a cited module may be a citer.
			%.non-ecosystem{$citer} = 'Error';
			%.citing{$citer} = []; # fake entry
		}
		my @keys = %.citing{$citer}.keys;
		return () unless +@keys;

		#handle simple citations, which is the default
		for @keys -> $cited {
			unless %.citing{$cited}:exists or $cited eq 'Test' {
				%.non-ecosystem{$cited} = 'Error';
				%.citing{$cited} = []; # fake entry
			}
		}
		return @keys unless $recursive;
		# deal with recursive citations	
		if $lev >= $.limit {
			die "Recursion limit of { $.limit } passed. TODO: Better loop algorithm than checking for limit.";
		}
		# prevent recursive abyss. Looping shouldn't occur. 50 levels of modules unlikely.
		return | gather for @keys -> $target { 
			my @tmp = $.citations-from( $target, :lev($lev + 1) , :recursive(True) ).flat ;
			take @tmp.elems ?? ( $target , @tmp.list, ) !! $target ;
		}
	}

	submethod BUILD (:%!citing) {};
}



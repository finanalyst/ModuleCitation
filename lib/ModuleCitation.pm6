class ModuleCitation {
#The citation number of a module is the number of citing modules for which it is a cited module
#The citation index of a module is the fraction as a percentage of the citation number of the 
#  number of cited modules. The total number of modules in the ecosystem will rise faster than cited modules
#The citation placing of a module is the position of the module when the citation indices are listed in descending order
#
#Cited modules that are not in the ecosystem are counted into the citations but are added to an non-ecosystem list

       	use JSON::Fast;

	has Int $.limit is rw;
	has %.citing;
	has %.citations;
	has DateTime $.date;
	has @.ecosystem;
	has %.non-ecosystem;
	has %.cited;
	has @.parts;
	has $.tot-modules;
	has $.tot-cited;
	# a simple minded avoidance of recursion abyss. Should check for citing loops.
	# eg. mod1 'requires' mod2 'requires' .... 'requires' mod1.
	# also no need to check that multiple calls to the same module in a recursive call as this dealt with later.
	# we just want a simple flat list of module names

	method citations-from ( Str $citer, Str :$mode = 'simple', Int :$lev is copy = $.limit ) {
                return Empty if $citer ~~ m/^ Test $/; # This is a core module and not counted
		unless %.citing{$citer}:exists { # recursively a cited module may be a citer.
			%.non-ecosystem{$citer} = 'Error';
			%.citing{$citer} = (); # fake entry with zero keys in case this happens again, or for recursive calls
		}
		my @cited-candidates = grep { !m/^ Test $/ }, %.citing{$citer}.keys;

		#handle simple citations, which is the default
		return |@cited-candidates unless $mode ~~ / recursive /;
		# check for recursive abyss Looping shouldn't occur. 150 levels of modules unlikely.
		if --$lev < 1 {
			note "Recursion limit of { $!limit } passed. TODO: Better loop algorithm than checking for limit.";
			return @cited-candidates; # soft fail
		}
		# we need to check whether 
		return gather for @cited-candidates -> $target { 
			my @tmp = $.citations-from( $target, :lev($lev) , :mode<recursive> ).flat ;
			take @tmp.elems ?? ( $target , @tmp.list, ) !! $target ;
		}
	}
	method make-cited-matrix {
            for @!ecosystem -> $citer {
                next unless %!citing{$citer}.keys;
                for @!parts -> $part {
                    for self.citations-from( $citer, :mode( $part ) ).flat -> $cited { 
                    next unless $cited;
                        %!cited{ $cited }{ $part }{ $citer } = 1
                    }
                }
            }
        }
        method get-citations {
            for @!ecosystem -> $mod {
                %!citations{$mod} = hash( @!parts X=> 0 );
                for @!parts -> $part {
                    %!citations{$mod}{$part} = +%!cited{$mod}{$part}.keys;
                }
            }
        }
        method is-cited-by ( Str $mod ) { # currently only needed for simple
            join ',', %!cited{$mod}<simple>.keys;
        }
            

	submethod BUILD (:$in-string, :@!ecosystem, :%!cited) {
            @!parts = <simple recursive>;
            $!limit = 150;
            %!citing = from-json($in-string);
            @!ecosystem  = %!citing.keys.grep({ ! m/^ __ | ^ Test $ /  }).map( { .trim } ).sort;
            $!tot-modules = +@!ecosystem;
            $!date .= new(%!citing<__date>:delete);
            self.make-cited-matrix;
            self.get-citations;
            $!tot-cited = +grep { %!citations{$_}<simple> > 0 }, %!citations.keys;
        }
}

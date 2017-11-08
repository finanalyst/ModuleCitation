# Class for module citations
use JSON::Fast;
use HTTP::UserAgent;
use Algorithm::Tarjan; # to test for cycles
use DBIish;
use HTML::Template;

class ModuleCitation {
  has %.configuration = ();
  has $.dbh; # the database handle
  has @!parts = <Simple Recursive>;
  has @!core-modules = <Test NativeCall zef>; #core modules that are installed
  has Bool $.verbose is rw = False;
  has %!citing = (); # compiled from module names
  has %!alias = (); # compiled from provides fields

  my regex base-name { [<-[:]>|| '::' ] * }; # a module contains at least one word character or :: but not a single :
  my regex adverb {
    ':' $<a-name>=(\w+)
      [ \( ~ \) $<a-val>= (.+?)
      |  \< ~ \> $<a-val>= (.+?)
      ]  }; # an adverb starts with ':', contains at least one word char and has a value delimited  by brackets
  my regex module { <base-name> <adverb>* }; # full spec is a base-name and [no] adverbs

  method log( $msg ) {
    spurt "$*CWD/%.configuration<logfile>",
      "{ DateTime.new(now).truncated-to('second') }: $msg\n", :append;
    say $msg if $!verbose;
  }

  submethod TWEAK { # should be called in a directory with a config file
    my Str $config = 'config.json';
    die "No configuration file in current directory ($*CWD)"
      unless "$*CWD/$config".IO.f;
    try { %!configuration = from-json( "$*CWD/$config".IO.slurp ) };
    if $! {
            die "Cannot parse data for $*CWD/$config as JSON: $!";
    }
    #create the database if it does not exist
    my $db = "$*CWD/{%!configuration<target-directory>}/{%!configuration<database-name>}.sqlite3";
    my $db-preconnection-exists = $db.IO.f.so; # has to come before the connection to check the db does not exist
    $!dbh = DBIish.connect( "SQLite", :database( $db ), :RaiseError );
    unless $db-preconnection-exists {    # db does not exist, so it needs to be created
      my $sth = $!dbh.do(q:to/STATEMENT/);
        CREATE TABLE projectfiles (
          filename varchar(50),
          location varchar(7),
          date varchar(12),
          errors varchar(2),
          valid text
        )
        STATEMENT
      $sth = $!dbh.do(q:to/STATEMENT/);
        CREATE TABLE cited (
          date varchar(12),
          module varchar(50),
          system integer,
          simple integer,
          recursive integer
          )
        STATEMENT
    }
  }

  method get-latest-project-files () {
    my $ua = HTTP::UserAgent.new;
    for %.configuration<ecosystem-urls>.kv -> $name, %source {
      my $response = $ua.get(%source<url>);
      my $fn="%.configuration<archive-directory>/projects_{$name}_{ DateTime.new(now).truncated-to('second') }.json";
      $fn.IO.spurt: $response.decoded-content;
      CATCH {
          self.log("Could not download module metadata from $name: {$_.message}")
      }
      self.log("Downloaded data to $fn");
    }
  }

  method add-date( Str $date, List $list ) {
    my $module-err-msg = '';
    %!citing = ();
    %!alias = (); # empty aliases
    # each value of alias is a list of one or more elements
    my $sth;
    my Algorithm::Tarjan $trj .= new;
    my %trj-matrix;
    for $list.list -> $mod {
      # first criterion is that only the latest version is used
      # %!citing{base-name} contains the version number of set
      # if a module has been picked up in a source, then the next version is dropped.
      if $mod<name> ~~ / <module> / and
        ( %!citing{~$<module><base-name>}:!exists or %!citing{~$<module><base-name>} lt $mod<version>)
        {
        my $name = ~$<module><base-name>;
        # exclude core-modules
        unless $name ~~ any @!core-modules {
          %!citing{$name} = {}; # add module as top-level of ecosystem
          # consider the 'provides' field and make each element an alias to the main module
          # structure of the 'provides' field is Hash of  Sub-Module:File pairs. Only need the keys
          with $mod<provides> {
            if $_.WHAT ~~ (Hash) {
              #criterion 3, another Top-Line module provides name as dependency, but Top-Line with same name takes preference
              %!alias{$name} = ( $name, ) if %!alias{$name}:exists and $name ne all %!alias{$name};
              for  $_.keys -> $sub-mod {
                next if $sub-mod eq any @!core-modules; # do not allow any core-module name into alias value
                with %!alias{$sub-mod} -> @pointed-to {
                  # criterion 4, add to list unles another Top-line module already provides itself as dependency
                  %!alias{$sub-mod}.append( $name ) unless $sub-mod eq any @pointed-to;
                } else {
                  %!alias{$sub-mod} = $name , ; #creates a list
                }
              }
            }
          }
          # consider the 'depends' field
          with $mod<depends> {
            my ($err, %mods) = self.analyse-dep($_);
            if $err eq '' {
              for %mods.kv -> $ref-name, %adverbs {
                # second criterion is that the module is not from another language source
                without %adverbs<from> {
                  %!citing{$name}{$ref-name} = $mod<version>   ;
                  %trj-matrix{$name}.push: $ref-name;
                }
              }
            } else { # accumulate warning messages
              $module-err-msg ~= "At \<$date> for \<$name> 'depends': $err";
            }
          }
        }
      }
    }
    # check for cycles in the citation matrix
    $trj.init( %trj-matrix );
    if $trj.find-cycles() > 0 {
      self.log("No change to cited table because Tarjan strongly connected components found")
    } else {
      #create citations matrix
      my @ecosystem  = %!citing.keys.map( { .trim } ).sort;
      my %cited = ();
      for @ecosystem -> $citer {
          next unless %!citing{$citer}.keys; # skip if citer hasnt dependencies
          for @!parts -> $part {
            for self.citations-from( $citer, $part ).flat -> $cited {
              next unless $cited; # skip blank elements
              %cited{ $cited }{ $part }{ $citer } = 1 # same as creating a set
            }
         }
      }
      $sth = $!dbh.prepare( q:to/STATEMENT/ );
        INSERT INTO cited (date, module, simple, recursive, system) VALUES ( ?, ?, ?, ?, ?)
        STATEMENT
      my $cited-total = 0;
      my @x-ecosystem = %!citing.keys.grep( { $_ !~~ any(@ecosystem) } );
      for @ecosystem -> $mod {
        my $num = +%cited{$mod}<Simple>.keys;
        $sth.execute( $date, $mod, $num, +%cited{$mod}<Recursive>.keys, 0);
        $cited-total++ if $num;
      }
      for @x-ecosystem -> $mod {
        my $num = +%cited{$mod}<Simple>.keys;
        $sth.execute( $date, $mod, $num, +%cited{$mod}<Recursive>.keys, 1);
        $cited-total++ if $num;
      }
      $sth.execute( $date, 'TotalEcosystem', +@ecosystem, 0, 2);
      $sth.execute( $date, 'TotalCited', $cited-total, 0 , 2);
      $sth.execute( $date, 'TotalXEcosystem', +@x-ecosystem, 0, 2);
      self.log("Data for $date added to cited table")
    }
    self.log("Module errors: $module-err-msg") if $module-err-msg;
  }

  method analyse-dep( $dep-str --> List ) {
    my %mods = ();
    my $err = '';
    given $dep-str.WHAT.^name {
      when 'Array' {
        for $dep-str.list -> $spec {
          given $spec.WHAT.^name {
            when 'Str' { # a simple module name
              if $spec ~~ /<module>/ {
                my %v = ();
                for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                %mods{ $<module><base-name> } = %v;
              } else { $err ~= "invalid module pattern: \<$spec>"}
            }
            when 'Array' { # a list of module names, which are alternatives
              for $spec.list -> $elem {
                if $elem ~~ /<module>/ {
                  my %v = ();
                  for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                  %mods{ $<module><base-name> } = %v;
                } else { $err ~= "invalid module pattern: \<$elem>"}
              }
            }
            when 'Hash' { # an element contains hints as well as the Module name
              with $spec<name> { # ignore any hash element not containing an module name
                if $spec<name> ~~ /<module>/ { # only need the information in the name field
                    my %v = ();
                    for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                    %mods{ $<module><base-name> } = %v;
                  } else { $err ~= 'invalid module pattern: <' ~ $spec<name> ~ ">" }
                }
              }
            default {
              $err ~= 'invalid module pattern: <' ~ $spec ~ ">";
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
                  } else {  $err ~= "Wrong module pattern: \<$spec>"}
                }
                when 'Array' { # a list of module names, which are alternatives
                  for $spec.list -> $elem {
                    if $elem ~~ /<module>/ {
                      my %v = ();
                      for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                      %mods{ $<module><base-name> } = %v;
                    } else { $err ~= "Wrong module pattern: \<$elem>" }
                  }
                }
                when 'Hash' { # an element contains hints as well as the Module name
                  with $spec<name> { # ignore any hash element not containing an module name
                    if $spec<name> ~~ /<module>/ { # only need the information in the name field
                        my %v = ();
                        for $<module><adverb>.list  { %v{ ~$_<a-name> } = ~$_<a-val> };
                        %mods{ $<module><base-name> } = %v;
                      } else { $err ~= 'Wrong module pattern: <' ~ $spec<name> ~ ">"}
                    }
                  }
                default {
                  $err ~= 'Unknown module pattern: <' ~ $spec ~ ">";
                }
              }
            }
          }
        }
      }
    }
    return ($err, %mods);
  }

  method citations-from( Str $citer, Str $mode ) {
    return Empty if $citer ~~ any @!core-modules;
    unless %!citing{$citer}:exists or %!alias{$citer}:exists { # recursively a cited module may be a citer.
      # modules themselves can be cited, and so can modules they 'provide'
      # sub-modules are treated for citation purposes as aliases of the module
      # without either the module or sub-module, the cited name is not in the Ecosystem
      %!citing{$citer} = (); # fake entry with zero keys in case this happens again
    }
    my @cited-candidates;
    for %!citing{$citer}.keys {
      @cited-candidates.append($_.list) with %!alias{$_} ;
      @cited-candidates.append($_) if %!alias{$_}:!exists and $_ ne any @!core-modules;
    };
    return |@cited-candidates unless $mode ~~ / Recursive /;
    return gather for @cited-candidates.list -> $target {
      my @tmp = $.citations-from( $target, $mode ).flat ;
      take @tmp.elems ?? ( $target , @tmp.list, ) !! $target ;
    }
  }

  method update{
    =comment
      downloading files from multiple sources means that
        a) files for the same date and same location may exist - to be marked as duplicate
        b) data from all sources needs to be combined to study the whole ecosystem
        c) a file from one source can be downloaded, but not from another, and at another time, vice versa.
           This means that complete information does exist in database, but is not used.
        So:
        - cited data is only added if there are files for each source
        - this requires we know when a new source became available

    # discover which files are not in database
    my $sth = $!dbh.prepare( q:to/STATEMENT/ );
      SELECT filename FROM projectfiles
      STATEMENT
    $sth.execute;
    my @existing-files = $sth.allrows.flat;
    my @new-files;
    for "$*CWD/{$.configuration<archive-directory>}".IO.dir.map( { .subst(/^ .* '/' /,'') } )
      -> $filename {
      next if $filename ~~ any( @existing-files );
      if $filename ~~ / 'projects_' $<loc>=(\w+) '_' $<date>=(.*?) 'T' / {
        @new-files.push: %( :name( ~$filename), :loc( ~$<loc>), :date( ~$<date> ), :error(False) );
      } else {
        @new-files.push: %( :name(~$filename), :loc<NA>, :date<1999-01-01>, :dup(False), :error(True) );
        self.log("Filename \<$filename> doesn't match pattern");
      }
    }
    # obtain duplicate information for each file
    my $results;
    my %dates;
    for @new-files -> %file {
      unless %file<error> {
        $sth = $.dbh.prepare( qq:to/STATEMENT/);
          SELECT count(date) > 0 AS 'dups' FROM projectfiles WHERE date='%file<date>' and location='%file<loc>'
          STATEMENT
        $sth.execute;
        $results = $sth.row(:hash);
        %file<duplicate> = $results<dups>.so;
        %dates{%file<date>} = {} without %dates{%file<date>};
        %dates{%file<date>}{%file<loc>} = %file<name>;
      }
      # add file to database
      self.log("Adding data for %file<name> to projectsfile table");
      $sth = $.dbh.do( qq:to/STATEMENT/  );
        INSERT INTO projectfiles ( filename, location, date, valid, errors )
        VALUES ( "%file<name>", "%file<loc>","%file<date>", "{%file<duplicate> ?? 'Dup' !! 'OK'}", "{ %file<error> ?? 'Y' !! 'N' }" )
        STATEMENT
    }
    # collect information where ecosystem is complete
    # only update cited files if all sources are downloaded.
    for %dates.kv -> $date, %locations {
      my Bool $err = False;
      if  %!configuration<ecosystem-urls>.map({
        .value<date> gt $date or ( .value<date> le $date and %locations{.key}:exists )
      }).all {
        my @json-list = ();
        for %locations.values -> $fn {
          try {
            @json-list.append(from-json("$*CWD/{$.configuration<archive-directory>}/$fn".IO.slurp).list)
          }
          if $! {
            $err = True;
            self.log( "JSON error reading  $fn: " ~ $! );
            $sth = $.dbh.do( qq:to/STATEMENT/  );
              UPDATE projectfiles
              SET errors="Y"
              WHERE filename="$fn"
              STATEMENT
            last # out of the loop for this date
          }
        } # locations loop
        self.add-date($date, @json-list) unless $err;
      } else {
        self.log(
          "Incomplete ecosystem:\n\t" ~
            %.configuration<ecosystem-urls>.keys.map({ "$_ : " ~ ( %locations{$_} // 'N/a' ) }).join(",\n\t")
          )
      }
    }
  }


  method generate-html() {
    # generate the table of values
    my $sth = $!dbh.prepare( q:to/STATEMENT/ );
      SELECT distinct(date) from cited order by date asc
      STATEMENT
    $sth.execute;
    my $date = $sth.allrows.flat.tail;
    $sth = $!dbh.prepare( qq:to/STATEMENT/ );
      SELECT t1.simple, t2.simple, t3.simple
      from
        (select simple from cited where date="$date" and module="TotalEcosystem") as t1,
          (select simple from cited where date="$date" and module="TotalCited") as t2,
            (select simple from cited where date="$date" and module="TotalXEcosystem") as t3
      STATEMENT
    $sth.execute;
    my @totals = $sth.allrows.flat;
    my $template = HTML::Template.from_file( %!configuration<html-template> );
    my %params = N_MOD => @totals[0],
        N_CIT => @totals[1],
        PC_CIT => sprintf("%6.2f%%",100 * @totals[1] / @totals[0]),
        DATE => $date,
        N_ROWS => %.configuration<top-limit>,
        CORES => @!core-modules.join(', ')
        ;
    my %orders;
    for <Simple Recursive> -> $part {
      $sth = $!dbh.prepare( qq:to/STATEMENT/ );
        select distinct(cited.module) as Name , t1.cit as Simple, t2.cit as Recursive
          from
          	cited,
          	(select module, round( 100.0 * cited.simple / t3.simple , 2) as cit
          		from cited,
          			(select simple from cited where date="$date" and module="TotalCited") as t3
          		where date="$date" and system=0
          	) as t1,
          	(select module, round( 100.0 * cited.recursive / t3.simple , 2) as cit
          		from cited,
          			(select simple from cited where date="$date" and module="TotalCited") as t3
          		where date="$date" and system=0
          	) as t2
          where t1.module=cited.module and t2.module=cited.module
          order by $part desc
          limit {%!configuration<top-limit>}
        STATEMENT
      $sth.execute;
      %orders{$part} = $sth.allrows(:array-of-hash);
    }

    for 0 ..^ %!configuration<top-limit> -> $n {
        %params<modules>.push( %(
          :order( sprintf("% 3d", $n+1 ) ),
          :s_name(  sprintf("%s",%orders<Simple>[$n]<Name> ) ),
          :s_s_sim( sprintf("%6.2f",%orders<Simple>[$n]<Simple> ) ),
          :s_r_rec( sprintf("%6.2f",%orders<Simple>[$n]<Recursive> ) ),
          :r_name(  sprintf("%s", %orders<Simple>[$n]<Name> ) ),
          :r_s_sim( sprintf("%6.2f",%orders<Recursive>[$n]<Simple> ) ),
          :r_r_rec( sprintf("%6.2f",%orders<Recursive>[$n]<Recursive> ) )
        ));
    }
    $sth = $!dbh.prepare( qq:to/STATEMENT/ );
      select module from cited where system=1 and date="$date"
      STATEMENT
    $sth.execute;
    if @totals[2] > 0 {
      %params<XEcosystem> = Bool::True;
      for $sth.allrows -> $mod {
              %params<XEcoLoop>.push: %( :ModName( sprintf("%s",$mod ) ), );
      }
    } else {
      %params<XEcosystem> = Bool::False ;
    }
    $template.with_params( %params );
    "{%!configuration<html-directory>}/index.html".IO.spurt: $template.output;
    self.log("Html index file created.")
  }

  method update-csv-files {
    my %filenames = <simple recursive all> Z=> ('GraphFile_simple.csv','GraphFile_recursive.csv','GraphFile_AllModules.csv');
    my @headings = <Date ModulesCited AllModules>;
    my $sth = $.dbh.prepare( q:to/STATEMENT/ );
      select distinct(cited.date) as Date,t1.simple as AllModules, t2.simple as ModulesCited
      from cited,
      (select date, module, simple from cited  where module="TotalEcosystem") as t1,
      (select date, module, simple from cited where module="TotalCited") as t2
      where cited.date=t1.date and cited.date=t2.date
      order by date asc
    STATEMENT
    $sth.execute;
    "{%!configuration<html-directory>}/{%filenames<all>}".IO.spurt:
      ( @headings.join(','),
        |$sth.allrows(:array-of-hash).map( { $_{@headings}.join(',') } )
      ).join("\n") ;
    self.log: "{%!configuration<html-directory>}/{%filenames<all>} created.";
    # get dates
    $sth = $.dbh.prepare( q:to/STATEMENT/ );
        select distinct(date) from cited
      STATEMENT
    $sth.execute;
    my @dates = $sth.allrows.flat;
    my %data;
    my %mods;

    for <simple recursive> -> $part {
      my $fh = open "{%!configuration<html-directory>}/{ %filenames{$part} }", :w;
      %data{$part} = {};
      %mods{$part} = {};
      for @dates -> $dd {
        %data{$part}{$dd} = {};
        $sth = $.dbh.prepare( qq:to/STATEMENT/ );
          select cited.module as name,
            round( 100.0*cited.$part/t1.simple, 2) as cit
          from cited,
            (select simple from cited where module="TotalCited" and date="$dd") as t1
          where cited.system=0 and cited.date="$dd"
          order by cit desc
          limit {%!configuration<top-limit>}
          STATEMENT
        $sth.execute;
        for $sth.allrows -> @row {
          %data{$part}{$dd}{@row[0]} = @row[1];
          %mods{$part}{@row[0]} = 1 unless %mods{$part}{@row[0]}:exists;
        }
      }
      my @modules = %mods{$part}.keys.sort;
      $fh.say: "Date," ~ @modules.join(',');
      for @dates -> $d {
            $fh.say( $d, ',', @modules.map( { %data{$part}{$d}{$_}:exists ?? %data{$part}{$d}{$_} !! 'NaN' } ).join(',') );
        }
      $fh.close;
      self.log: "{%!configuration<html-directory>}/{%filenames{$part}} created.";
    }
  }

  method compile-popular-task {
    my $metajson = "{%!configuration<task-popular-directory>}/META6.json";
    # copy head into new README
    my $readme = "{%!configuration<task-popular-directory>}/README.md";
    "readme.start.md".IO.copy: $readme;

    my %json = try from-json( $metajson.IO.slurp );
    if $! {
      self.log("Task Compilation ended. $!");
      return
    }
    %json<depends> = (); #remove existing depends value
    # Get the last date
    my $sth = $!dbh.prepare( q:to/STATEMENT/ );
          SELECT distinct(date) from cited order by date asc
          STATEMENT
    $sth.execute;
    my $date = $sth.allrows.flat.tail;

    # Get the valid project file for this date to extract description data
    $sth = $!dbh.prepare( qq:to/STATEMENT/ );
          SELECT filename from projectfiles where date="$date" and valid="OK"
          STATEMENT
    $sth.execute;
    my $projectfile = $sth.allrows.flat.tail;
    my $modules = try from-json( "{%!configuration<archive-directory>}/$projectfile".IO.slurp) ;
    if $! {
      self.log("Task Compilation ended. $!");
      return
    }

    # Get the top N modules in recusive order
    $sth = $!dbh.prepare( qq:to/STATEMENT/);
      select cited.module as "Name",
        round( 100.0*cited.recursive/t1.simple, 2) as "Index"
      from cited,
        (select simple from cited where module="TotalCited" and date="$date") as t1
      where cited.system=0 and cited.date="$date"
      order by "Index" desc
      limit {%!configuration<task-popular-number>}
      STATEMENT
    $sth.execute;
    my @data = $sth.allrows(:array-of-hash);

    # update the README and META6 files
    $readme.IO.spurt( @data.map( { "| {$_<Name>} | {$_<Index>} | { self.get-description( $_<Name>, $modules ) } |" } ).join("\n"),:append);
    #add date
    $readme.IO.spurt( qq:to/DATE/ ,:append );


      ## Date of Compilation

      This list was compiled on { Date.today }.

      DATE
    $readme.IO.spurt( "readme.end.md".IO.slurp,:append);
    %json<depends> = @data>><Name>;
    $metajson.IO.spurt: to-json(%json);
    self.log("Task::Popular list compiled");
  }

  method get-description( $name, $mods ) {
    my $desc = 'OOps description not found, please file issue at github repository of p6-task-popular';
    for $mods.list -> %mod {
      next unless %mod<name> eq $name;
      $desc = %mod<description>;
      last;
    }
    return $desc;
  }
}

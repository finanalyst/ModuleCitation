# Class for module citations
use JSON::Fast;
use HTTP::UserAgent;
use Algorithm::Tarjan; # to test for cycles
use DBIish;
use HTML::Template;

class ModuleCitation {
  has %.configuration = ();
  has $.max-name is rw; # the length of the longest module name
  has Str $.raw is rw = ''; # the raw data from the project file
  has $.dbh; # the database handle
  has @!parts = <Simple Recursive>;
  has @!core-modules = <Test NativeCall zef>; #core modules that are installed
  has Bool $!verbose;

  my regex base-name { \w [<-[:]>|| '::' ] * }; # a module contains at least one word character or :: but not a single :
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

  submethod BUILD( :$verbose=False ) { # should be called in a directory with a config file
    my Str $config = 'config.json';
    die "No configuration file in current directory ($*CWD)"
      unless "$*CWD/$config".IO.f;
    %!configuration = from-json( "$*CWD/$config".IO.slurp );
    if $! {
            die "Cannot parse data for $*CWD/$config as JSON: $!";
    }
    $!verbose = $verbose;
    #create the database if it does not exist
    my $db = "$*CWD/{%!configuration<target-directory>}/{%!configuration<database-name>}.sqlite3";
    my $db-preconnection-exists = $db.IO.f.so; # has to come before the connection to check the db does not exist
    $!dbh = DBIish.connect( "SQLite", :database( $db ), :RaiseError );
    unless $db-preconnection-exists {    # db does not exist, so it needs to be created
      my $sth = $!dbh.do(q:to/STATEMENT/);
        CREATE TABLE projectfiles (
          filename varchar(50),
          location varchar(4),
          date varchar(12),
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

  method get-latest-project-file () {
    my $ua = HTTP::UserAgent.new;
    my $k = 0;
    for %.configuration<ecosystem-urls>.list -> $url {
      my $response = $ua.get($url);
      my $fn="%.configuration<archive-directory>/projects_{$k++}_{ DateTime.new(now).truncated-to('second') }";
      $fn.IO.spurt: $response.decoded-content;
      CATCH {
          self.log("Could not download module metadata: {$_.message}")
      }
      self.log("Downloaded data to $fn");
    }
  }

  method add-filename( $filename ) {
    self.log("Processing $filename");
    my $error-msg = '';
    my $date = '2000-01-01'; #in case date cannot be determined
    my $loc = 0;
    my %citing;
    my $sth;
    my $list;
    my Algorithm::Tarjan $trj .= new;
    my %trj-matrix;
    # get the file from archive and parse it for location and time information
    if $filename ~~ / 'projects_' $<loc>=(\d+) '_' $<date>=(.*?) 'T' / {
      $date = $<date>.Str;
      $loc = $<loc>.Str;
      $sth = $.dbh.prepare( qq:to/STATEMENT/);
        SELECT count(date) AS 'Number' FROM projectfiles WHERE date='$date' and location='$loc'
        STATEMENT
      $sth.execute;
      my %similar = $sth.row(:hash);
      # any files with the same location and date as one already in the directory are set as Duplicate
      # this is because multiple project files may be downloaded and the default is to keep information
      $error-msg = 'Duplicate' if %similar<Number> > 0;
    } else {
      $error-msg = "Filename doesnt match pattern";
      self.log($error-msg)
    }
    # the json data is now tested.
    unless $error-msg {
      %trj-matrix = Empty;
      $list = try from-json( "$*CWD/$.configuration<archive-directory>/$filename".IO.slurp );
      if $! {
        $error-msg = "Not valid JSON";
        self.log("$!")
      }
    }
    unless $error-msg {
      # the json is valid
      self.log("Adding $filename to cited table");
      for $list.list -> $mod {
        # first criterion is that only the latest version is used
        unless $mod<name> ~~ / ^ [ <-[:]> || '::' ] * / and %citing{$/}:exists and %citing{$/} gt $mod<version>  {
          my $name = ~$/;
          # exclude core-modules
          unless $name ~~ any @!core-modules {
            %citing{$name} = {};
            # only consider the 'depends' field
            with $mod<depends> {
              my ($err, %mods) = self.analyse-dep($_);
              if $err eq '' {
                for %mods.kv -> $ref-name, %adverbs {
                  # second criterion is that the module is not from another source
                  without %adverbs<from> {
                    %citing{$name}{$ref-name} = $mod<version>   ;
                    %trj-matrix{$name}.push: $ref-name;
                  }
                }
              } else {
                $error-msg = "Depends field error: $err";
              }
            }
          }
        }
      }
      # check for cycles in the citation matrix
      $trj.init( %trj-matrix );
      if $trj.find-cycles() > 0 {
         $error-msg = "Cycles in data likely";
         self.log("Tarjan strongly connected components found")
      }
    }
    $sth = $.dbh.do( qq:to/STATEMENT/  );
      INSERT INTO projectfiles ( filename, location, date, valid )
      VALUES ( "$filename", "$loc","$date", "{ $error-msg ?? $error-msg !! 'OK' }" );
      STATEMENT
    #now add filename to the citing table if no error
    if $error-msg {
      self.log("No change to citing/index tables because of an error: $error-msg") }
    else {
      #create citations matrix
      my @ecosystem  = %citing.keys.map( { .trim } ).sort;
      my %cited = ();
      for @ecosystem -> $citer {
          next unless %citing{$citer}.keys; # skip if citer hasnt dependencies
          for @!parts -> $part {
            for self.citations-from( %citing, $citer, $part ).flat -> $cited {
              next unless $cited; # skip blank elements
              %cited{ $cited }{ $part }{ $citer } = 1 # same as creating a set
            }
         }
      }
      $sth = $!dbh.prepare( q:to/STATEMENT/ );
        INSERT INTO cited (date, module, simple, recursive, system) VALUES ( ?, ?, ?, ?, ?)
        STATEMENT
      my $cited-total = 0;
      my @x-ecosystem = %citing.keys.grep( { $_ !~~ any(@ecosystem) } );
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
      self.log("Added seems successful")
    }
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

  method citations-from( %citing, Str $citer, Str $mode ) {
    return Empty if $citer ~~ m/^ Test $/; # This is a core module and not counted
    unless %citing{$citer}:exists { # recursively a cited module may be a citer.
      #if it does not exist in the ecosystem, then it is in a depends list, but not at a top-level
      %citing{$citer} = (); # fake entry with zero keys in case this happens again
    }
    my @cited-candidates = grep { !m/^ Test $/ }, %citing{$citer}.keys;
    #handle simple citations, which is the default
    return |@cited-candidates unless $mode ~~ / Recursive /;
    return gather for @cited-candidates -> $target {
      my @tmp = $.citations-from( %citing, $target, $mode ).flat ;
      take @tmp.elems ?? ( $target , @tmp.list, ) !! $target ;
    }
  }

  method update() {
    #find files in the archive that have not been included in the database
    #this will fill the database on the first time through, but only the latest file on a normal return
    my $sth = $!dbh.prepare( q:to/STATEMENT/ );
      SELECT filename FROM projectfiles
      STATEMENT
    $sth.execute;
    my @existing-files = $sth.allrows.flat;
    for "$*CWD/{$.configuration<archive-directory>}".IO.dir.map( { .subst(/^ .* '/' /,'') } )
      -> $filename {
      next if $filename ~~ any( @existing-files );
      self.add-filename($filename);
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

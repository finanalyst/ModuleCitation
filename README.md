# ModuleCitation
Scripts and modules for generating a citation index for modules in the Perl6 ecosystem

##General
The Perl6 Ecosystem has a large number of modules and it is interesting to see which are used the most, 
and it will be interesting to see how this profile changes over time.

Since each module in the Ecosystem contains a `META.info` or `META6.json` file for the module's meta-information,
this can be searched for the `"depends"` key to see which external module it is dependent on. This is a 
*citation* of another module (a module may only *cite* another specific module once), which then becomes 
a *cited* module. By gathering information over the whole
ecosystem, it is possible to generate a *citation index* for a single "top line" Ecosystem module as the fraction
of the number of times that module is cited compared to the total number of citations (or cited modules, which
is the same number because of the one citation constraint). 

Modules that do not have a `META.info` or `META6.json` file are considered **non-compliant** and are ignored.

TODO: the --date options are not implemented. 

##Scripts and Methods
* **CitationGather.pl** [--final] [--RepPath=/path/to/directory/for/EcosystemSparseRepository] [--ArcPath=/path/to/directory/for/archive]

  The script creates a repository at the path in the option `--RepPath`. Default is `$*CWP ~ '/CitationData'` (sub-directory in the working directory). 
  
  It uses `git` to create a sparse repository and only the files `META.info` and `META6.json` are downloaded.
  
  The script outputs a list of repositories git has been unable to access.
  
  It is wise to run the script several times if this list is too long.
  
  The option `--final` stores the
  results in a json file with a date as the name in a local directory called /path/to/directory/for/archive if `--ArcPath` is given.
  
  Default is 'CitationArchive' sub-directory in current working directory.
  
  Using module instead of standalone script:
  ``` perl
  use ModuleCitation;
  my $retval = CitationGather(Bool :final, Str :RepPath(/path/to/directory/for/EcosystemSparseRepository) );
  # $retval = List ModuleName(s)
  # $retval = 0 if no non-compliant modules, but this should not be assumed as normal.
  ```
  
* **CitationRetrieve.pl** [--ArcPath=/path/to/directory/for/archive]

  The script uses .git to create a local directory named in the option `--ArcPath` and pulls data from this repository.
  
  Without the option, the directory is called 'CitationArchive' in current working directory.
  
  Further invocations of the script (without `--DirPath`) refresh the archive from this repository.

  Invalid input triggers the useage string.

  Using module instead of standalone script:
  ``` perl
  use ModuleCitation;
  my $retval = CitationRetrieve(Str :ArcPath(/path/to/directory/for/archive));
  # $retval = 0 if successful
  ```

* **CitationProcess.pl** [--top=nn] [--col=nn] [--remote ] [--ArcPath=/path/to/directory/for/archive]

 The script shows the top (option `--top=nn` default 50) citations on the latest date in repository, output in columns (option `--col=nn` default 3).
 
 The option `--remote` calls the code used by CitationRetrieve.
 
 The default is 'local', which then uses the local `--ArcPath` value or 'CitationArchive'. 
 
 This is so that a local 'CitationData'
 repository can be created and used to create a local 'CitationArchive', which can be used independently of
 the 'CitationArchive' in this repository.
 
  No options assumes the defaults.

  Other parameter(s) or invalid input trigger the useage string.

  Using the Module
  ``` perl
  use ModuleCitation;
  my $retval = CitationProcess( Int :top , Int :col, Bool :remote, Str :ArcDir );
  # $retval = 0 if successful
  # $retval = 
  ```

* **CitationForModule.pl** [--date=yyyymmdd] Module1 [ Module2 ... ]

  Shows the Citation Index of the named module at the latest date if `--date` is not set.
  
  If more than one Module is given, the output is a list of pairs `:Name(Index)` at the latest date and the 
`--date` option is ignored.

  If one Module is named and the `--date` option is set, then a list of pairs `:Date(Index)` is returned.
  
  Note that the standalone script and Module method have different behaviours when both `--date` and multiple 
  Modules are named. In the standalone script, if more than one Module is given, only the latest date is shown.

  No parameters or invalid input triggers the useage string.
  
  Using the Module:
  ``` perl
  use v6;
  use ModuleCitation;
  my $retval = CitationForModule(Str Module, :date(Str), *Str @Modules);
  # $retval = Num Index if one Module named
  # $retval = Array of Pair(Str Name => Num Index) if more than one module
  # $retval = Hash (Str date => Num Index) if date given, each key is a date
  # $retval = Hash of Pair (Str date => (Str Name => Num Index) ) if date and modules given
  ```

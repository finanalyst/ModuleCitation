# ModuleCitation
Scripts and modules for generating a citation index for modules in the Perl6 ecosystem

##General
The Perl6 Ecosystem has a large number of modules and it is interesting to see which are used the most, 
and it will be interesting to see how this profile changes over time.

The Ecosystem has a file with meta information about each _top line_ module (other modules in the ecosystem
are contained in sub-directories of the _top line_ modules.

Each module lists the modules it `"depends"` on. We call this a 
*citation* of another module, which is then called *cited* module. By gathering information over the whole
ecosystem, it is possible to generate a *citation index* for each _top line_ Ecosystem module. The citation index is
defined as the fraction as a percentage 
of the number of times that module is cited compared to the total number of citations. Since each module is only 
allowed to *cite* another module once, which means that the number of citations is the number of cited module.

A *simple* search collects only citations in the `"depends"` list. A *recursive*^1 search collects citations in modules
that are *cited* by the modules in the `"depends"` list, and the citations in those modules. 

*TODO:* the --date options are not implemented. 

^1 To prevent a 
citation loop, eg. Module1 -> module2 -> ... -> Module1, the recursion level is clamped at 50. 

TODO: use a cycle detection algorithm to break a recursive loop. But currently, 50 levels of recursion seems sufficient to gather 
all citations.

##Repository

Two ways of creating an archive to process are envisaged. Once the archive is created it can be analysed using
**CitationProcessed.pl** and **CitationForModule.pl**

1)  Working with the 'Archive' subdirectory in this repository, which should be updated regularly. This contains
the Citation data run remotely.

   The remote archive is created and refreshed with **CitationRetrieve.pl**

2)  Working with a local sparse repository, which creates a local 'Archive' subdirectory.

   The local archive is created and refreshed with **CitationCreate.pl** and **CitationGather.pl**

Note that a local archive can be created using **CitationRetrieve.pl** which can be supplemented using the local 
repository scripts. They should work together harmoniously because it is unlikely that remotely generated files will have the same time names as locally generated ones.

##Scripts and Methods

* **CitationCreate.pl** [--CitPath=/path/to/directory/for/Citations]

  The script creates a repository & archive at the path in the option `--CitPath`. Default is `~.local/ModuleCitations`

  The list of Ecosystem Projects is downloaded from the file where panda looks for it, and stored at `--CitPath`
  
  It uses `git` to create a sparse repository `Repository` and only the files `META.info` and `META6.json` 
are downloaded for each Ecosystem Module.

  The git function messages are output onto STDOUT so that the process can be monitored.
  
  The script also outputs a list of repositories git has been unable to access.
  
  It is wise to run the script several times if this list is too long.

  Using Module instead of standalone script:
  ``` perl
  use ModuleCitation;
  my $retval = CitationCreate(Str :CitPath('/path/to/directory/for/Citations') );
  # $retval = ['Module Name' 'Module Name' ... ]
  ```
  
* **CitationGather.pl** [--CitPath=/path/to/directory/for/Citations] [--force]
  The script expects for a Repository at `--CitPath` (default ~.local/ModuleCitations).

  It refreshes the git directories if the repository is over a day old (default)

  If `--force` is set, then git is forced to run on all Project directories.

  The script gathers the citation results and outputs them into a json file with a date (from `DateTime(now)` )
as the name in the subdirectory 'Archive' at `--CitPath` (default ~.ModuleCitations).

  Invalid input and the absence of a repository trigger useage.
  
  Using module instead of standalone script:
  ``` perl
  use ModuleCitation;
  my $retval = CitationGather(Bool :final, Str :CitPath(/path/to/directory/for/Citations) );
  # $retval = List ModuleName(s)
  # $retval = 0 if no non-compliant modules, but this should not be assumed as normal.
  ```

* **CitationRetrieve.pl** [--CitPath=/path/to/directory/for/Citations]

  The script uses .git to create an 'Archive' subdirectory at `--CitPath` and pulls the data from 
the 'Archive' subdirectory in this repository.

  If an 'Archive' subdirectory exists at `--CitPath` then the repository is refreshed.
  
  Invalid input triggers the useage string.

  Using module instead of standalone script:
  ``` perl
  use ModuleCitation;
  my $retval = CitationRetrieve(Str :CitPath(/path/to/directory/for/Citations));
  # $retval = 0 if successful
  ```

* **CitationProcess.pl** [--top=nn] [--col=nn] [--CitPath=/path/to/directory/for/citations]

 The script shows the top (option `--top=nn` default 50) citations on the latest date in repository, output in columns (option `--col=nn` default 3).
 
  No options assumes the defaults.

  Other parameter(s) or invalid input trigger the useage string.

  Using the Module
  ``` perl
  use ModuleCitation;
  my $retval = CitationProcess( Int :top(24) , Int :col(4), Str :CitPath('~./local/more/Citations/ );
  # $retval = 0 if successful
  # $retval = 
  ```

* **CitationForModule.pl** [--date=yyyymmdd] Module1 [ Module2 ... ] [--CitPath=/path/to/directory/for/citations]

  Shows the Citation Index of the named module at the latest date if `--date` is absent
  
  If more than one Module is given, the output is a list of pairs `:Name(Index)` at the latest date and the 
`--date` option is ignored.

  If one Module is named and the `--date` option is set, then a list of pairs `:Date(Index)` is returned, 
one for each of the dates in the Archive after the date in the --date option (after using DateTime semantics)
  
  Note that the standalone script and Module method have different behaviours when both `--date` and multiple 
  Modules are named. In the standalone script, if more than one Module is given, only the latest date is shown.

  No parameters or invalid input triggers the useage string.
  
  Using the Module:
  ``` perl
  use v6;
  use ModuleCitation;
  my $retval = CitationForModule(Str Module, :date(Str), Str :CitPath( Str ), *Str @Modules);
  # $retval = Num Index if one Module named
  # $retval = Array of Pair(Str Name => Num Index) if more than one module
  # $retval = Hash (Str date => Num Index) if date given, each key is a date
  # $retval = Hash of Pair (Str date => (Str Name => Num Index) ) if date and modules given
  ```

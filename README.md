# ModuleCitation
Scripts and module for generating a citation index for modules in the Perl6 ecosystem

[General](#general)  
[Process](#process)  
[Scripts](#scripts)  
[Configuration](#configuration)  

## General

The Perl6 Ecosystem has a large number of modules and it is interesting to see which are used the most frequently,
and it will be interesting to see how this profile changes over time. The Ecosystem used to be contained in a
single projects file, but with cpan6, two files now exist, and possibly more in future. The `Ecosystem` now is
considered to be the union of all META6.json references in all the known lists of modules. It is possible for a module with the same name and same version number to be in both lists, but with different metadata.

A META6.json file refers to a  _top line_ module, which may in turn provide more
modules through the `provides` field. These are called _sub-modules_.

Each  _top line_ module lists the modules it `"depends"` on. We call this a
*citation* of another module, which is then called a *cited* module. By gathering information over the whole
ecosystem, it is possible to generate a *citation index* for each _top line_ module. The citation index is
defined as the percentage fraction
of the number of times that module is cited compared to the total number of citations. Each module is only
allowed to *cite* another module once.

The meta6.json specification allows for dependencies to be defined on sources not in perl6, eg., C and perl5. A citation is valid only if it is to a perl6 Module.

However, _top line_ meta data may come from multiple sources,  _top line_ modules may also "depend" on sub-modules that are _provided_ by other _top line_ modules, and sub-modules with the same name may be provided by multiple  _top line_ modules. For the purposes of this citation index, the following criteria are used:  
1. Only the latest version of a _top line_ module is taken into account
1. If a module with the same version level is encountered twice (appearing in two meta data lists), the duplicate data is ignored; the ecosystem list is read first.  
1. Modules "from" another language are ignored.
1. If a  _top line_ module `provides` a sub-module that has the same name as another  _top line_ module, then the sub-module is ignored (preference is given to the  _top line_ module). This is not specified in the perl6 documentation, but it does seem to be implied.
1. If two  _top line_ modules `provide` a sub-module with the same name, the first  _top line_ module encountered is given preference. This ambiguity does not seem to have a unique resolution in the specification.
1. It is possible for a  _top line_ module to `depend` on alternative modules. Each alternative is given equal weighting for citation purposes.

A *simple* search collects only citations in the `"depends"` list. A *recursive* search collects citations in modules
that are *cited* by the modules in the `"depends"` list, and the citations in those modules.

The Tarjan algorithm is used to detect whether
possible loops may occur. An ecosystem data set with a Tarjan 'strongly connected' cluster is not analysed.

## Process
The Perl6 Ecosystem is defined by files at http://ecosystem-api.p6c.org/projects.json  
https://raw.githubusercontent.com/ugexe/Perl6-ecosystems/master/cpan.json

The files are downloaded, and stored in an archive.
The json is processed to the names and the children, and the results are stored in an SQLite3 database.
The ecosystem struture is created and analysed to create the citation indices.
A static html file is created, together with the data files needed by the graphical engines used in the html.
The html components are stored to a git repository that is then pushed to github (in a bash script), where github makes it public.


## Scripts

A single ModuleCitation object is created, and on creation looks for a mandatory configuration file (config.json). A single BUILD parameter is possible, eg.

```my ModuleCitation $mc .= new(:verbose);```

  **:verbose** is False by default. If passed as True, then log messages are printed to STDOUT.

The following are the main public methods.

* **get-latest-project-file**  
    The script collects the current Ecosystem `projects.txt` file and stores it with a datestamp in the archive directory.

* **update**  
    Compares the files in the archive with the files listed in the database. The project file is added to the archive. If the date of the file is already present in the database, it is marked as a duplicate. If it is data for a new date, then it is added to the citation table of the database.  
    Returns True for a normal exit, and False if an error occured in a file due to a Tarjan loop, a Json error, or an incomplete download. The intent is to use a False return to trigger another download of meta data.

* **update-csv-files**  
    Generates the csv files for the html graphical modules.

* **generate-html**  
    Generates the html file based on a template.

* **compile-task-popular**  
    Creates the META6.json and README.md files for the Task::Popular distribution. An existing META6.json needs to be in the directory for the file, and the top of the README file, called readme.start.md. The method assumes the existence of a database.

## Configuration

  The following is a typical configuration file
``` JSON
  {
      "database-name": "citations",
      "ecosystem-url":"http://ecosystem-api.p6c.org/projects.json",
      "archive-directory": "arc",
      "target-directory": "db",
      "html-template": "CitationTemplate.tmpl",
      "html-directory": "html",
      "logfile": "citation.log",
      "top-limit": "50",
      "task-popular-directory": "popular",
      "task-popular-number": 30
  }
```
* **top-limit** is the the number of modules to be listed.
* **task-popular-number** is the number of modules to be included in the distribution list

# ModuleCitation
Scripts and module for generating a citation index for modules in the Perl6 ecosystem

[General](#general)  
[Process](#process)  
[Scripts](#scripts)  
[Configuration](#configuration)  

## General

The Perl6 Ecosystem has a large number of modules and it is interesting to see which are used the most frquently,
and it will be interesting to see how this profile changes over time.

The Ecosystem has a file with meta information about each _top line_ module (other modules in the ecosystem
are contained in sub-directories of the _top line_ modules.

Each module lists the modules it `"depends"` on. We call this a
*citation* of another module, which is then called *cited* module. By gathering information over the whole
ecosystem, it is possible to generate a *citation index* for each _top line_ Ecosystem module. The citation index is
defined as the percentage fraction
of the number of times that module is cited compared to the total number of citations. Each module is only
allowed to *cite* another module once.

A *simple* search collects only citations in the `"depends"` list. A *recursive* search collects citations in modules
that are *cited* by the modules in the `"depends"` list, and the citations in those modules. The Tarjan algorithm is used to detect where
possible loops may occur to prevent a recursive abyss.

## Process
The Perl6 Ecosystem is defined by a file called projects at http://ecosystem-api.p6c.org/projects.json

The file is downloaded, and stored in an archive.
The json is processed to the names and the children, and the results are stored in an SQLite3 database.
The ecosystem struture is created and analysed to create the citation indices.
A static html file is created, together with the data files needed by the graphical engines used in the html.
The html components are stored to a git repository that is then pushed to github (in a bash script), where github makes it public.


## Scripts

A single ModuleCitation object is created, and on creation looks for a mandatory configuration file (config.json). A single BUILD parameter is possible, eg.
my ModuleCitation $mc .= new(:verbose);

  **:verbose** is False by default. If passed as True, then log messages are printed to STDOUT.

The following are the main public methods.

* **get-latest-project-file**
    The script collects the current Ecosystem `projects.txt` file and stores it with a datestamp in the archive directory.

* **update**
    Compares the files in the archive with the files listed in the database. The project file is added to the archive. If the date of the file is already present in the database, it is marked as a duplicate. If it is data for a new date, then it is added to the citation table of the database.

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

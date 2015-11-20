# ModuleCitation
Scripts and module for generating a citation index for modules in the Perl6 ecosystem

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

A *simple* search collects only citations in the `"depends"` list. A *recursive*<sup>1</sup> search collects citations in modules
that are *cited* by the modules in the `"depends"` list, and the citations in those modules. 

<sup>1</sup> To prevent a 
citation loop, eg. Module1 -> module2 -> ... -> Module1, the recursion level is clamped at 50. 

TODO: use a cycle detection algorithm to break a recursive loop. But currently, 50 levels of recursion seems sufficient to gather 
all citations.
TODO: implement date options to show the change in CI for a module(s) using data in the ./archive/ directory.

##Scripts

* **GatherCitations.pl**
    The script collects the Ecosystem `projects.txt` file and gathers the citation results. The projects file and the data are stored
    in ./archive/ with a date (from `DateTime(now)` ).


* **CitationAnalyse.pl** [--top=nn] [--col=nn] [--textfile] [--screen] [--html] [--rowtotal=nn]

  The script finds the latest CitationData file in archive, calculates the simple and recursive indices, then outputs the results
depending on the inputs.

  **textfile**=True puts the **top** results into three columns and creates a local text file.

  **screen**=True puts the results onto the screen

  **html**=True uses CitationTemplate.tmpl (HTML::Template) to create the local file `index.html`. This is the file used for the
	github gh-pages build.

  No options assumes the defaults: top=50, col=2, textfile=false, screen=true, html=false.

  Other parameter(s) or invalid input trigger the useage string.


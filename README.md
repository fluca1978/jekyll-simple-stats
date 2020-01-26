# Jekyll Simple Statistic Generator

This repository contains a couple of Perl applications to quickly generate some statistical information about the blog activity, supposing of course you use Jekyll as a blog engine.

In the beginning there was only a Perl 5 script, then on January 2020 I decided to rewrite it in Perl 6. The two scripts are not the same, they act slightly differently, but chances are the Perl 5 one will no more be mantained.

## Main Differences Between the Versions

The Perl 5 script generates a single file to be included into your Jekyll page to show the stats; on the other hand, the Raku script generates a file per year to be included. While this requires a little more manual tweak, it provides more modularity.

The Perl 5 script provides, so far, more options to instrument the script, however the Raku one is OOP and is much more consistent in the file and directory naming.

The script names are different: the Raku script has a shorter name `jss.p6`, while the Perl 5 script has a verbose name `jekyll_simple_stats.pl`.

# The Raku Script

## Synopsis

```shell
% perl6 jss.p6 --jekyll-home=<where is your blog> 
```

## Usage

The mandatory argument `jekyll-home` must be specified as the path to your local Jekyll directory.
The script will inspect the `_posts` subdirectory looking for posts and will organize them into a few data structures:
- a `Post` object for every text file will be produced, such object contains the title, the tags and the year and month of the post;
- `Post`s will be grouped into a `Stat` object, that is able to graph them by month and tag;
- a `Blog` object is the entry point for the application and is responsible for creating the former two objects.

The data structures could change in the future.

At the end of the execution, the script will produce a message telling you which files must be included:
```shell
All done, please check that your stat file on your blog has
all the following includes (without any leading space!):

{% include stats/2020.md %}
{% include stats/2019.md %}
{% include stats/2018.md %}
{% include stats/2017.md %}
{% include stats/2016.md %}
{% include stats/2015.md %}
{% include stats/2014.md %}
{% include stats/2013.md %}
{% include stats/2012.md %}
{% include stats/2011.md %}
{% include stats/2010.md %}
{% include stats/2009.md %}
{% include stats/2008.md %}
```

The output could be different depending on your post ratio and years.

The script will generate the following files:
- images files into your Jekyll home, folder `images/stats`, two PNG files per year (e.g., `2008-tags.png`, `2008-months.png`);
- text file (in markdown format) into your Jekyll home, folder `_includes/stats/_`, one per year (e.g., `2008.md`).

### Partial Stats Generation

It is possible to specify two optional parameters to perform a partial generation:
- `--year=dddd` does generate only the specified year, if there is some content to generate;
- `--year=current` generates only the current year, in order to speed up the generation while keeping old stats untouched.


# The Perl 5 Script

## Synopsis

```shell
jekyll_simple_stats.pl [-chipqtv] [long options...]
        -h STR --home STR    local blog main folder, all other will be
                             derived from here
        -p STR --posts STR   posts directory (e.g., _posts)
        -i STR --images STR  images directory (e.g., images/graphs)
        -t STR --texts STR   path to put text files in markdown (e.g.,
                             _include/stats/)
        -v --verbose         verbose output
        -q --quiet           quiet output (supress normal output)
        --help               help output
        -c STR --count STR   tag count (default 10)
```

## Usage

The only mandatory argument is `home`, that is your local web site directory:

```shell
% perl jekyll_simple_stats.pl -v -h ~/git/fluca1978.github.io
```

The script assumes your graphs will be generated in `images/graphs`, your post directory is `_posts` and the include directory is `_includes_. You can change such setting by using appropriate command options.

The script will generate two PNG files per year, one with the posting activity by month, and one by most used tags.

## Dependencies

The script requires:
- Perl 5
- GnuPlot
- Perl 5 modules `Getopt::Long::Descriptive` and `File::Find`


## Improvements

Since I'm not a `gnuplot` user, the graphical part can be aggresively improved!
Just open an issue or contact me.


# Example on my personal web site

See [my stats page](https://fluca1978.github.io/stats).

See also [this blog post](https://fluca1978.github.io/2019/07/10/JekyllStatistics.html) about the rationale.

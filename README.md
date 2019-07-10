# Jekyll Simple Statistic Generator

This repository contains a *quick and dirt* Perl 5 script to generate some blog post activity counting.
The idea is to be able to scan your local blog and produce some graphs to place into it by including an automatically generated piece of HTML.



## Synopsis

```shell
jekyll_simple_stats.pl [-cdhitv] [long options...]
        -h STR --home STR    local blog main folder, all other will be
                             derived from here
        -d STR --posts STR   posts directory (e.g., _posts)
        -i STR --images STR  images directory (e.g., images/graphs)
        -t STR --texts STR   path to put text files in markdown (e.g.,
                             _include/stats/)
        -v --verbose         verbose output
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

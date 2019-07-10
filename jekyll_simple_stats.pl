#!env perl
use v5.20;
use File::Find;
use Data::Dumper;
use Getopt::Long::Descriptive;
use File::Spec;

# configure options and help
my ($opts, $usage) = describe_options(
    "%c %o",
    [ 'home|h=s',   'local blog main folder, all other will be derived from here', { required => 1} ],
    [ 'posts|p=s',  'posts directory (e.g., _posts)',                                               ],
    [ 'images|i=s', 'images directory (e.g., images/graphs)',                                       ],
    [ 'texts|t=s',  'path to put text files in markdown (e.g., _include/stats/)',                   ],
    [ 'verbose|v',  'verbose output'                                                                ],
    [ 'help',      'help output' , { shortcircuit => 1 }                                           ],
    [ 'count|c=s',  'tag count (default 10)' ,                                                      ],
    );



# se e' stato richiesto l'help lo visualizzo ed esco
if ( $opts->help ){
    say $usage->text;
    say << "HELP";
    Invocation example:

    perl $0 -h ~/git/fluca1978.github.io
HELP
    }


# This is the hash that collects the data about all the posts.
# It is indexed by the year, than the STATS and year+month or TOP and labels.
# As an example
# $posts
#     2019
#        STATS
#           2019-01 = 12
#           2019-02 = 3
#           ...
#       TAGS
#          postgresql = 10
#          java       = 2
#
#       TOTAL         = 22
my $posts = {};

my $post_filter = sub {
    # ensure this is a file
    # and has a correct name
    return if ( ! -f $_ );
    return if ( $_ !~ /^(\d{4})-(\d{2})-\d{2}.*$/ );

    my ( $year, $month );

    if ( $_ =~ /^(\d{4})-(\d{2})-\d{2}.*$/ ){
        ( $year, $month ) = ( $1, $2 );
        $posts->{ $year }->{ STATS }->{ "$year-$month" }++;
        $posts->{ $year }->{ TOTAL }++;
    }

    # read the tags
    open my $fh, "<", $File::Find::name;
    my @tags = ();
    my $found = undef;
    while ( my $line = <$fh> ) {
        $found = 1 if ( $line =~ /^tag(s)?:/ );
        if ( $found && $line =~ /^\-\s+(\w+)$/ ){
            push @tags, lc $1;
        }
        last if ( $found && $line =~ /^[-]{3}$/ );
    }
    close $fh;

    for my $tag ( @tags ){
        next if ( ! $tag );
        $posts->{ TAGS }->{ $tag }++; # global tags
        $posts->{ $year }->{ TAGS }->{ $tag }++;  #per year tags
    }
};


my $posts_directory   = $opts->posts  || File::Spec->catdir( $opts->home, '_posts' );
my $images_directory  = $opts->images || File::Spec->catdir( $opts->home, 'images/graphs' );
my $include_directory = $opts->texts  || File::Spec->catdir( $opts->home, '_includes/' );

# ensure all paths are absolute
$posts_directory   = File::Spec->rel2abs( $posts_directory );
$images_directory  = File::Spec->rel2abs( $images_directory );
$include_directory = File::Spec->rel2abs( $include_directory );

# inform the user about running directories
say <<"_DIR_";
Running with the following directories:
    posts to index => $posts_directory
    graphs path    => $images_directory
    include path   => $include_directory

_DIR_

# recompute the image relative directory in case it has been specified
my $images_relative_directory = File::Spec->catdir( (File::Spec->splitdir( $images_directory ))[-2,-1]  );

# check arguments
for ( ( $opts->home, $posts_directory, $images_directory, $include_directory ) ) {
    die "\nDirectory [$_] does not exists" if ( ! -d $_ );
}


my $top_tag_count = $opts->count || 10;
my $include_stats_file = File::Spec->catfile( $include_directory, 'stats.html' );
open my $stats, '>', $include_stats_file || die "\nCannot open $include_stats_file\n$!\n";


# let's start the real job: populate the hash with the results
say "Inspecting $opts->posts ... please wait" if ( $opts->verbose );
find ( $post_filter, $posts_directory );
# say Dumper( $posts );

say 'Generating CSV files ...' if ( $opts->verbose );
for my $year ( reverse sort keys %$posts ){
    # avoid special keys
    next if ( ! int( $year ) );




    say "$posts->{ $year }->{ TOTAL } total posts in $year" if ( $opts->verbose );

    my $current_file_csv = "/tmp/data-$year.csv";
    say "Generating data file $current_file_csv" if ( $opts->verbose );
    open my $csv, '>', $current_file_csv || die "\nCannot produce data file $current_file_csv\n$!\n";
    # write each line for the specific month
    say {$csv} "$_;$posts->{ $year }->{ STATS }->{ $_ };" for ( sort keys %{ $posts->{ $year }->{ STATS } } );
    close $csv;

    my $current_file_gnuplot = "/tmp/data-$year.gnuplot";
    say "Generating plot file $current_file_gnuplot" if ( $opts->verbose );
    open my $gnuplot, '>', $current_file_gnuplot || die "\nCannot produce plot file $current_file_gnuplot\n$!\n";
    say {$gnuplot} << "GNUPLOT";
#!env gnuplot
reset
set terminal png

set title "$year Post Ratio"
set xlabel "Month"
set xdata time
set timefmt '%Y-%m'
set format x "%b/%y" # Or some other output format you prefer
set xtics "$year-01", 7776000 rotate by 60 right
set datafile separator ';'
set ylabel "Number of Posts"
set grid
set style fill solid 1.0
set boxwidth 0.9 relative

plot "$current_file_csv"  using 1:2 title "" with boxes linecolor rgb "#bb00FF"
GNUPLOT

    close $gnuplot;

    my $current_file_png = File::Spec->catfile( $images_directory, $year . '.png' );
    say "Generating image file $current_file_png" if ( $opts->verbose );
    `gnuplot $current_file_gnuplot > $current_file_png`;
    unlink $current_file_gnuplot;
    unlink $current_file_csv;

    # redo for the TAGS
    open my $csv, '>', $current_file_csv || die "\nCannot produce data file $current_file_csv\n$!\n";
    my $top = 0;
    my @keys = sort  { $posts->{ $year }->{ TAGS }->{ $b } <=> $posts->{ $year }->{ TAGS }->{ $a } }
                     keys %{ $posts->{ $year }->{ TAGS } };
    # write only the top tags
    for $_ ( @keys ){
        say {$csv} "$_;$posts->{ $year }->{ TAGS }->{ $_ };";
        $top++;
        last if ( $top >= $top_tag_count );
    }
    close $csv;
    open my $gnuplot, '>', $current_file_gnuplot || die "\nCannot produce plot file $current_file_gnuplot\n$!\n";
    say {$gnuplot} << "GNUPLOT";
#!env gnuplot
reset
set terminal png
set title "$year Most Frequent Tags"
set auto x
set xlabel "Tag"
set xtics rotate by 60 right
set datafile separator ';'
set ylabel "Posts"
set style fill solid 1.0
set boxwidth 0.9 relative
plot "$current_file_csv"  using 2:xtic(1) title "" with boxes linecolor rgb "#bb00FF"
GNUPLOT
    close $gnuplot;

    my $current_tag_png = File::Spec->catfile( $images_directory,  $year . '-tags.png' );
    say "Generating image file $current_tag_png" if ( $opts->verbose );
    `gnuplot $current_file_gnuplot > $current_tag_png`;
    unlink $current_file_gnuplot;
    unlink $current_file_csv;


    # produce this year report on the stat markdown file
    my $top_categories = join( ', ' , @keys[0,1,2] );
    say {$stats} << "_STATS_";
## $year
<b>$posts->{ $year }->{ TOTAL } posts</b> written in $year.
<br/>
Top categories are: <b>$top_categories</b>

<center>
<img src="/$images_relative_directory/$year.png" />
<br/>
<img src="/$images_relative_directory/$year-tags.png" />
</center>
_STATS_


}



# inform about the stats
my $now = localtime;
say {$stats} << "_STATS_";
<small>
The above statistical data has been generated automatically on $now
via <a href="https://github.com/fluca1978/jekyll-simple-stats" target="_new">
    Jekyll Simple Stats by Luca Ferrari
    </a>
</small>
_STATS_

close $stats;

say << "_HELP_";

All done!
Remember to include the stats file with something like this:
    {% include stats.html %}
_HELP_

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
    [ 'quiet|q',   'quiet output (supress normal output)'                                           ],
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


# check that verbose and quite mode are not both active
die "\nCannot specify `verbose` and `quiet` mode at the same time!\n" if ( $opts->verbose && $opts->quiet );


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
say <<"_DIR_" unless( $opts->quiet );
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


# get the current year
my $current_year = ( localtime() )[ 5 ] +  1900;

my $top_tag_count = $opts->count || 10;
my $include_stats_file = File::Spec->catfile( $include_directory, 'stats.html' );
open my $stats, '>', $include_stats_file || die "\nCannot open $include_stats_file\n$!\n";


# let's start the real job: populate the hash with the results
say "Inspecting $opts->posts ... please wait" if ( $opts->verbose );
find ( $post_filter, $posts_directory );
# say Dumper( $posts );



# generate a summary about all years and tags
say {$stats} '## Blog Activity';
say {$stats} 'The following is a glance at the blogging activity across all years:';
for my $year ( reverse sort keys %$posts ){
    next if ( ! int( $year ) );
    say {$stats} sprintf ' - %04d : %d total posts across %d different categories;',
                                                                                      $year,
                                                                                      $posts->{ $year }->{ TOTAL },
                                                                                      scalar keys %{ $posts->{ $year }->{ TAGS } };
}



# generate a per-year overall graph
{
    say 'Generating years ...' if ( $opts->verbose );
    my $current_file_csv     = File::Spec->catfile( File::Spec->tmpdir(), 'years.csv' );
    my $current_file_gnuplot = File::Spec->catfile( File::Spec->tmpdir(), 'years.gnuplot' );

    open my $csv, '>', $current_file_csv || die "\nCannot produce data file $current_file_csv\n$!\n";

    for my $year ( sort keys %$posts ){
        next if ( ! int( $year ) );
        say {$csv} sprintf '%04d;%d;',
                                        $year,
                                        $posts->{ $year }->{ TOTAL };
    }

    close $csv;

    open my $gnuplot, '>', $current_file_gnuplot || die "\nCannot produce plot file $current_file_gnuplot\n$!\n";
    say {$gnuplot} << "GNUPLOT";
#!env gnuplot
reset
set terminal png
set title "Post Ratio per-Year"
set auto x
set xlabel "Year"
set xtics rotate by 60 right
set datafile separator ';'
set ylabel "Posts"
set grid
set style fill solid 1.0
set boxwidth 0.9 relative
plot "$current_file_csv"  using 2:xtic(1) title "" with boxes linecolor rgb "#bb00FF"
GNUPLOT
    close $gnuplot;

    my $current_years_png = File::Spec->catfile( $images_directory,  'years.png' );
    say "Generating image file $current_years_png" if ( $opts->verbose );
    `gnuplot $current_file_gnuplot > $current_years_png`;
    unlink $current_file_gnuplot;
    unlink $current_file_csv;


    say {$stats} << "_STATS_";
<center>
<img src="/$images_relative_directory/years.png" />
</center>
_STATS_

}


# generate a categories overall graph
{
    say 'Generating main categories ...' if ( $opts->verbose );
    my $current_file_csv     = File::Spec->catfile( File::Spec->tmpdir(), 'tags.csv' );
    my $current_file_gnuplot = File::Spec->catfile( File::Spec->tmpdir(), 'tags.gnuplot' );

    open my $csv, '>', $current_file_csv || die "\nCannot produce data file $current_file_csv\n$!\n";
    my $top = 0;
    my @keys = sort  { $posts->{ TAGS }->{ $b } <=> $posts->{ TAGS }->{ $a } }
                     keys %{ $posts->{ TAGS } };
    # write only the top tags
    for $_ ( @keys ){
        say {$csv} "$_;$posts->{ TAGS }->{ $_ };";
        $top++;
        last if ( $top >= $top_tag_count );
    }
    close $csv;
    open my $gnuplot, '>', $current_file_gnuplot || die "\nCannot produce plot file $current_file_gnuplot\n$!\n";
    say {$gnuplot} << "GNUPLOT";
#!env gnuplot
reset
set terminal png
set title "Most Frequent Tags"
set auto x
set xlabel "Tag"
set xtics rotate by 60 right
set datafile separator ';'
set ylabel "Posts"
set grid
set style fill solid 1.0
set boxwidth 0.9 relative
plot "$current_file_csv"  using 2:xtic(1) title "" with boxes linecolor rgb "#bb00FF"
GNUPLOT
    close $gnuplot;

    my $current_tag_png = File::Spec->catfile( $images_directory,  'tags.png' );
    say "Generating image file $current_tag_png" if ( $opts->verbose );
    `gnuplot $current_file_gnuplot > $current_tag_png`;
    unlink $current_file_gnuplot;
    unlink $current_file_csv;


    say {$stats} << "_STATS_";
<center>
<img src="/$images_relative_directory/tags.png" />
</center>
_STATS_

}


say 'Generating CSV files ...' if ( $opts->verbose );
for my $year ( reverse sort keys %$posts ){
    # avoid special keys
    next if ( ! int( $year ) );


    # autovivification of months that are not yeat produced:
    # if the year is a work in progress, some months will not be available
    # yet because they are in the future, so place them with a zero post
    # count to allow the correct graph to show up
    for my $current_month ( 1 .. 12 ){
        my $yk = sprintf( '%04d-%02d', $year, $current_month );
        $posts->{ $year }->{ STATS }->{ $yk } //= 0;
    }


    say "$posts->{ $year }->{ TOTAL } total posts in $year" if ( $opts->verbose );

    my $current_file_csv = File::Spec->catfile( File::Spec->tmpdir(), "$year.csv" );
    say "Generating data file $current_file_csv" if ( $opts->verbose );
    open my $csv, '>', $current_file_csv || die "\nCannot produce data file $current_file_csv\n$!\n";
    # write each line for the specific month
    say {$csv} "$_;$posts->{ $year }->{ STATS }->{ $_ };" for ( sort keys %{ $posts->{ $year }->{ STATS } } );


    close $csv;

    my $current_file_gnuplot = File::Spec->catfile( File::Spec->tmpdir(), "$year.gnuplot" );
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
set format x "%B (%Y)"
set xrange ["$year-01":"$year-12"]
set xtics "$year-01", 2592000 rotate by 60 right
set datafile separator ';'
set ylabel "Number of Posts"
set grid
set style fill solid 1.0
set boxwidth 0.8 relative

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

    # in the case the number of tags is less than the required one, fill the graph
    # with empty data
    while ( $top < $top_tag_count ){
        say {$csv} ";0;";
        $top++;
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
    # please note that the categories for this year could be less than
    # the number required by the user, so try to compute it and ajust to
    # the minimum
    my $top_categories_threshold = $top_tag_count < $#keys
        ? $top_tag_count
        : scalar @keys;
    my $top_categories = join( ', ' , @keys[ 0 .. $top_categories_threshold ] );

    my $warning_year_in_progress = undef;
    if ( $current_year == $year ){
        $warning_year_in_progress = '(work in progress!)';
    }
    say {$stats} << "_STATS_";

### $year $warning_year_in_progress
<b>$posts->{ $year }->{ TOTAL } posts</b> written in $year across @{[ scalar @keys ]} different categories.
<br/>
Topmost <i>$top_categories_threshold</i> categories in <i>$year</i> are: <b>$top_categories</b>

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
    Jekyll Simple Stats 
    </a>
    <a href="https://fluca1978.github.io" target="_new">
    by Luca Ferrari
    </a>
</small>
_STATS_

close $stats;

say << "_HELP_" unless( $opts->quiet );

All done!
Remember to include the stats file with something like this:

    {% include stats.html %}

in the file your are going to publish with Jekyll.
Also remember to add changed graphs and stats to your git commit!
_HELP_

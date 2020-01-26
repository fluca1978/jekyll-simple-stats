#!env perl6

# Jekyll Simple Stats
#
# A simple program to generate very basic statistics
# about a Jekyll blog.
#
# Rewritten in Perl 6 on January 2020
#

# A regex to parse the name of a post file,
# that is done with yyyy-mm-dd-title
my regex rx_post_filename { ^ $<year>=\d ** 4 \- $<month>=\d ** 2 \- $<day>=\d ** 2 };

# A regex to match the begin and end of the Markdown Frontmatter stuff.
my regex rx_frontmatter_edge { ^ \- \- \- $ };

# A regex to match a title in the markdown part
#my regex rx_post_title { ^ title\: \s+ <["|']>? $<title>=(.*) <["|']>? $  }
my regex rx_post_title { ^ title\: \s+ $<title>=(.+)  $  }

# A regex to match a single tag line
my regex rx_post_single_tag { ^ \- \s+ $<tag>=<[\w - ]>+ $ }

# A post class represent the amount
# of information required to generate a post
# statistic data.
class Post
{
    has IO::Path $.filename;
    has Str @.tags;

    has Int $!year;
    has Int $!month;
    has Str $!title;

    submethod BUILD( IO::Path :$filename ) {
        $!filename := $filename;
        self!extract-info();
    }


    # extract all the info
    # required to elaborate the statistics data
    method !extract-info(){
        $!year  = $!filename.basename.match( /<rx_post_filename>/ )<rx_post_filename><year>.Int();
        $!month = $!filename.basename.match( /<rx_post_filename>/ )<rx_post_filename><month>.Int();

        # extract the tags
        self!extract-tags-and-title();
    }

    # A method to parse the tags of the post content.
    method !extract-tags-and-title(){
        my $tags-found = False;
        my $front-matter-found = False;
        for $!filename.IO.lines -> $line {
            if ! $front-matter-found && $line.match( /<rx_frontmatter_edge>/ )  {
                $front-matter-found = True;
                next;
            }

            if $front-matter-found {

                # got the post title?
                if $line.match( /<rx_post_title>/ ) {
                    $!title = $/<rx_post_title><title>.Str.subst( /<["|']>/, '', :g ).trim();
                    next;
                }


                if ( ! $tags-found && $line ~~ /^tags:/ ) {
                    $tags-found = True;
                    next;
                }

                if ( $tags-found && $line ~~ /<rx_post_single_tag>/ ) {
                    @!tags.push: $/<rx_post_single_tag><tag>.Str.trim.lc;
                }
                elsif ( $tags-found && $line ~~ /<rx_frontmatter_edge>/ ) {
                    last;
                }
            } # end of the frontmatter within parsing

        }
    }

    method year(){ $!year; }
    method month(){ '%02d'.sprintf: $!month; }
    method title(){ $!title }

    # Use to print out this post object.
    # Examples:
    #
    # say $post.Str;
    # print $post;
    method Str(){
        "⤷ %s\n\t%04d-%02d\n\tTitle: [%s]\n\tTags: [%s]".sprintf:
        $!filename.basename,
        $!year,
        $!month,
        $!title,
        join( ', ', @!tags );
    }

}

# A Stat class contains all the informations for the stats
# of a single year, including the per-year and per-month stats.
class Stat {

    has %!posts-count; # how many posts are there in every single month
    has %!tags-count;  # how many posts are there for a specific tag
    has Int $!year;
    has IO::Path $!filename;
    has IO::Path $!include-directory;
    has IO::Path $!graph-tags-filename;
    has IO::Path $!graph-months-filename;
    has IO::Path $!home-directory;

    submethod BUILD( :@posts,
                     Int:D :$year,
                     :$blog ){

        fail "No posts!" if ! @posts;

        $!year = $year;

        for @posts -> $post {
            next if $post !~~ Post;
            # increase the number of the posts for the specified month
            %!posts-count{ $post.month }++;

            # increase the counts of the tags
            for @( $post.tags ) -> $tag {
                %!tags-count{ $tag }++;
            }
        }

        $!include-directory = $blog.dir-stats.IO;
        # create all other IO objects
        $!filename = $!include-directory.add( "{$!year}.md" );  # something like _includes/stats/2020.md
        $!graph-tags-filename   = $blog.dir-images.IO.add( "{$!year}-tags.png" ); # e.g., imgaes/2020-tags.png
        $!graph-months-filename = $blog.dir-images.IO.add( "{$!year}-months.png" ); # e.g., images/2020-months.png
        $!home-directory = $blog.dir-home.IO;
    }

    method year(){ $!year; }

    method count(){
        my $sum = 0;
        for %!posts-count.keys -> $month {
            $sum += %!posts-count{ $month };
        }

        return $sum;
    }

    method count-tags() {
        %!tags-count.keys.elems;
    }

    method count-per-month( Int $month ){
        %!posts-count{ $month } ?? %!posts-count{ $month } !! 0;
    }

    # Returns a list of Pair objects, where the key is the tag name
    # and the value is the post count.
    method tags( Int $limit = 10){
        my @tags =  %!tags-count.pairs.sort( { $^b.value <=> $^a.value } );
        return @tags[ 0..$limit ];
    }


    method Str {
        "%04d\n\t%d total posts\n\t%d total tags\n\tMain tags:\n\t\t%s".sprintf:
        $!year,
        self.count,
        self.count-tags,
        join( ",\n\t\t", self.tags );
    }

    method !is-current-year(){
        my $now = DateTime.now;
        return $now.year == $!year;
    }


    method !graph-tags-url() {
        my $url = $!graph-tags-filename;
        my $home = $!home-directory;
        $url ~~ s/$home//;
        $url;
    }

    method !graph-months-url() {
        my $url = $!graph-months-filename;
        my $home = $!home-directory;
        $url ~~ s/$home//;
        $url;
    }


    method !generate-tags-graph(){
        my $csv-temp-file = "/tmp/{$!year}-tags.csv";
        my $gnuplot-file  = "/tmp/{$!year}-tags.gnuplot";

        my $fh = open $csv-temp-file, :w;
        for self.tags -> $tag-pair {
            $fh.say( '%s;%d;'.sprintf( $tag-pair.key, $tag-pair.value ) );
        }

        $fh.close;

        my $gnuplot = qq:to/_GNUPLOT_/;
        #!env gnuplot
        reset
        set terminal png
        set title "{ $!year } Most Frequent Tags"
        set auto x
        set xlabel "Tag"
        set xtics rotate by 60 right
        set datafile separator ';'
        set ylabel "Posts"
        set style fill solid 1.0
        set boxwidth 0.9 relative
        plot "$csv-temp-file"  using 2:xtic(1) title "" with boxes linecolor rgb "#bb00FF"
        _GNUPLOT_

        spurt $gnuplot-file, $gnuplot;

        # now run gnuplot
        shell "gnuplot $gnuplot-file > $!graph-tags-filename";

        # remove the files
        $csv-temp-file.IO.unlink;
        $gnuplot-file.IO.unlink;
    }


    method !generate-months-graph(){
        my $csv-temp-file = "/tmp/{$!year}-months.csv";
        my $gnuplot-file  = "/tmp/{$!year}-months.gnuplot";

        my $fh = open $csv-temp-file, :w;
        # WARNING: need to iterate on all the months or 0-months will
        # make gnuplot complain!
        for 1..12 -> $month {
            my $key = sprintf '%02d', $month;
            my $count = %!posts-count{ $key } // 0;
            $fh.say( '%04d-%02d;%d;'.sprintf( $!year, $key, $count ) );
        }

        $fh.close;

        my $gnuplot = qq:to/_GNUPLOT_/;
        #!env gnuplot
        reset
        set terminal png
        set title "{ $!year } Post Ratio"
        set xlabel "Month"
        set xdata time
        set timefmt '%Y-%m'
        set format x "%B"
        set xrange ["{ $!year }-01":"{ $!year }-12"]
        set xtics "{ $!year }-01", 2592000 rotate by 60 right
        set datafile separator ';'
        set ylabel "Number of Posts"
        set grid
        set style fill solid 1.0
        set boxwidth 0.8 relative
        plot "$csv-temp-file"  using 1:2 title "" with boxes linecolor rgb "#bb00FF"
        _GNUPLOT_

        spurt $gnuplot-file, $gnuplot;

        # now run gnuplot
        shell "gnuplot $gnuplot-file > $!graph-months-filename";

        # remove the files
        $csv-temp-file.IO.unlink;
        $gnuplot-file.IO.unlink;
    }



    method generate-markdown(){
        self!generate-tags-graph;
        self!generate-months-graph;

        my $markdown = qq:to/_MD_/;
        ## { $!year } { self!is-current-year ?? '(work in progress)' !! '' }

        **{ self.count } total posts** have been written on { $!year }.
        There have been *{ self.count-tags } different tags* used, the most
        used popular being (in order of number of posts):
        _MD_
        for self.tags -> $tag-pair {
            $markdown = "%s \n- *%s* (%d posts) ".sprintf: $markdown, $tag-pair.key, $tag-pair.value;
        }

        $markdown .= trim;
        $markdown  = $markdown ~ '.';


        my $now = DateTime.now( formatter =>
                                { '%s at %d:%02d'.sprintf: .yyyy-mm-dd, .hour, .minute } );


        $markdown = $markdown ~ qq:to/_MD_/;
        <br/>
        <br/>
        The following is the overall { $!year } post ratio by month:
        <br/>
            <center>
              <img src="{ self!graph-months-url.Str }" alt="{ $!year } post ratio per month" />
            </center>
        <br/>

        <br/>
        The following is the overall { $!year } post ratio by tag:
        <br/>
          <center>
            <img src="{ self!graph-tags-url.Str }" alt="{ $!year } post ratio per tag" />
          </center>
        <br/>

        <div align="right">
        <small>
        Last generated on { $now.Str }
        </small>
        </div>

        <br/>
        _MD_


        spurt $!filename, $markdown;
    }


    method jekyll-include-string(){
        # must be a path relative to the include dir!
        my ( $dir, $file ) = $!filename.path.split( '/' ).reverse[ 1, 0 ];
        my $relative-filename = $dir.IO.add( $file );
        qq:to/_INCLUDE_/;
        \{% comment %\} Stats for year { $!year } \{% comment %\}
        \{% include { $relative-filename } %\}
        _INCLUDE_
    }
}



# A Blog class represents the information about a Jekyll
# installation, with particular regard to the directory
# structure.
class Blog {
    has Str $.dir-home;     # the main directory of the blog
    has Str $.dir-posts;    # where the posts are
    has Str $.dir-stats;    # where the stats will be produced
    has Str $.dir-images;   # where the images will be placed

    has Post @.posts;       # a list of posts

    # effective years of blog posts found
    has Int @.years;

    # An info method to display the content
    # of this blog object.
    method print-dirs(){
        say qq:to/_DIRS_/;
        Home directory in [$!dir-home]
             Posts in     [$!dir-posts]
             Images in    [$!dir-images]
             Stats in     [$!dir-stats]
        _DIRS_
    }


    method generate-dirs-if-needed(){
        my @dirs = ( $!dir-stats, $!dir-images );
        for @dirs -> $dir {
            $dir.IO.mkdir if ! $dir.IO.d;
        }
    }


    method scan( Int :$year? ) {
        say 'Inspecting the post directory...';
        my %found-years;

        for $!dir-posts.IO.dir() -> $post-file {
            # skip non file stuff..
            next if ! $post-file.f;
            # skip the file if the year is not good!
            next if $year && ! $post-file.basename.match: / ^ $year /;

            my $post = Post.new( filename => $post-file );

            # save this year if not seen before
            %found-years{ $post.year }++;

            # store it in the list
            @!posts.push: $post;
        }

        fail "No posts found in the blog!" if ! @!posts;

        # stores the years
        @!years = %found-years.keys.sort.map: *.Int;
        say "Found { @!posts.elems } posts within years { @!years }";
    }

    method posts-as-hash() {
        my %posts-per-year;

        for @!posts -> $post {
            %posts-per-year{ $post.year }{ $post.month }.push: $post;
        }

        return %posts-per-year;
    }

    #
    # Provides all the posts in a specified year.
    # If no year is provided, all the posts are returned.
    method get-posts( Int :$year? ) {
        return @!posts if ! $year;
        return () if ! @!years.grep: $year;
        return @!posts.grep( { .year == $year } ) if $year;
    }


    method generate-markdown-credits {
        my $md = qq:to/_MD_/;
        <small>
        The graphs and statistical data have been generated
        by the Raku
        script  { $*PROGRAM.IO.basename } running on $*PERL via $*VM.
        <br/>
        See <a href="https://github.com/fluca1978/jekyll-simple-stats" target="_new">
               <i>Jekyll Simple Stats</i>
            </a>
        <a href="https://fluca1978.github.io" target="_new">
            by Luca Ferrari
        </a>
        .
        </small>
        _MD_

        # output the file
        my $credits-file = $!dir-stats.IO.add( 'credits.md' );
        $credits-file.spurt: $md;

        return '{%% include %s/%s %%}'.sprintf: $credits-file.path.split( '/' ).reverse[ 1, 0 ];
    }
}


multi sub MAIN( Bool :$help )
{
        USAGE();
}


multi sub MAIN(
    Str :$jekyll-home
    where { .so && .IO.d // warn "Please specify an existing home directory [$jekyll-home]" }


    , Str :$dir-posts?
    where { ! .defined || .IO.d || warn "Not an existing posts directory [$dir-posts]" }
        = $jekyll-home ~ '/_posts'

    , Str :$dir-images?
        = $jekyll-home ~ '/images/stats'

    , Str :$dir-stats?
        = $jekyll-home ~ '/_includes/stats'


    , Str :$year?
          where { ! .defined
                      || $_ ~~ / \d ** 4 | current | last | previous /
                      || warn 'Year must be of four digits!' }

   , Bool :$dry-run?
)
{
    my Blog $blog = Blog.new( :dir-home( $jekyll-home ),
                              :$dir-posts,
                              :$dir-stats,
                              :$dir-images );

    # show what we have configured so far
    $blog.print-dirs();
    $blog.generate-dirs-if-needed();

        # check which parameter for a single year we have
        # and in the case of 'current' use the current date year
    my Int $single-year = Nil;
    if $year {
        $single-year = DateTime.now.year.Int     if $year ~~ /current/;
        $single-year = DateTime.now.year.Int - 1 if $year ~~ /last | previous/;
        $single-year = $year.Int if $year ~~ Int;
    }

    # do the scan of the posts directory
    $blog.scan( :year( $single-year ) );

    # now scan across the years
    my @include-instructions;
    for $blog.years.sort.reverse {

        my @current-posts = $blog.get-posts( :year( $_ ) );

        # skip all the things if there are no post in this year
        next if ! @current-posts;

        my $stat = Stat.new: posts => @current-posts ,
        year => $_,
        blog => $blog;

        $stat.Str.say;

        # generate the files for this year
        $stat.generate-markdown if ! $dry-run;

        # store the include instructions
        @include-instructions.push: $stat.jekyll-include-string;
    }

    @include-instructions.unshift: $blog.generate-markdown-credits;


    say qq:to/_HELP_/;

    All done, please check that your stat file on your blog has
    all the following includes (without any leading space!):

    { @include-instructions.reverse.join( "\n" ) }
    _HELP_



    if $year {
        say qq:to/_EXTRA_HELP_/;

        ===================================================================
        WARNING: please note that you asked to generate only the $year year
        so there could be other years not included in this generation. Make
        sure your statistic data and included files are all in place and
        provide the result you want!
        ===================================================================

        _EXTRA_HELP_
    }

    if $dry-run {
        say qq:to/_EXTRA_HELP_/;

        ===================================================================
        WARNING: dry-run mode activated, no one file has been modified!
        All the information printed above is useful only to get an estimated
        count of the statistical data, but nothing has been updated!
        ===================================================================

       _EXTRA_HELP_
    }
    

}


sub USAGE() {
    print qq:to/EOH/;
    { $*USAGE }

    Generates statistics data about your blog depending on how you named the posts
    and the tags within the posts.
    The posts must be named liked 'YYYY_MM_DD' and whatever you like.
    The tags must be included into a 'tags' list.

    The Jekyll Home Directory is a mandatory argument and specifies the "home" of your
    blog. From such directory, subdirectories like '_includes', '_posts' and alike
    therefore your blog should adhere to Jekyll tree layout.


    It is possible to generate a single year, and this is helpful when you want to update
    only the statistics for the current year.
    In particulare the --year parameter allows you to specify a single year by expressing
    it as a four-digits number, or the special string 'current' to say the year
    the clock reveals (useful for automated scripts). It is also possible to specify
    the special string 'previous' (or 'last') to generate the year before the current one.

    In the case you use the --dry-run parameter, the script will act accordingly to
    your wills, but no markdown file will be generated at all.

    Please note that, in order for this to work, you need to include all the generated files
    into your markdown page that will show the statistics.

    As an example, the following is the invocation to generate all your statistics data:
                   {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog

   while if you want to update only a specific year you should invoke it as
                  {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog --year=2020

   and if you want to update only the current year you should invoke it as
                   {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog --year=current

   and if you want to update only the previous year you should invoke it as
                   {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog --year=previous


   It is possible to specify every single directory of your blog via the `--dir-xxx` parameters,
   such as for example:
                   {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog \\
                          --dir-posts=/path/to/blog/_posts         \\
                          --dir-images=/path/to/blog/images/stats  \\
                          --dir-stats=/path/to/blog/_include/stats \\

   EOH
}

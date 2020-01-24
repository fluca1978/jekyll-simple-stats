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
                     Int :$year,
                     :$blog ){
        $!year = $year;

        for @posts -> $post {
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
        _MD_


        spurt $!filename, $markdown;
    }


    method jekyll-include-string(){
        # must be a path relative to the include dir!
        my ( $dir, $file ) = $!filename.path.split( '/' ).reverse[ 1, 0 ];
        my $relative-filename = $dir.IO.add( $file );
        '{%% include %s %%}'.sprintf: $relative-filename;
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

    # range of years for the whole blog
    has Int ( $.year-min, $.year-max );

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
        for $!dir-posts.IO.dir() -> $post-file {
            # skip the file if the year is not good!
            next if $year && ! $post-file.basename.match: / ^ $year /;

            my $post = Post.new( filename => $post-file );

            # is this post changing the years boundaries?
            $!year-min = $post.year if ! $!year-min || $post.year < $!year-min;
            $!year-max = $post.year if ! $!year-max || $post.year > $!year-max;

            # store it in the list
            @!posts.push: $post;
        }

        say "Found { @!posts.elems } posts between years $!year-min and $!year-max";
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
        return Nil if $year > $!year-max || $year < $!year-min;
        return @!posts.grep( { .year == $year } ) if $year;
    }


    method generate-markdown-credits {
        my $now = DateTime.now( formatter =>
                                { '%s at %d:%02d'.sprintf: .yyyy-mm-dd, .hour, .minute } );
        my $md = qq:to/_MD_/;
        <small>
        The graphs and statistical data have been generated on
        $now
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





sub MAIN(
    Str :$jekyll-home
    where { .IO.d // die "Please specify a home directory [$jekyll-home]" }

    , Int :$year?
          where { $_ ~~ / \d ** 4 / || die 'Year must be of four digits!' }
)
{
    my Blog $blog = Blog.new( dir-home => $jekyll-home,
                              dir-posts => $jekyll-home ~ '/_posts',
                              dir-stats => $jekyll-home ~ '/_includes/stats',
                              dir-images => $jekyll-home ~ '/images/stats' );

    # show what we have configured so far
    $blog.print-dirs();
    $blog.generate-dirs-if-needed();

    # do the scan of the posts directory
    $blog.scan( :$year );

    # now scan across the years
    my @include-instructions;
    for $blog.year-min .. $blog.year-max {
        my $stat = Stat.new: posts => $blog.get-posts( :year( $_ ) ),
        year => $_,
        blog => $blog;

        $stat.Str.say;

        # generate the files for this year
        $stat.generate-markdown;

        # store the include instructions
        @include-instructions.push: $stat.jekyll-include-string;
    }

    @include-instructions.unshift: $blog.generate-markdown-credits;


    say qq:to/_HELP_/;

    All done, please check that your stat file on your blog has
    all the following includes (without any leading space!):
    _HELP_

    @include-instructions.reverse.join( "\n" ).say;

}

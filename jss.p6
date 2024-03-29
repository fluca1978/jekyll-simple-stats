#!raku


# Jekyll Simple Stats
#
# A simple program to generate very basic statistics
# about a Jekyll blog.
#
# Rewritten in Raku on January 2020
#


use Terminal::ANSIColor;


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
    has Int $!tag-limit;
    has IO::Path $!filename;
    has IO::Path $!include-directory;
    has IO::Path $!graph-tags-filename;
    has IO::Path $!graph-months-filename;
    has IO::Path $!home-directory;
    has Str $!graph-color where { .uc ~~ / ^ <[0..9A..F]> ** 6 $ / } = '00AA00';

    submethod BUILD( :@posts,
                     Int:D :$year,
                     :$blog,
                     Int:D :$tag-limit,
                     Str :$graph-color? ){

        fail "No posts for year $year!" if ! @posts;

        $!year = $year;
        $!graph-color = $graph-color if $graph-color;
        $!tag-limit   = $tag-limit;

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
    method tags(){
        my @tags =  %!tags-count.pairs.sort( { $^b.value <=> $^a.value } );
        my Int $limit = @tags.elems > $!tag-limit ?? $!tag-limit !! @tags.elems - 1;
        return @tags[ 0 .. $limit ];
    }


    method Str {
        "%04d\n\t%d total posts\n\t%d total tags\n\tMain tags:\n\t\t%s".sprintf:
        $!year,
        self.count,
        self.count-tags,
        join( ",\n\t\t", self.tags );
    }

    method !is-current-year(){ DateTime.now.year == $!year }


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
        use Chart::Gnuplot;
        use Chart::Gnuplot::Subset;


        # build an array of arrays, each line is a data
        my @data = self.tags.map: { [ .key, .value ] };
        my AnyTicsTic @tics = self.tags.map: { %( label => .key, pos => $++ ) };



        my $gnuplot = Chart::Gnuplot.new:
        terminal => 'png',
        filename => $!graph-tags-filename.Str;

        $gnuplot.xlabel( label => 'Tag' );
        $gnuplot.ylabel( label => 'Posts' );
        $gnuplot.title( text => "{ $!year } Most Frequent Tags" );
        $gnuplot.xtics( tics => @tics, :right, :rotate( 60 ) );
        $gnuplot.yrange( min => 0, max => self.tags.map( { .value } ).max );
        $gnuplot.plot:
        vertices => @data,
        using => [2],
        style => 'histogram',
        title => '',
        fill => "solid 1.0",
        linecolor => 'rgb "#%s"'.sprintf: $!graph-color
        ;

        $gnuplot.dispose;
    }


    method !generate-months-graph(){

        use Chart::Gnuplot;
        use Chart::Gnuplot::Subset;


        # build an array of arrays, each line is a data
        my @data;
        # WARNING: need to iterate on all the months or 0-months will
        # make gnuplot complain!
        for 1..12 -> $month {
            my $key = sprintf '%02d', $month;
            my $count = %!posts-count{ $key } // 0;
            @data.push: [ '%04d-%02d'.sprintf( $!year, $key ), $count ];
        }

        my AnyTicsTic @tics = %( label => 'January', pos => 0 ),
        %( label => 'February', pos => 1 ),
        %( label => 'March', pos => 2 ),
        %( label => 'April', pos => 3 ),
        %( label => 'May', pos => 4 ),
        %( label => 'June', pos => 5 ),
        %( label => 'July', pos => 6 ),
        %( label => 'August', pos => 7 ),
        %( label => 'September', pos => 8 ),
        %( label => 'October', pos => 9 ),
        %( label => 'November', pos => 10 ),
        %( label => 'December', pos => 11 );



        my $gnuplot = Chart::Gnuplot.new:
        terminal => 'png',
        filename => $!graph-months-filename.Str;

        $gnuplot.xlabel( label => 'Month' );
        $gnuplot.ylabel( label => 'Number of Posts' );
        $gnuplot.title( text => "{ $!year } Post Ratio by Month" );
        $gnuplot.xtics( tics => @tics, :right, :rotate( 60 ) );
        $gnuplot.yrange( min => 0, max => %!posts-count.map( { .value // 0 } ).max );
        $gnuplot.plot:
        vertices => @data,
        using => [2],
        style => 'histogram',
        title => '',
        fill => "solid 1.0",
        linecolor => 'rgb "#%s"'.sprintf: $!graph-color
        ;

        $gnuplot.dispose;

    }



    method generate-markdown(){
        self!generate-tags-graph;
        self!generate-months-graph;

        my $markdown = qq:to/_MD_/;
        <a name="{ $!year }" />
        ## { $!year } { self!is-current-year ?? '(work in progress)' !! '' }

        **{ self.count } total posts** have been written on { $!year }.
        There have been *{ self.count-tags } different tags* used, the most
        popular being (sorted by number of posts):
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
        The following is the overall { $!year } post ratio by tag (showing max { $!tag-limit } tags):
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
        return '{%% include %s %%}'.sprintf: $relative-filename;
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
        say colored( qq:to/_DIRS_/, 'bold italic cyan' );
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
        say colored( 'Inspecting the post directory...', 'yellow' ) if $*verbose;

        for $!dir-posts.IO.dir() -> $post-file {
            # skip non file stuff..
            next if ! $post-file.f;
            # skip the file if the year is not good!
            next if $year && ! $post-file.basename.match: / ^ $year /;

            my $post = Post.new( filename => $post-file );

            # store it in the list
            @!posts.push: $post;

            # store the year
            @!years.push( $post.year ) if ! @!years.grep( $post.year );
        }

        fail "No posts found in the blog!" if ! @!posts;
        say colored( "Found { @!posts.elems } posts within years { @!years.sort.join( ', ' ) }", 'green' ) if $*verbose;
    }

    #
    # Provides all the posts in a specified year.
    # If no year is provided, all the posts are returned.
    method get-posts( Int :$year? ) {
        return @!posts if ! $year;
        return () if ! @!years.grep: $year;
        return @!posts.grep( { .year == $year } ) if $year;
    }


    # Generate a section in the markdown
    # to provide a quick link list to jump to a specific
    # year in the report.
    #
    # Returns the markdown command to include
    # the file, such as
    # {% include stats/quick-links.md %}
    method generate-markdown-year-links {
        my $md = qq:to/_MD_/;
        ## Quick jump to the years
        Select one of the following links to quickly jump to the
        corresponding year:
        _MD_

        my Str $years-md;
        my $decade;
        for @!years.sort {
            my $current-decade = ( $_ / 10 ).floor;

            if $decade != $current-decade {
                $years-md ~= "\n- years { $current-decade * 10 } - { $current-decade * 10 + 9 }: ";
                $decade = $current-decade;
            }
            else {
                $years-md ~= ', ';
            }

            $years-md ~= "[{$_}](#$_)";
        }

        # output the file
        my $credits-file = $!dir-stats.IO.add( 'quick-links.md' );
        $credits-file.spurt: [ $md, '<br/>', $years-md ];

        return '{%% include %s %%}'.sprintf: $credits-file.path.split( '/' ).reverse[ 1, 0 ].join( '/' );
    }

    method generate-markdown-credits {
        my $md = qq:to/_MD_/;
        <small>
        The graphs and statistical data have been generated
        by the Raku
        script  { $*PROGRAM.IO.basename } running on $*RAKU via $*VM.
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
    where { $jekyll-home.so && $jekyll-home.IO.d // warn "Specificy the home directory [$jekyll-home]" }


    , Str :$dir-posts?
          where { ! $dir-posts.defined || $dir-posts.IO.d  }
    = $jekyll-home ~ '/_posts'

    , Str :$dir-images?
          = $jekyll-home ~ '/images/stats'

    , Str :$dir-stats?
          = $jekyll-home ~ '/_includes/stats'


    , Str :$year?
          where { ! $year.defined
                  || $year ~~ / \d ** 4 | current | last | previous /
                // warn "Year must be a four digit number or a special keyword current,last, previous" }

    , Bool :$dry-run?
    , Bool :$*verbose?
    , Str :$graph-color?
          where { .uc ~~ / ^ <[0..9A..F]> ** 6 / }
    = 'BB00FF'

    , Int :$tag-limit?
          where { $_ > 0 }
    = 30
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
        my $this-year = DateTime.now.year;
        $single-year = do given $year {
            when Int                         { $year <= $this-year ?? $year !! $this-year }
            when /:i ^ current $ /           { $this-year }
            when /:i ^ [last | previous] $ / { $this-year - 1 }
            default                          { $this-year }
        };

        say colored( "Using year $single-year", 'yellow' ) if $*verbose;
    }

    # display the color used for graphs
    say colored( "Using graph color $graph-color", 'yellow' ) if $*verbose;

    # do the scan of the posts directory
    $blog.scan( :year( $single-year ) );

    # now scan across the years
    my @include-instructions;
    for $blog.years.sort {
        say colored( "\nExtracting data for year $_", 'yellow' ) if $*verbose;

        my @current-posts = $blog.get-posts( :year( $_ ) );

        # skip all the things if there are no post in this year
        next if ! @current-posts;

        my $stat = Stat.new: posts => @current-posts ,
        year => $_,
        blog => $blog,
        tag-limit => $tag-limit,
        graph-color => $graph-color;

        say colored( $stat.Str, 'green' ) if $*verbose;

        # generate the files for this year
        $stat.generate-markdown if ! $dry-run;

        # store the include instructions
        @include-instructions.push: $stat.jekyll-include-string;
    }

    # include also the links for the quick year selection
    # but only if not running in single year mode
    @include-instructions.push: $blog.generate-markdown-year-links if ! $year;

    @include-instructions.unshift: $blog.generate-markdown-credits if ! $dry-run;





    if $year {
        say colored( qq:to/_EXTRA_HELP_/, 'bold red' );

        ===================================================================
        WARNING: please note that you asked to generate only the $year year
        so there could be other years not included in this generation. Make
        sure your statistic data and included files are all in place and
        provide the result you want!
        ===================================================================

        _EXTRA_HELP_
    }

    if $dry-run {
        say colored( qq:to/_EXTRA_HELP_/, 'bold red' );

        ===================================================================
        WARNING: dry-run mode activated, no one file has been modified!
        All the information printed above is useful only to get an estimated
        count of the statistical data, but nothing has been updated!
        ===================================================================

       _EXTRA_HELP_
    }

    say qq:to/_HELP_/;

    All done, please check that your stat file on your blog has
    all the following include directives (without any leading space!):

    { colored( '8<---8<---8<---8<---8<--- BEGIN OF INCLUDE 8<---8<---8<---8<---8<---', 'italic' ) }

    { colored( @include-instructions.reverse.join( "\n" ), 'bold cyan' ) }

    { colored( '--->8--->8--->8--->8--->8  END OF INCLUDE  --->8--->8--->8--->8--->8', 'italic' ) }
    _HELP_

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

    In the case you use the `--dry-run` parameter, the script will act accordingly to
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

   Please note that you cannot specify an year greater than the current one, in such case
   you will generate only the current year.

   It is possible to specify every single directory of your blog via the `--dir-xxx` parameters,
   such as for example:
                   {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog \\
                          --dir-posts=/path/to/blog/_posts         \\
                          --dir-images=/path/to/blog/images/stats  \\
                          --dir-stats=/path/to/blog/_include/stats \\


   You can enable extra verbose output with the `--verbose` command line flag.

   The color of the graphs can be customized with the `--grap-color` option, that accepts an RGB
   string (e.g., '00BB77') that will be used. If none is provided, the default color 'BB00FF' will be used.

   The number of the tags shown in the "Tag Ratio" graph can be customized with the `--tag-limit` option.
   The default value is 30, you can increase or decrease such value but please consider that such value could make the graph labels overlapping. As an example:
                            {$*PROGRAM.IO.basename} --jekyll-home=/path/to/blog --tag-count=20

  EOH
}

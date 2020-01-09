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

# An Year class contains all the informations for the stats
# of a single year, including the per-year and per-month stats.
class Year {

    has %!posts-count; # how many posts are there in every single month
    has %!tags-count;  # how many posts are there for a specific tag
    has Int $!year;

    submethod BUILD( :@posts, :$year ){
        $!year = $year;

        for @posts -> $post {
            # increase the number of the posts for the specified month
            %!posts-count{ $post.month }++;

            # increase the counts of the tags
            for @( $post.tags ) -> $tag {
                %!tags-count{ $tag }++;
            }
        }
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


    method scan() {
        say 'Inspecting the post directory...';
        for $!dir-posts.IO.dir() -> $post-file {
            my $post = Post.new( filename => $post-file );
            @!posts.push: $post;
        }

        say "Found { @!posts.elems } posts";
    }

    method posts-as-hash() {
        my %posts-per-year;

        for @!posts -> $post {
            %posts-per-year{ $post.year }{ $post.month }.push: $post;
        }

        return %posts-per-year;
    }


    method generate-years(){
        my Year @years;
        my %posts-per-year;

        for @!posts -> $post {
            %posts-per-year{ $post.year }.push: $post;
        }

        for %posts-per-year.keys.sort -> $year {
            @years.push: Year.new: posts => @( %posts-per-year{ $year } ), year => $year.Int;
        }

        return @years;
    }
}





sub MAIN(
    Str :$jekyll-home
    where { .IO.d // die "Please specify a home directory [$jekyll-home]" }
)
{
    my Blog $blog = Blog.new( dir-home => $jekyll-home,
                              dir-posts => $jekyll-home ~ '/_posts',
                              dir-stats => $jekyll-home ~ '/stats',
                              dir-images => $jekyll-home ~ '/_include/stats' );

    # show what we have configured so far
    $blog.print-dirs();

    # do the scan of the posts directory
    $blog.scan();

    # do generate all stats data divided by year
    my @years = $blog.generate-years;
    for @years -> $year {
        # provide some output about this year
        say $year.Str;

        # for $year.tags -> $tag {
        #     say "{$tag.key} --- {$tag.value}";
        # }
    }
}



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

# A post class represent the amount
# of information required to generate a post
# statistic data.
class Post
{
    has IO::Path $.filename;
    has Str @.tags;

    has Int $!year;
    has Int $!month;

    # extract all the info
    # required to elaborate the statistics data
    method extract-info(){
        $!year  = $!filename.basename.match( /<rx_post_filename>/ )<rx_post_filename><year>.Int();
        $!month = $!filename.basename.match( /<rx_post_filename>/ )<rx_post_filename><month>.Int();
    }

    method year(){ $!year; }
    method month(){ $!month; }
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
            $post.extract-info();
            say $post.year ~ ' --> ' ~ $post.month;
        }
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
}



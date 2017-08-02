#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::Bin/../lib";
use JSON::Patch::Diff;

use strict;
use warnings;
use JSON;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure ("bundling");

use File::Basename;
my $name = basename($0);

## Handle OPTIONS
my $is_help;
my $is_pretty;
my $is_verbose;
my $is_keep_old;
my $is_use_replace;
my $is_use_move;
my $is_use_depth;

GetOptions(
        'help|h'        => \$is_help,
        'pretty|p'      => \$is_pretty,
        'verbose|v'     => \$is_verbose,
        'keep-old|k'    => \$is_keep_old,
        'use-replace|r' => \$is_use_replace,
        #'use-move|m'    => \$is_use_move,
        'use-depth|d'   => \$is_use_depth
) or die "$name: missing operand after '$name'\n$name: Try '$name --help' for more information.";

if ($is_verbose)
{
    $JSON::Patch::Diff::DEBUG = 1;
}

if ($is_help) 
{
    print "Usage: $name [OPTION]... [-o FILE] FILES\n";
    print "Calculate JSON Patch difference from source to destination JSON FILES.\n\n";
    print "Mandatory arguments to long options are mandatory for short options too.\n";
    print "  -d, --use-depth    performs in depth expansion of operations within arrays\n";
    print "  -k, --keep-old     keep old values in patch (\"old\" key)\n";
    print "  -p, --pretty       display pretty formatted JSON Patch\n";
    print "  -r, --use-replace  have 'replace' operations in resulting patch\n";
    #print "  -m, --use-move     have 'move' operations in resulting patch\n";
    print "  -v, --verbose      display extra text\n";
    print "  -h, --help         dispaly this help and exit\n\n";
    print "Report bugs to: velislav\@telebid-pro.com\n";
    exit;
}

## Handle FILES
my $ARGC = @ARGV;

if ($ARGC == 0) 
{
    print "$name: missing operand after '$name'\n";
    print "$name: Try '$name --help' for more information.\n";
    exit;
}
if ($ARGC == 1) 
{
    print "$name: missing destination file operand.\n";
    exit;
}
elsif ($ARGC > 2) 
{
    print "$name: extra operand '$ARGV[2]'\n";
    exit;
}

my $srcfile = $ARGV[0];
my $dstfile = $ARGV[1];

## TODO: Move the logic below to a method inside JSON::Patch::Diff. New method to handle 
## retrieval of $src and $dst from filenames. GetPatch should work with JSON text, files
## or file names and perl scalars.

## Open source FILE
local $/=undef;
open ( FILE, '<:encoding(UTF-8)', $srcfile) 
    or die "Could not open file $srcfile: $!";
binmode FILE;
my $src_text = <FILE>;
close FILE;

## Open destination FILE
open ( FILE, '<:encoding(UTF-8)', $dstfile) 
    or die "Could not open file $dstfile: $!";
binmode FILE;
my $dst_text = <FILE>;
close FILE;

## Open JSON OO interface and decode FILES
my $json = JSON->new->allow_nonref;
my $src = $json->decode($src_text);
my $dst = $json->decode($dst_text);

## Calculate JSON Patch difference
my $diff;

my $options = {
    "keep_old"    => $is_keep_old,
    "use_replace" => $is_use_replace,
    "use_depth"   => $is_use_depth,
    #"use_move"    => $is_use_move
};

$diff = JSON::Patch::Diff::GetPatch($src, $dst, $options);

## Output
if ($is_verbose) 
{
    print "Source JSON:\n";
    print $json->pretty->encode($src), "\n";

    print "Destination JSON:\n";
    print $json->pretty->encode($dst), "\n";
    
    my $number_of_ops = @{$diff};
    print "JSON Patch diff ($number_of_ops " . ($number_of_ops == 1 ? "operation" : "operations") . "):\n";
}

if ($is_pretty) 
{
    print $json->pretty->encode($diff);
}
else 
{
    print $json->encode($diff);
    print "\n";
}

exit;

__END__

=encoding utf8

=head1 NAME

jsondiff.pl - Calculate JSON Patch difference between two JSON files.

=head1 SYNOPSIS

jsondiff.pl [OPTION]... [-o F<FILE>] F<FILE1> F<FILE2>

=head1 OPTIONS

=over 4

=item B<-k, --keep-old>

Keep old values for 'replace' and 'remove' operations ("old" key).

=item B<-p, --pretty>

Used to pretty print the resulting JSON Pointer.

=item B<-v, --verbose>

Enters verbose mode.

=item B<-h, --help>
 
Displays help text and exits.

=back

=head1 DESCRIPTION

Uses JSON::Patch::Diff to calculate JSON Patch difference between two FILES.

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

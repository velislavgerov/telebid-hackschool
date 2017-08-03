#!/usr/bin/perl -w
use FindBin;
use lib "$FindBin::Bin/../lib";
use JSON::Patch::Diff;

use strict;
use warnings;
use JSON;
use Pod::Usage;
use Getopt::Long qw(GetOptions);

use File::Basename;
my $name = basename($0);

my %opt;

Getopt::Long::Configure ("bundling");
GetOptions(\%opt, 'help|h',
    'pretty|p', 'verbose|v',
    'keep-old|k', 'use-replace|r', 'use-depth|d'
) or pod2usage(2);

if ($opt{verbose})
{
    $JSON::Patch::Diff::DEBUG = 1;
}

if ($opt{help})
{
    pod2usage(0);
}

my $exit_message = "";

if (@ARGV == 0)
{
    $exit_message .= "$name: Missing operand after '$name' ...\n";
    $exit_message .= "$name: Try '$name --help' for more information.";
}
elsif (@ARGV == 1)
{
    $exit_message .= "$name: Missing destination file operand: FILE2.";
}
elsif (@ARGV > 2)
{
    $exit_message .= "$name: Extra operand '$ARGV[2]'";
}

if ($exit_message)
{
    pod2usage({-exitval=>2, -verbose=>0, -message=>$exit_message});
}

my $srcfile = $ARGV[0];
my $dstfile = $ARGV[1];

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
    "keep_old"    => $opt{'keep-old'},
    "use_replace" => $opt{'use-replace'},
    "use_depth"   => $opt{'use-depth'},
    #"use_move"    => $is_use_move
};

$diff = JSON::Patch::Diff::GetPatch($src, $dst, $options);

## Output
if ($opt{verbose}) 
{
    print "Source JSON:\n";
    print $json->pretty->encode($src), "\n";

    print "Destination JSON:\n";
    print $json->pretty->encode($dst), "\n";
    
    my $number_of_ops = @{$diff};
    print "JSON Patch diff ($number_of_ops " . ($number_of_ops == 1 ? "operation" : "operations") . "):\n";
}

if ($opt{pretty}) 
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

jsondiff.pl [OPTION]... F<FILE1> F<FILE2>

=head1 OPTIONS

=over 4

=item B<-d, --use-depth>

In depth expansion for array operations.

=item B<-k, --keep-old>

Keep old values for 'replace' and 'remove' operations ("old" key).

=item B<-p, --pretty>

Makes the resulting JSON Pointer easily readable.

=item B<-r, --recursive>

Uses 'replace' operations for arrays.

=item B<-v, --verbose>

Runs in verbose mode.

=item B<-h, --help>
 
Displays this help text and exits.

=back

Report bugs to: E<lt>velislav@telebid-pro.comE<gt>

=head1 DESCRIPTION

B<jsondiff.pl> will use JSON::Patch::Diff to calculate JSON Patch difference between two FILES.

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

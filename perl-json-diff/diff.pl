<<<<<<< HEAD
#! /usr/bin/perl -wT
=======
#!/usr/bin/perl -w

>>>>>>> d89e01180fee75694c5f086e7f97be91b5d5cd2e
use lib "lib";
use JSON::Diff;

use strict;
use warnings;
use JSON;
use Getopt::Long qw(GetOptions);

use feature 'say';

## Handle OPTIONS
my $is_help;
my $is_pretty;
my $is_verbose;
my $output;

GetOptions(
        'help|h' => \$is_help,
        'pretty|p' => \$is_pretty,
        'verbose|v' => \$is_verbose,
        'output|o=s' => \$output
) or die "$0: missing operand after '$0'\n$0: Try '$0 --help' for more information.";

if ($is_help) {
    print "Usage: $0 [OPTION]... [-o FILE] FILES\n";
    print "Calculate JSON Patch difference from source to destination JSON FILES.\n\n";
    print "Mandatory arguments to long options are mandatory for short options too.\n";
    print "  -o, --output=FILE  save output to FILE\n";
    print "  -p, --pretty       display pretty formatted JSON Patch\n";
    print "  -v, --verbose      display extra text\n";
    print "  -h, --help         dispaly this help and exit\n\n";
    print "Report bugs to: velislav\@telebid-pro.com\n";
    exit;
}

## Handle FILES
my $ARGC = @ARGV;

if ($ARGC == 0) {
    print "$0: missing operand after '$0'\n";
    print "$0: Try '$0 --help' for more information.\n";
    exit;
}
if ($ARGC == 1) {
    print "$0: missing destination file operand.\n";
    exit;
}
elsif ($ARGC > 2) {
    print "$0: extra operand '$ARGV[2]'\n";
    exit;
}

if ($is_verbose) {
    $DEBUG = 1;
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
my $diff = diff($src, $dst);

## Output
if ($DEBUG) {
    say "From JSON:";
    print $json->pretty->encode($src);

    say "\nTo JSON:";
    print $json->pretty->encode($dst);
    
    my $number_of_ops = @{$diff};
    say "\nResulting diff ($number_of_ops " . ($number_of_ops == 1 ? "operation" : "operations") . "):";
}

if ($is_pretty) {
    print $json->pretty->encode($diff);
}
else {
    print $json->encode($diff);
    print "\n";
}

## Save JSON Pointer
if ($output) {
    if ($DEBUG) { 
        print "Saving JSON Pointer to: $output.\n"; 
    }
    open ( FILE, '>:encoding(UTF-8)', $output) 
        or die "Could not open file $output $!";
    print FILE to_json($diff, {"utf8"=>1});
    close FILE;
}

exit;

__END__

=encoding utf8

=head1 NAME

diff.pl - perl script utilizing JSON::Diff

=head1 SYNOPSIS

diff.pl [OPTION]... [-o FILE] FILES

=head1 OPTIONS

=over 4

=item B<-o, --output=FILE>

Used to specify the output FILE for the resulting JSON Patch.


=item B<-p, --pretty>

Used to pretty print the resulting JSON Pointer.

=item B<-v, --verbose>

Enters verbose mode.

=item B<-h, --help>
 
Displays help text and exits.

=back

=head1 DESCRIPTION

Using JSON::Diff to calculate JSON Patch difference between two FILES.

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

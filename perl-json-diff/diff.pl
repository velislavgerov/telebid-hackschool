# ---------------------------------------------------------------------------- #
# -------------------------------     DIFF    -------------------------------- #
# ---------------------------------------------------------------------------- #

use lib "lib";
use JSON::Diff;

use strict;
use warnings;

use feature 'say';

## set JSON OO interface
my $json = JSON->new->allow_nonref;

## input filenames
my $ARGC = @ARGV;

if ($ARGC == 0) {
    say "$0: missing operand after '$0'";
    say "$0: Try '$0 --help' for more information.";
    exit;
}
elsif ($ARGC == 1) {
    if ($ARGV[0] eq "--help" || $ARGV[0] eq "-h") {
        say "Usage: $0 SOURCE DEST";
        say "Calculates JSON Patch from SOURCE and DEST files.";
        say "";
        say "Options:";
        say "  -h, --help   dispaly this help and exit";
        say "";
        exit;
    }
    else {
        say "$0: missing destination file operand.";
        exit;
    }
}
elsif ($ARGC > 2) {
    say "$0: extra operand $ARGV[2]";
    exit;
}

my $srcfile = $ARGV[0];
my $dstfile = $ARGV[1];

## open src file and read text
local $/=undef;

open ( FILE, '<:encoding(UTF-8)', $srcfile) 
    or die "Could not open file $srcfile: $!";
binmode FILE;
my $src_text = <FILE>;
close FILE;

## open dst file and read text
open ( FILE, '<:encoding(UTF-8)', $dstfile) 
    or die "Could not open file $dstfile: $!";
binmode FILE;
my $dst_text = <FILE>;
close FILE;

## decode both files
my $src = $json->decode($src_text); # json scalar
my $dst = $json->decode($dst_text); # json scalar


## source json texts
say "From JSON:";
print $json->pretty->encode($src);

say "\nTo JSON:";
print $json->pretty->encode($dst);

## optinally set DEBUG
#$DEBUG = 1;
my $diff = json_diff($src, $dst);

## output
my $number = @{$diff};
say "\nResulting diff ($number operations):";
print $json->pretty->encode($diff);

exit;

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

## FILENAMES

my $srcfile = 'json-files/s.json';
my $dstfile = 'json-files/d.json';

## open src file and read text
local $/=undef;

open ( FILE, '<:encoding(UTF-8)', $srcfile) 
    or die "Could not open file $srcfile $!";
binmode FILE;
my $src_text = <FILE>;
close FILE;

## open dst file and read text
open ( FILE, '<:encoding(UTF-8)', $dstfile) 
    or die "Could not open file $dstfile $!";
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
my $diff = JSON::Diff->json_diff($src, $dst);

## output
my $number = @{$diff};
say "\nResulting diff ($number operations):";
print $json->pretty->encode($diff);


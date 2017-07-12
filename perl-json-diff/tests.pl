# ---------------------------------------------------------------------------- #
# -------------------------------   TESTING   -------------------------------- #
# ---------------------------------------------------------------------------- #

use lib "lib";
use JSON::Diff;

use strict;
use warnings;

use Data::Compare;
use feature 'say';

## set JSON OO interface
my $json = JSON->new->allow_nonref;

## set JSON tests filename

my $testsfile = "json-patch-tests/tests.json";

## get tests JSON text
local $/=undef;
open ( FILE, '<:encoding(UTF-8)', $testsfile) 
    or die "Could not open file $testsfile $!";
binmode FILE;
my $tests_text = <FILE>;
close FILE;

## decode tests JSON text
my $tests = $json->decode($tests_text);

## do each test
my $count_ok = 0;
my $count_fail = 0;

foreach my $test (@{$tests}){
    my $src = $json->pretty->encode(@{$test}{doc});
    my $dst = $json->pretty->encode(@{$test}{expected});
    my $patch = $json->pretty->encode(@{$test}{patch});
    my $comment = $json->encode(@{$test}{comment});
    my $diff = JSON::Diff->json_diff($src, $dst);
    my $result_patch = $json->pretty->encode($diff);
    
    #TODO: Use Data::Compare JSON extension
    if (Compare($patch, $result_patch)) {
        print "[ OK ] $comment";
        $count_ok += 1;
    }
    else {
        print "[FAIL] $comment";
        print "Source document:\n";
        print $src;
        print "Destination document:\n";
        print $dst;
        print "Expected patch:\n";
        print $patch;
        print "Got:\n";
        print "$result_patch\n";
        $count_fail += 1;
    }
}

my $total = $count_ok + $count_fail;
print "Total OK    - ${count_ok}\n";
print "Total FAIL  - ${count_fail}\n";
print "Total tests - ${total}\n";


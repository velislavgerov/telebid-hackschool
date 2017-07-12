use lib "lib";
use JSON::Diff;

use strict;
use warnings;

use Data::Compare;
use feature 'say';

# ---------------------------------------------------------------------------- #
# -------------------------------   TESTING   -------------------------------- #
# ---------------------------------------------------------------------------- #

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
foreach my $test (@{$tests}){ 
    my $src = $json->encode(@{$test}{doc});
    my $dst = $json->encode(@{$test}{expected});
    my $patch = $json->pretty->encode(@{$test}{patch});
    my $comment = $json->encode(@{$test}{comment});
    my $diff = JSON::Diff->json_diff($src, $dst);
    my $result_patch = $json->pretty->encode($diff);
    
    #TODO: Use Data::Compare JSON extension
    if (Compare($patch, $result_patch)) {
        say "[ OK ]   $comment\n";
    }
    else {
        print "[FAIL] $comment";
        print "Expected:\n";
        print $patch;
        print "Got:\n";
        print $result_patch;
    }
}

# ---------------------------------------------------------------------------- #
# -------------------------------   TESTING   -------------------------------- #
# ---------------------------------------------------------------------------- #

use lib "lib";
use lib "perl-json-patch/lib";

use JSON::Diff;
use JSON::Patch;

use strict;
use warnings;

use Data::Compare;
use feature 'say';

#$DEBUG = 1;

## set JSON OO interface
my $json = JSON->new->allow_nonref;
my $json_patch = new JSON::Patch;


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

my $out_json = [];

foreach my $test (@{$tests}){
    if (exists ${$test}{disabled}) { 
        if ($DEBUG) {
            print "(disabled) skipping...\n";
        }
        next; 
    }
    elsif (exists ${$test}{error}) {
        if ($DEBUG) {
            print "(error) skipping...\n";
        }
        next; 
    }
    elsif (! exists ${$test}{expected}) {
        if ($DEBUG) {
            print "(no expected) skipping...\n";
        }
        next; 
    }
    
    my $src = @{$test}{doc};
    my $dst = @{$test}{expected};
    my $src_text = $json->pretty->encode($src);
    my $dst_text = $json->pretty->encode($dst);
    my $patch = @{$test}{patch};
    my $patch_text = $json->pretty->encode($patch);
    my $comment_text = $json->encode(@{$test}{comment});
    my $diff = JSON::Diff->json_diff($src, $dst);
    my $result_patch = $json->pretty->encode($diff);
    
    push @{$out_json}, {"doc" => $src, "exp" => $dst, "patch" => $diff};

    #TODO: Use Data::Compare JSON extension
    if (Compare($patch, $diff)) {
        print "[ OK ] $comment_text";
        $count_ok += 1;
    }
    else {
        print "[FAIL] $comment_text";
        if (1) {
                print "Source document:\n";
                print $src_text;
                print "Destination document:\n";
                print $dst_text;
                print "Expected patch:\n";
                print $patch_text;
                print "Got:\n";
                print "$result_patch\n";
        }
        #foreach (@{$diff}){
        #    $json_patch->load_operators(%{$_});
        #}

        $DEBUG = 1;
        my $diff = JSON::Diff->json_diff($src, $dst);
        $DEBUG = 0;
        $count_fail += 1;
    }
}

## RESULTS

my $total = $count_ok + $count_fail;
print "----------------\n";
print "Total OK    - ${count_ok}\n";
print "Total FAIL  - ${count_fail}\n";
print "Total tests - ${total}\n";

if ($total > 0 && $count_fail > 0) {
    print "---- FAILED ----\n";
}
else {
    print "----   OK   ----\n";
}

my $outfile = 'out.json';
open ( FILE, '>:encoding(UTF-8)', $outfile) 
    or die "Could not open file $outfile $!";
print FILE $json->pretty->encode($out_json);
close FILE;


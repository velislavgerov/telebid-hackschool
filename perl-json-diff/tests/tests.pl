#!/usr/bin/perl -w
# ---------------------------------------------------------------------------- #
# -------------------------------   TESTING   -------------------------------- #
# ---------------------------------------------------------------------------- #
use FindBin;
use lib "$FindBin::Bin/../lib";
use JSON::Patch::Diff;

use strict;
use warnings;

use JSON;
use Data::Compare;
use Data::Dumper;
use feature 'say';

## set JSON OO interface
my $json = JSON->new->allow_nonref;

## set JSON tests in filenames and out filenames

my $test_file1 = "$FindBin::Bin/json-patch-tests/tests.json";
my $test_file2 = "$FindBin::Bin/json-patch-tests/spec_tests.json";
my $out_test_file1 = "$FindBin::Bin/files/tests_out.json";
my $out_test_file2 = "$FindBin::Bin/files/spec_tests_out.json";

## get tests JSON text
local $/=undef;
open ( FILE, '<:encoding(UTF-8)', $test_file1 ) 
    or die "Could not open file $test_file1 $!";
binmode FILE;
my $test_file_text1 = <FILE>;
close FILE;

open ( FILE, '<:encoding(UTF-8)', $test_file2) 
    or die "Could not open file $test_file2 $!";
binmode FILE;
my $test_file_text2 = <FILE>;
close FILE;

## decode tests JSON text
my @test_files;

push @test_files, {
        "file" => $test_file1,
        "out"  => $out_test_file1,
        "text" => $json->decode($test_file_text1)
};
push @test_files, {
        "file"=>$test_file2,
        "out"=>$out_test_file2,
        "text"=>$json->decode($test_file_text2)
};

foreach my $test_file (@test_files) {
        say "Test file: ${$test_file}{file}";
        ## do each test
        my $count_ok = 0;
        my $count_fail = 0;

        my $out_json = [];

        foreach my $test (@{${$test_file}{text}}){
            if (exists ${$test}{disabled}) { 
                if ($JSON::Patch::Diff::DEBUG) {
                    print "(disabled) skipping...\n";
                }
                next; 
            }
            elsif (exists ${$test}{error}) {
                if ($JSON::Patch::Diff::DEBUG) {
                    print "(error) skipping...\n";
                }
                next; 
            }
            elsif (! exists ${$test}{expected}) {
                if ($JSON::Patch::Diff::DEBUG) {
                    print "(no expected) skipping...\n";
                }
                next; 
            }
            
            my $src = ${$test}{doc};
            my $dst = ${$test}{expected};
            my $src_text = $json->pretty->encode($src);
            my $dst_text = $json->pretty->encode($dst);
            my $patch = @{$test}{patch};
            my $patch_text = $json->pretty->encode($patch);
            my $comment_text = $json->encode(@{$test}{comment});
            my $diff = JSON::Patch::Diff::GetPatch($src, $dst, {'keep_old'=>0, 'use_replace'=>1, 'use_depth'=>1});
            my $result_patch = $json->pretty->encode($diff);

            # I am calling $json->decode below to avoid a strange bug, where numbers
            # got encoded as JSON strings
            push @{$out_json}, {"comment" => $comment_text, 
                                "src" => $json->decode($src_text),
                                "dst" => $json->decode($dst_text),
                                "patch" => $diff}; 

            #TODO: Use Data::Compare JSON extension
            if (Compare($patch, $diff)) {
                print "[ OK ] $comment_text";
                $count_ok += 1;
            }
            else {
                print "[FAIL] $comment_text";
                
                #print "Source document:\n";
                #print $src_text;
                #print "Destination document:\n";
                #print $dst_text;
                print "Expected patch:\n";
                print $patch_text;
                print "Got:\n";
                print "$result_patch\n";

                #$JSON::Patch::Diff::DEBUG = 1;
                #my $diff = JSON::Patch::Diff->json_diff($src, $dst);
                #$JSON::Patch::Diff::DEBUG = 0;
                $count_fail += 1;
            }
        }

        ## RESULTS
        say "Results for: ${$test_file}{file}";
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
        my $out_file = ${$test_file}{out};
        say "Saving results to: $out_file\n";
        open ( FILE, '>:encoding(UTF-8)', $out_file) 
            or die "Could not open file $out_file $!";
        print FILE to_json($out_json, {"utf8"=>1, "pretty"=>1});
        close FILE;
}

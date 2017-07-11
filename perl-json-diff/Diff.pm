# ---------------------------------------------------------------------------- #
# JSON::Diff - JSON Patch (RFC6902) difference of two JSON files ------------- #
# Author: Velislav Gerov <vgerov93@gmail.com> -------------------------------- #
# Copyright 2017 Velislav Gerov <vgerov93@gmail.com> ------------------------- #
# ---------------------------------------------------------------------------- #

package JSON::Diff;

use strict;
use warnings;

use JSON;
use Data::Compare;
use Scalar::Util qw(looks_like_number);
use feature 'say';

# GLOBALS
my $DEBUG = 1;

sub compare_values($$$$) {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts = @{$parts};
    my @diff = @{$diff};
    if ($DEBUG) {
        say "Compare values";
        say "parts: $parts";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }

    if (Compare($src, $dst)) {
        if ($DEBUG) { say "$src is equal to $dst"; }
        return
    }

    my $ref = \$src;
    if (ref ($$ref) eq 'HASH') {  
        compare_hashes(\@parts, $src, $dst, \@{$diff});
    }
    elsif (ref ($$ref) eq 'ARRAY') {
        compare_arrays(\@parts, $src, $dst, \@{$diff});
    }
    else {
        # value is scalar
        my $ptr = ptr_from_parts(\@parts);
        # check if string has missing quotes
        if (substr($dst, 0, 1) ne '"' && ! substr($dst, -1) ne '"') {
            if (! looks_like_number($dst)) { $dst = '"' . $dst . '"'; }
        }
        @{$diff} = (@{$diff}, qq|{"op": "replace", "path": "$ptr", "value": $dst}|);
        if ($DEBUG) {say "Diff updated: @{$diff}";}
    }

}

sub compare_arrays($$$$) {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts = @{$parts};
    my @diff = @{$diff};
    
    if ($DEBUG) {
        say "Compare arrays";
        say "parts: $parts";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }
    
    my @src_new = @{$src};

    my $len_dst = @{$dst};
    my $i = 0;
    my $j = 0;
    while ($i < $len_dst)
    {
        #say $i;
        #say @{$dst}[$i];
        
        my $left = @{$dst}[$i];
        my $right = $src_new[$j];
    
        if ($DEBUG) { say "comprating left:$left to right:$right"; }

        if (Compare($left, $right)) {
                if ($i != $j) {
                @parts = (@{$parts}, $i);
                my $ptr = ptr_from_parts(\@parts);
                @{$diff} = (@{$diff}, qq|{"op": "add", "path": "$ptr", "value": @{$dst}{$i}}|);
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. $i], @{$dst}{$i}, @src_new[$i .. $len_src_new]);
                if ($DEBUG) { 
                    say "@{$diff}";
                    say "@src_new"; 
                }
            }
            $i += 1;
            $j = 0;
        }
        else {
            if ($j == $len_dst - 1) {
                @parts = (@{$parts}, $i);
                my $ptr = ptr_from_parts(\@parts);
                @{$diff} = (@{$diff}, qq|{"op": "add", "path": "$ptr", "value": $left}|);
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. $i - 1], $left, @src_new[$i .. $len_src_new-1]);
                if ($DEBUG) { 
                    say "@{$diff}";
                    say "@src_new"; 
                }

                $i += 1;
                $j = 0;
            }
            else {
                $j += 1;
            }
        }
    }
    say "@src_new"; 
    my $len_src_new = @src_new;
    for (my $i=$len_src_new - 1; $i >= $len_dst; $i--) {
        say "this: $i";
        @parts = (@{$parts}, $i);
        my $ptr = ptr_from_parts(\@parts);
        @{$diff} = (@{$diff}, qq|{"op": "remove", "path": "$ptr"}|);
        if ($DEBUG) { say "@{$diff}"; }
    }

    say "ARRAY";

}

sub compare_hashes($$$$) {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts = @{$parts};
    my @diff = @{$diff};
    
    if ($DEBUG) {
        say "Compare hashes";
        say "parts: $parts";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }


    foreach my $key (keys %{$src}) {
        if ($DEBUG) { say "Key: $key"; }
        # remove src key if not in dst
        if (! exists $$dst{$key}) {
            @parts = (@{$parts}, $key);
            my $ptr = ptr_from_parts(\@parts);
            @{$diff} = (@{$diff}, qq|{"op": "remove", "path": "$ptr"}|);
            if ($DEBUG) {say "Diff updated: @{$diff}";}
            next
        }
        # else go deeper
        if ($DEBUG) { say 'GOING DEEPER'; }
        @parts = (@{$parts}, $key);
        compare_values(\@parts, $$src{$key}, $$dst{$key}, \@{$diff});
        if ($DEBUG) { say 'EXIT DEEPER'; }
    }
    
    if ($DEBUG) { say 'FOR KEY IN DST'; }
    foreach my $key (keys %{$dst}) {
        if (! exists $$src{$key}) {
            @parts = (@{$parts}, $key);
            my $ptr = ptr_from_parts(\@parts);
            my $value = JSON->new->allow_nonref->encode(${$dst}{$key});
            @{$diff} = (@{$diff}, qq|{"op": "add", "path": "$ptr", "value": $value}|);
            if ($DEBUG) {say "Diff updated: @{$diff}";}
        }
    }
}

sub ptr_from_parts($) {
    # Returns JSON Pointer string
    # Input
    #  :parts - reference to array specifying JSON path elements
    
    my @parts = @{$_[0]};
    my $ptr;
    
    if (!@parts) {
        return '';        # path to whole document
    }

    foreach (@parts){
        $_ =~ s/~/~0/g;   # replace ~ with ~0
        $_ =~ s/\//~1/g;  # replace / with ~1
        $ptr .= '/' . $_; # parts prefixed by /
    }

    return $ptr;
}

sub json_diff($$;$) {
    my ( $src_json, $dst_json, $options ) = @_;
    my $diff = [];
    my $parts = [];
    # $src_json е HASH или STRING
    # $dst_json е HASH или STRING
    # $options е HASH или UNDEF, да се игнорира към момента
    #   ... тук се случва магията
    
    compare_values($parts, $src_json, $dst_json, $diff);
    
    return $diff;
}



# ---------------------------------------------------------------------------- #
# -------------------------------   TESTING   -------------------------------- #
# ---------------------------------------------------------------------------- #

# JSON OO interface
my $json = JSON->new->allow_nonref;

# FILENAMES

my $srcfile = 'src.json';
my $dstfile = 'dst.json';

# open src file and read text
local $/=undef;

open ( FILE, '<:encoding(UTF-8)', $srcfile) 
    or die "Could not open file $srcfile $!";
binmode FILE;
my $src_text = <FILE>;
close FILE;

# open dst file and read text
open ( FILE, '<:encoding(UTF-8)', $dstfile) 
    or die "Could not open file $dstfile $!";
binmode FILE;
my $dst_text = <FILE>;
close FILE;

# decode both files
my $src = $json->decode($src_text); # json scalar
my $dst = $json->decode($dst_text); # json scalar

$DEBUG = 0;

# source json texts
say "From JSON:";
print $json->pretty->encode($src);

say "\nTo JSON:";
print $json->pretty->encode($dst);

# calculate diff array
my $diff = json_diff($src, $dst);

# output
my $number = @{$diff};
say "\nResulting diff ($number operations):";
say "[";
foreach (@{$diff}) {
    print "  ", $_;
    if (! Compare($_, @{$diff}[-1])) {
        say ",";
    }
    else {
        say "";
    }
}
say "]"

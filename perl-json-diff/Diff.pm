#!/usr/bin/env perl
package JSON::Diff;

use strict;
use warnings;

use JSON;
use feature 'say';


# JSON OO interface
my $json = JSON->new->allow_nonref;
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

    my $ref = \$src;
    if (ref ($$ref) eq 'HASH') { 
        compare_hashes(\@parts, $src, $dst, \@{$diff});
    }
    elsif (ref ($$ref) eq 'ARRAY') {
        say('ARRAY');
    }
    else {
        # value is scalar
        # XXX: what can go wrong?
        my $src_str = "$src"; 
        my $dst_str = "$dst";
        if ($src_str eq $dst_str) {
            if ($DEBUG) { say "$src is equal to $dst"; }
            return
        }
        # not equal scalars
        else {
            my $ptr = ptr_from_parts(\@parts);
            @{$diff} = (@{$diff}, qq|{"op": "replace", "path": $ptr, "value": $dst}|);
            if ($DEBUG) {say "Diff updated: @{$diff}";}
        }
    }

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
            @{$diff} = (@{$diff}, qq|{"op": "remove", "path": $ptr}|);
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
            @{$diff} = (@{$diff}, qq|{"op": "add", "path": $ptr, "value": $value}|);
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
#
# open src file and read text
local $/=undef;

open ( FILE, '<:encoding(UTF-8)', 'src.json') 
    or die "Could not open file 'src.json' $!";
binmode FILE;
my $src_text = <FILE>;
close FILE;

# open dst file and read text
open ( FILE, '<:encoding(UTF-8)', 'dst.json') 
    or die "Could not open file 'dst.json' $!";
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
foreach (@{$diff}) {
    say $_;
}

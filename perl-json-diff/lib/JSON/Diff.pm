# ---------------------------------------------------------------------------- #
# JSON::Diff - JSON Patch (RFC6902) difference of two JSON files ------------- #
# Author: Velislav Gerov <vgerov93@gmail.com> -------------------------------- #
# Copyright 2017 Velislav Gerov <vgerov93@gmail.com> ------------------------- #
# ---------------------------------------------------------------------------- #

package JSON::Diff;

use strict;
use warnings;

use JSON;
use Test::Deep::NoTest;

use Scalar::Util qw(looks_like_number);
use feature 'say';
use parent 'Exporter';

our $DEBUG = 0;
our @EXPORT = qw($DEBUG);

sub compare_values {
    my ($parts, $src, $dst, $diff) = @_;
    if ($DEBUG) {
        say "Compare values";
        say "parts: $parts";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }
    
    # TODO: implement a smarter compare method. Consider the case of 1 and "1"
    if (eq_deeply($src, $dst)) {
        if ($DEBUG) { say "$src is equal to $dst"; }
        return
        #if (isnum($src) == isnum($dst)) {
        #    # values are equal only if they are are from the same type
        #    return
        #}
    }

    if (ref ($src) eq 'HASH' && ref($dst) eq 'HASH') {
        compare_hashes($parts, $src, $dst, $diff);
    }
    elsif (ref ($src) eq 'ARRAY' && ref ($dst) eq 'ARRAY') {
        compare_arrays($parts, $src, $dst, $diff);
    }
    else { # SCALAR
        my $ptr = ptr_from_parts($parts);
        # Check if the string has missing quotes. Consider 127.0.0.1
        #if (substr($dst, 0, 1) ne '"' && ! substr($dst, -1) ne '"') {
        #    if (! looks_like_number($dst)) { $dst = '"' . $dst . '"'; }
        #}
        push @{$diff}, {"op"=>"replace", "path"=>$ptr, "value"=>$dst}; 
        if ($DEBUG) {say "Diff updated: @{$diff}";}
    }
}

sub compare_arrays {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts;

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
        my $left = @{$dst}[$i];
        my $right = $src_new[$j];
    
        if ($DEBUG) { say "comprating dst:$left to src:$right"; }

        if (eq_deeply($left, $right)) {
                if ($i != $j) {
                @parts = (@{$parts}, $i);
                my $ptr = ptr_from_parts(\@parts);
                push @{$diff}, {"op" => "add", "path" => $ptr, "value" => @{$dst}[$i]};
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. $i - 1], @{$dst}[$i], @src_new[$i .. $len_src_new - 1]);
                if ($DEBUG) { 
                    say "@{$diff}";
                    say "@src_new"; 
                }
            }
            $i += 1;
            $j = $i;
        }
        else {
            if ($j == $len_dst - 1) {
                @parts = (@{$parts}, $i);
                my $ptr = ptr_from_parts(\@parts);
                push @{$diff}, {"op" => "add", "path" => $ptr, "value" => $left};
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
    
    my $len_src_new = @src_new;
    for (my $i=$len_src_new - 1; $i >= $len_dst; $i--) {
            #say "this: $i";
        @parts = (@{$parts}, $i);
        my $ptr = ptr_from_parts(\@parts);
        push @{$diff}, {"op" => "remove", "path" => $ptr};
        if ($DEBUG) { say "@{$diff}"; }
    }
}

sub compare_hashes {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts;

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
            push @{$diff}, {"op" => "remove", "path" => $ptr};
            if ($DEBUG) {say "Diff updated: @{$diff}";}
            next
        }
        # else go deeper
        if ($DEBUG) { say "GOING DEEPER $key"; }
        @parts = (@{$parts}, $key);
        compare_values(\@parts, $$src{$key}, $$dst{$key}, $diff);
        if ($DEBUG) { say "EXIT DEEPER $key"; }
    }
    
    if ($DEBUG) { say 'FOR KEY IN DST'; }
    foreach my $key (keys %{$dst}) {
        if (! exists $$src{$key}) {
            @parts = (@{$parts}, $key);
            my $ptr = ptr_from_parts(\@parts);
            my $value = ${$dst}{$key};
            push @{$diff}, {"op" => "add", "path" => $ptr, "value" => $value};
            if ($DEBUG) {say "Diff updated: @{$diff}";}
        }
    }
}

sub ptr_from_parts {
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

sub isnum ($) {
    return 0 if $_[0] eq '';
    $_[0] ^ $_[0] ? 0 : 1
}

sub json_diff {
    # XXX: needs more elaborate input checking
    my ($class, $src_json, $dst_json, $options);
    if ($_[0] eq 'JSON::Diff'){
        ($class, $src_json, $dst_json, $options ) = @_;
    }
    else {
        ($src_json, $dst_json, $options ) = @_;
    }
    
    my $diff = [];
    my $parts = [];

    # $src_json е HASH или STRING
    # $dst_json е HASH или STRING
    # $options е HASH или UNDEF, да се игнорира към момента
    #   ... тук се случва магията
    
    compare_values($parts, $src_json, $dst_json, $diff);
    
    return $diff;
}

1;

# ---------------------------------------------------------------------------- #
# JSON::Diff - JSON Patch (RFC6902) difference of two JSON files ------------- #
# Author: Velislav Gerov <velislav@telebid-pro.com> -------------------------- #
# Copyright 2017 Velislav Gerov <velislav@telebid-pro.com> ------------------- #
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
our @EXPORT = qw($DEBUG diff); 

my $JSON = JSON->new->allow_nonref;

sub compareValues {
    my ($path, $src, $dst, $diff) = @_;
    if ($DEBUG) {
        say "Compare values";
        say "path: $path";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }
   
    $JSON = $JSON->canonical([1]);
    my $src_text = $JSON->encode($src);
    my $dst_text = $JSON->encode($dst);
    
    if (eq_deeply($src_text, $dst_text)) {     
        # return only if the case is not like "1" == 1
        if (isNum($src) == isNum($dst)) {
            return;
        }
    }
        
    if (ref ($src) eq 'HASH' && ref($dst) eq 'HASH') {
        compareHashes($path, $src, $dst, $diff);
    }
    elsif (ref ($src) eq 'ARRAY' && ref ($dst) eq 'ARRAY') {
        compareArrays($path, $src, $dst, $diff);
    }
    else { 
        my $ptr = getJsonPtr($path);
        push @{$diff}, {"op"=>"replace", "path"=>$ptr, "value"=>$dst}; 
        if ($DEBUG) {say "Diff updated: @{$diff}";}
    }
}

sub compareArrays {
    my ($path, $src, $dst, $diff) = @_;
    my @path;

    if ($DEBUG) {
        say "Compare arrays";
        say "path: $path";
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
                @path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@path);
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
                @path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@path);
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
        @path = (@{$path}, $i);
        my $ptr = getJsonPtr(\@path);
        push @{$diff}, {"op" => "remove", "path" => $ptr};
        if ($DEBUG) { say "@{$diff}"; }
    }
}

sub compareHashes {
    my ($path, $src, $dst, $diff) = @_;
    my @path;

    if ($DEBUG) {
        say "Compare hashes";
        say "path: $path";
        say "diff: $diff";
        say "src: $src";
        say "dst: $dst";
    }

    foreach my $key (keys %{$src}) {
        if ($DEBUG) { say "Key: $key"; }
        # remove src key if not in dst
        if (! exists $$dst{$key}) {
            @path = (@{$path}, $key);
            my $ptr = getJsonPtr(\@path);
            push @{$diff}, {"op" => "remove", "path" => $ptr};
            if ($DEBUG) {say "Diff updated: @{$diff}";}
            next
        }
        # else go deeper
        if ($DEBUG) { say "GOING DEEPER $key"; }
        @path = (@{$path}, $key);
        compareValues(\@path, $$src{$key}, $$dst{$key}, $diff);
        if ($DEBUG) { say "EXIT DEEPER $key"; }
    }
    
    if ($DEBUG) { say 'FOR KEY IN DST'; }
    foreach my $key (keys %{$dst}) {
        if (! exists $$src{$key}) {
            @path = (@{$path}, $key);
            my $ptr = getJsonPtr(\@path);
            my $value = ${$dst}{$key};
            push @{$diff}, {"op" => "add", "path" => $ptr, "value" => $value};
            if ($DEBUG) {say "Diff updated: @{$diff}";}
        }
    }
}

sub getJsonPtr {
    # Returns JSON Pointer string
    # Input
    #  :path - reference to array specifying JSON path elements
    
    my @path = @{$_[0]};
    my $ptr;
    
    if (!@path) {
        return '';        # path to whole document
    }

    foreach (@path){
        $_ =~ s/~/~0/g;   # replace ~ with ~0
        $_ =~ s/\//~1/g;  # replace / with ~1
        $ptr .= '/' . $_; # prefix result with /
    }

    return $ptr;
}

sub isNum ($) {
    return 0 if $_[0] eq '';
    $_[0] ^ $_[0] ? 0 : 1
}

sub diff {
    # XXX: needs more elaborate input checking
    my ($self, $src, $dst, $options);
    if ($_[0] eq 'JSON::Diff'){
        ($self, $src, $dst, $options ) = @_;
    }
    else {
        ($src, $dst, $options ) = @_;
    }

    my $diff = [];
    my $path = [];

    compareValues($path, $src, $dst, $diff);
    
    return $diff;
}

1;

__END__

=encoding utf8

=head1 NAME

JSON::Diff

=head1 DESCRIPTION

A minimalistic module to calculate JSON Patch difference between two FILES.

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

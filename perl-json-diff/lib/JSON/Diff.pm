# ---------------------------------------------------------------------------- #
# JSON::Diff - JSON Patch (RFC6902) difference of two JSON files ------------- #
# Author: Velislav Gerov <velislav@telebid-pro.com> -------------------------- #
# Copyright 2017 Velislav Gerov <velislav@telebid-pro.com> ------------------- #
# ---------------------------------------------------------------------------- #

package JSON::Diff;

use strict;
use warnings;

use JSON;
use Test::Deep::NoTest qw(eq_deeply);
use Scalar::Util qw(looks_like_number);
use feature 'say';
use parent 'Exporter';

our $DEBUG = 0;
our @EXPORT = qw($DEBUG diff); 

my $JSON = JSON->new->allow_nonref;

sub diff($$;$) {
    # XXX: needs more elaborate input checking
    my ($src, $dst, $options ) = @_;
    
    my $diff = [];
    my $path = [];

    compareValues($path, $src, $dst, $diff);
    
    return $diff;
}

sub compareValues {
    my ($path, $src, $dst, $diff) = @_;
    
    Trace(
        "Comparing values",
        "path: $path",
        "diff: $diff",
        "src: $src",
        "dst: $dst"
    );
   
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
        push @{$diff}, {
                "op"=>"replace", 
                "path"=>$ptr,
                "value"=>$dst
        }; 
        Trace("Diff updated: @{$diff}");
    }
}

sub compareArrays {
    my ($path, $src, $dst, $diff) = @_;
    my @path;

    Trace(
        "Comparing arrays",
        "path: $path",
        "diff: $diff",
        "src: $src",
        "dst: $dst"
    );    
    
    my @src_new = @{$src};
    my $len_dst = @{$dst};
    my $i = 0;
    my $j = 0;
    while ($i < $len_dst)
    {   
        my $left = @{$dst}[$i];
        my $right = $src_new[$j];
    
        Trace("comprating dst:$left to src:$right");

        if (eq_deeply($left, $right)) {
            if ($i != $j) {
                @path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@path);
                push @{$diff}, {"op" => "add",
                                "path" => $ptr, 
                                "value" => @{$dst}[$i]
                };
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. $i - 1],
                            @{$dst}[$i],
                            @src_new[$i .. $len_src_new - 1]
                );
                Trace(
                    "@{$diff}",
                    "@src_new" 
                );
            }
            $i += 1;
            $j = $i;
        }
        else {
            if ($j == $len_dst - 1) {
                @path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@path);
                push @{$diff}, {"op" => "add",
                                "path" => $ptr,
                                "value" => $left
                };
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. $i - 1],
                            $left, 
                            @src_new[$i .. $len_src_new-1]
                );
                Trace(
                    "@{$diff}",
                    "@src_new"
                );

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
        @path = (@{$path}, $i);
        my $ptr = getJsonPtr(\@path);
        push @{$diff}, {"op" => "remove", 
                        "path" => $ptr
        };
        
        Trace("@{$diff}");
    }
}

sub compareHashes {
    my ($path, $src, $dst, $diff) = @_;
    my @path;

    Trace(
        "Comparing hashes",
        "path: $path",
        "diff: $diff",
        "src: $src",
        "dst: $dst"
    );

    foreach my $key (keys %{$src}) {
        Trace("Key: $key");
        # remove src key if not in dst
        if (! exists $$dst{$key}) {
            @path = (@{$path}, $key);
            my $ptr = getJsonPtr(\@path);
            push @{$diff}, {"op" => "remove",
                            "path" => $ptr
            };
            Trace("Diff updated: @{$diff}");
            next
        }
        # else go deeper
        Trace("GOING DEEPER $key");
        
        @path = (@{$path}, $key);
        compareValues(\@path, $$src{$key}, $$dst{$key}, $diff);
        
        Trace("EXIT DEEPER $key");
    }
    
    Trace('FOR KEY IN DST');
    foreach my $key (keys %{$dst}) {
        if (! exists $$src{$key}) {
            @path = (@{$path}, $key);
            my $ptr = getJsonPtr(\@path);
            my $value = ${$dst}{$key};
            push @{$diff}, {
                    "op" => "add", 
                    "path" => $ptr, 
                    "value" => $value
            };
            Trace("Diff updated: @{$diff}");
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
    # add comment
    return 0 if $_[0] eq '';
    $_[0] ^ $_[0] ? 0 : 1
}

sub Trace {
    if ($DEBUG) {
        foreach (@_) {
            say $_;
        }
    }
}

1;

__END__

=encoding utf8

=head1 NAME

JSON::Diff

=head1 SYNOPSIS

 use JSON;
 use JSON::Diff;

 my $src_ref = from_json($src_json_text);
 my $dst_ref = from_json($dst_json_text);

 my $diff = diff($src_ref, $dst_ref);
 my $diff_text = to_json($diff);

=head1 DESCRIPTION

A minimalistic module to calculate JSON Patch difference between two perlrefs.

=head1 FUNCTIONAL INTERFACE 

=over 4

=item diff($src, $dst, $options)

 Inputs:   $src:      perlref: decoded JSON object (Source JSON)
           $dst:      perlref: decoded JSON object (Destination JSON)
           $options:  unused
 
 Returns:  perlref:   [ { JSON Patch operation }, ... ]
 
 Throws:   no

Calculates and returns a JSON Patch difference between source and destination JSON objects.

=back

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

#!/usr/bin/env perl
package JSON::Diff;

use strict;
use warnings;

use JSON;
use feature 'say';

# JSON OO interface
my $json = JSON->new->allow_nonref;

sub compare_values($$$$) {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts = @{$parts};
    my @diff = @{$diff};
    
    my $ref = \$src;
    if (ref ($$ref) eq 'HASH') {
        say ('It is a HASH');
    }
    elsif (ref ($$ref) eq 'ARRAY') {
        say('ARRAY');
    }
    else {
        say('SCALAR');
    }

}

sub compare_hashes($$$$) {
    my ($parts, $src, $dst, $diff) = @_;
    my @parts = @{$parts};
    my @diff = @{$diff};

    foreach my $key (keys %{$src}) {
        # remove src key if not in dst
        if (! exists $$dst{$key}) {
            @parts = (@parts, $key);
            my $ptr = ptr_from_parts(\@parts);
            @diff = (@diff, "{'op': 'remove', 'path': $ptr}");
            next
        }
        # else go deeper
        @parts = (@parts, $key);
        compare_values(\@parts, $$src{$key}, $$dst{$key}, \@diff);
    }
    
    foreach my $key (keys %{$dst}) {
        if (! exists $$src{$key}) {
            @parts = (@parts, $key);
            my $ptr = ptr_from_parts(\@parts);
            my $json_text = $json->new->encode($$src{$key});
            @diff = (@diff, "{'op': 'add', 'path': $ptr, 'value: $json_text");
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


my $src = $json->decode($src_text); # json scalar
my $dst = $json->decode($dst_text); # json scalar

#print $json->pretty->encode( $json_scalar );

sub json_diff($$;$) {
    my ( $src_json, $dst_json, $options ) = @_;
    my $diff = [];

    # $src_json е HASH или STRING
    # $dst_json е HASH или STRING
    # $options е HASH или UNDEF, да се игнорира към момента
    #   ... тук се случва магията

    return $diff;
}

#my @array = json_diff($json_scalar, $json_scalar);
#my $size = @array;
#print "${size}\n";
#print "@array[0]\n";

#say $json_scalar;
#foreach my $key (keys %{$$json_scalar{applications}})
#{
#    say $key;
#    say $$json_scalar{applications}{$key}{name};
#    my $my_ref = \$$json_scalar{applications}{$key}{pings}{cart_page}{expected_response_codes};
#    say ref($$my_ref);
#    if (ref ($$my_ref) eq 'HASH')
#    {
#            say ('HASH');
#    }
#    elsif (ref ($$my_ref) eq 'ARRAY')
#    {
#            say('ARRAY');
#    }
#    else
#    {
#            say('SCALAR');
#    }
#}


my @array = qw();
my @diff = [];
compare_hashes(\@array, $src, $dst, \@diff);
compare_values(\@array, $src, $dst, \@diff);


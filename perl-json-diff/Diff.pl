#!/usr/bin/env perl
package JSON::Diff;

use strict;
use warnings;

use JSON;
use feature 'say';

# Open json file and read text
local $/=undef;
my $filename = 'src.json';
open ( FILE, '<:encoding(UTF-8)', $filename) 
    or die "Could not open file '$filename' $!";
binmode FILE;
my $json_text = <FILE>;
close FILE;

# Set JSON OO interface
my $json = JSON->new->allow_nonref;
my $json_scalar = $json->decode( $json_text );

print $json->pretty->encode( $json_scalar );

sub json_diff($$;$) {
    my ( $src_json, $dst_json, $options ) = @_;
    my $diff = [];

    # $src_json е HASH или STRING
    # $dst_json е HASH или STRING
    # $options е HASH или UNDEF, да се игнорира към момента
    #   ... тук се случва магията

    return $diff;
}

my @array = json_diff($json_scalar, $json_scalar);
my $size = @array;
print "${size}\n";
print "@array[0]\n";

say $json_scalar;
foreach my $key (keys %{$$json_scalar{applications}})
{
    say $key;
    say $$json_scalar{applications}{$key}{name};
    my $my_ref = \$$json_scalar{applications}{$key}{pings}{cart_page}{expected_response_codes};
    say ref($$my_ref);
    if (ref ($$my_ref) eq 'HASH')
    {
            say ('HASH');
    }
    elsif (ref ($$my_ref) eq 'ARRAY')
    {
            say('ARRAY');
    }
    else
    {
            say('SCALAR');
    }
}

sub ptr_from_parts($) {
    # Returns JSON Pointer string
    # Input
    #  :parts - array containing JSON path elements
    
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

my @array = qw();
print ptr_from_parts \@array, "\n";

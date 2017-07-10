#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Data::Dumper;

use feature 'say';

# Open json file and read text
local $/=undef;
my $filename = 'input.json';
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

#print $json_scalar{'applications'}{test_ping_icmp}{pings}{16}{packets_rate};

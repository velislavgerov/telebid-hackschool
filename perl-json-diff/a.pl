use strict;
use warnings;
use feature 'say';

sub isnum ($) {
    return 0 if $_[0] eq '';
    $_[0] ^ $_[0] ? 0 : 1
}


my $a = {"a"=>2};
say isnum($a);
say isnum '2';
say isnum '0';


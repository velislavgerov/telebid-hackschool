package JSON::Patch::Humanize;

use strict;
use warnings;

use Data::Dumper;
use JSON;

my $json = JSON->new->allow_nonref;

sub Humanize($);

my $ref = [
    { "op"=> "replace", "path"=> "/baz", "value"=> "boo", "old"=> "asd" },
    { "op"=> "add", "path"=> "/hello", "value"=> ["world"] },
    { "op"=> "remove", "path"=> "/foo", "old"=>"bar"}
];

sub Humanize($)
{
    my ($in_json) = $_[0];

    my $out_json = [];

    foreach my $op (@$in_json)
    {   
        # TODO: Usage should be as follows:
        #   1.Create operation object
        #   2.Retrieve human readable interpretation
        # NOTE: (2.) Might be context dependant
        #
        # Example:
        #   $operation = JSON::Patch::Operation->($op, $ctx)
        #   print $operation->humanized()
        
        my $humanized_op = temp_OpParse($op);

        push @{$out_json}, $humanized_op;

    }
    return $out_json;
}

sub temp_OpParse($)
{
    my ($op) = shift;

    if (lc $$op{op} eq 'add')
    {
       return join('', $json->encode($$op{value}), ' was added to "', $$op{path}, '"');
    }
    elsif (lc $$op{op} eq 'replace')
    {
       return join('', $json->encode($$op{old}), ' at "', $$op{path}, '" was replaced with ', $json->encode($$op{value}));
    }
    elsif (lc $$op{op} eq 'remove')
    {
        return join('', $json->encode($$op{old}), ' was removed from "', $$op{path}, '"');
    }

    return "Unrecognized operation";
}

# ----------------------------------------------------------------- #
#                                 test                              #
# ----------------------------------------------------------------- #

print Dumper Humanize($ref);

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
    { "op"=> "remove", "path"=> "/foo", "old"=>"bar"},
    { "op" => "move", "path"=> "/a", "from"=> "/b", "value"=>2}
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

    if (lc $$op{op} eq 'add' || lc $$op{op} eq 'copy')
    {
       return join('', 'Added value ', $json->encode($$op{value}), ' at ', $$op{path}, '.');
    }
    elsif (lc $$op{op} eq 'replace')
    {
       return join('', 'Changed value from ', $json->encode($$op{old}), ' to ', $json->encode($$op{value}), ' at ', $$op{path}, '.');
    }
    elsif (lc $$op{op} eq 'remove')
    {
        return join('', 'Deleted value ', $json->encode($$op{old}), ' at ', $$op{path}, '.');
    }
    elsif (lc $$op{op} eq 'move')
    {
        return join('', 'Moved value ', $json->encode($$op{value}), ' from ', $$op{from}, ' to ', $$op{path}, '.');
    }

    return "Unrecognized operation";
}

# ----------------------------------------------------------------- #
#                                 test                              #
# ----------------------------------------------------------------- #

print Dumper Humanize($ref);

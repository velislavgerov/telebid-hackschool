package JSON::Diff;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use Test::Deep::NoTest qw(eq_deeply);
use Scalar::Util qw(looks_like_number);

our $DEBUG = 0;

my $json = JSON->new->allow_nonref;

sub GetPatch($$;$)
{
    # XXX: needs more elaboratdde input checking
    my ($src, $dst, $options ) = @_;
    
    my $diff = [];
    my $path = [];
    
    TRACE(
        "JSON::Diff:GetPatch with:\n",
        "SOURCE: ", Dumper($src), "\n",
        "DEST:   ", Dumper($dst), "\n"
    );
        
    CompareValues($path, $src, $dst, $diff);

    return $diff;
}

sub CompareValues($$$$)
{
    my ($path, $src, $dst, $diff) = @_;
    
    TRACE("Comparing VALUES");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);

    $json = $json->canonical([1]);

    my $src_text = $json->encode($src);
    my $dst_text = $json->encode($dst);
    
    if (eq_deeply($src_text, $dst_text)) 
    {   
        # return only if the case is not like "1" == 1
        if (isNum($src) == isNum($dst)) 
        {
            TRACE("SOURCE is equal DEST");
            return;
        }
    }
        
    if (ref($src) eq 'HASH' && ref($dst) eq 'HASH') 
    {
        compareHashes($path, $src, $dst, $diff);
    }
    elsif (ref($src) eq 'ARRAY' && ref($dst) eq 'ARRAY') 
    {
        compareArrays($path, $src, $dst, $diff);
    }
    else 
    {
        my $ptr = getJsonPtr($path);
        push @$diff, {
            "op"    => "replace", 
            "path"  => $ptr,
            "value" => $dst
        };
        TRACE("DIFF updated: ", Dumper($diff));
    }
}

sub compareArrays($$$$)
{
    my ($path, $src, $dst, $diff) = @_;
    my @curr_path;
   
    TRACE("Comparing ARRAYS");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);

    my @src_new = @{$src};
    my $len_dst = @{$dst};
    my $i = 0;
    my $j = 0;
    while ($i < $len_dst)
    {
        my $left = @{$dst}[$i];
        my $right = $src_new[$j];
        if (eq_deeply($left, $right)) 
        {
            if ($i != $j) {
                @curr_path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@curr_path);
                push @{$diff}, {"op" => "add",
                                "path" => $ptr, 
                                "value" => @{$dst}[$i]
                };
                TRACE(
                    "DIFF updated: ",
                    Dumper($diff)
                );

                my $len_src_new = @src_new;
                @src_new = (
                    @src_new[0 .. ($i - 1)],
                    @{$dst}[$i],
                    @src_new[$i .. ($len_src_new - 1)]
                );
            }
            $i += 1;
            $j = $i;
        }
        else {
            if ($j == $len_dst - 1) {
                @curr_path = (@{$path}, $i);
                my $ptr = getJsonPtr(\@curr_path);
                push @{$diff}, {
                    "op" => "add",
                    "path" => $ptr,
                    "value" => $left
                };
                TRACE(
                    "DIFF updated: ",
                    Dumper($diff)
                );
                my $len_src_new = @src_new;
                @src_new = (@src_new[0 .. ($i - 1)],
                            $left, 
                            @src_new[$i .. ($len_src_new-1)]
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
    for (my $i = $len_src_new - 1; $i >= $len_dst; $i--) 
    {
        @curr_path = (@{$path}, $i);
        my $ptr = getJsonPtr(\@curr_path);
        push @{$diff}, {
            "op" => "remove", 
            "path" => $ptr
        }; 
        TRACE(
            "DIFF updated: ",
            Dumper($diff)
        );
    }
}

sub compareHashes($$$$) {
    my ($path, $src, $dst, $diff) = @_;
    my @curr_path;

    TRACE("Comparing HASHES:");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);

    foreach my $key (keys %$src) 
    {
        # remove src key if not in dst
        if (! exists $$dst{$key}) 
        {
            @curr_path = (@$path, $key);
            my $ptr = getJsonPtr(\@curr_path);
            push @$diff, {
                "op" => "remove",
                "path" => $ptr
            };
            TRACE(
                "DIFF updated: ",
                Dumper($diff)
            );
            next;
        }
        # else go deeper
        @curr_path = (@$path, $key);
        CompareValues(\@curr_path, $$src{$key}, $$dst{$key}, $diff);
    }
    
    foreach my $key (keys %{$dst}) 
    {
        if (! exists $$src{$key}) 
        {
            @curr_path = (@{$path}, $key);
            my $ptr = getJsonPtr(\@curr_path);
            my $value = ${$dst}{$key};
            push @{$diff}, {
                    "op" => "add", 
                    "path" => $ptr, 
                    "value" => $value
            };
            TRACE(
                "DIFF updated: ",
                Dumper($diff)
            );
        }
    }
}

sub getJsonPtr($) {
    # Returns JSON Pointer string
    # Input
    #  :path - reference to array specifying JSON path elements
    
    my @curr_path = @{$_[0]};
    my $ptr;
    
    if (!@curr_path) {
        return '';        # path to whole document
    }

    foreach my $point (@curr_path){
        $point =~ s/~/~0/g;   # replace ~ with ~0
        $point =~ s/\//~1/g;  # replace / with ~1
        $ptr .= '/' . $point; # prefix result with /
    }

    return $ptr;
}

sub isNum($) {
    # Input: Perl Scalar
    # Returns: 1 if perl scalar is a number, 0 otherwise
    # Source: PerlMonks
    # Question: How to check if scalar value is numeric or string
    # Answer: XORing a string gives a string of nulls while XORring
    # a number gives zero
    # URL: https://tinyurl.com/ycnltx55
    return 0 if $_[0] eq '';
    return $_[0] ^ $_[0] ? 0 : 1
}

sub TRACE(@) 
{
    if (!$DEBUG) 
    {
        return;
    }
    foreach my $message (@_) 
    {
        if (ref($message)) 
        {
            print Dumper $message;
        }
        else
        {
            print $message;
        }
    }
    print "\n";
}

sub ASSERT($$$;$) 
{ 
    my ($condition, $message, $code, $args) = @_;

    if (!$DEBUG) 
    {
        return;
    }
    if (!$condition) 
    {
        die "JSON::Diff: error: $message; code: $code";
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

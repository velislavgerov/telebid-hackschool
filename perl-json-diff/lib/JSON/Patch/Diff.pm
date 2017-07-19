package JSON::Patch::Diff;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use Test::Deep::NoTest qw(eq_deeply);
use Scalar::Util qw(looks_like_number);

our $DEBUG = 0;

my $json = JSON->new->allow_nonref;

sub HumanReadable($)
{
}

sub GetPatch($$;$)
{
    my ($src, $dst, $options ) = @_;
    # TODO: elaborate input checking

    my $diff = [];
    my $path = [];
    
    TRACE("JSON::Diff:GetPatch with:");
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);
        
    CompareValues($path, $src, $dst, $diff, $options);

    return $diff;
}

sub CompareValues($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    
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
        CompareHashes($path, $src, $dst, $diff, $options);
    }
    elsif (ref($src) eq 'ARRAY' && ref($dst) eq 'ARRAY') 
    {
        CompareArrays($path, $src, $dst, $diff, $options);
    }
    else 
    {
        # get values
        my $ptr = GetJSONPtr($path);
        
        # add operation
        if (defined $options)
        {
             push @$diff, {
                "op"    => "replace", 
                "path"  => $ptr,
                "value" => $dst,
                "old"   => $src
            };
        }
        else
        {
            push @$diff, {
                "op"    => "replace", 
                "path"  => $ptr,
                "value" => $dst
            };
        }
        
        # debug
        TRACE("DIFF updated: ", $diff);
    }
}

sub CompareArrays($$$$)
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
        my $left  = @{$dst}[$i];
        my $right = $src_new[$j];
        if (eq_deeply($left, $right)) 
        {
            if ($i != $j) {
                @curr_path = (@{$path}, $i);
                my $ptr = GetJSONPtr(\@curr_path);
                push @{$diff}, {
                    "op" => "add",
                    "path" => $ptr, 
                    "value" => @{$dst}[$i]
                };

                TRACE("DIFF updated: ",$diff);

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
                my $ptr = GetJSONPtr(\@curr_path);
                push @{$diff}, {
                    "op" => "add",
                    "path" => $ptr,
                    "value" => $left
                };
                TRACE("DIFF updated: ", $diff);
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
        my $ptr = GetJSONPtr(\@curr_path);
        push @{$diff}, {
            "op" => "remove", 
            "path" => $ptr
        }; 
        TRACE("DIFF updated: ", $diff);
    }
}
=pod
sub AddOperation
{
    @curr_path = (@{$path}, $i);
    my $ptr = GetJSONPtr(\@curr_path);
    push @{$diff}, {
            "op" => "add",
            "path" => $ptr,
            "value" => $left
    };

    TRACE("DIFF updated: ", $diff);
    
    my $len_src_new = @src_new;
    @src_new = (@src_new[0 .. ($i - 1)],
                $left, 
                @src_new[$i .. ($len_src_new-1)]
    );
}
=cut
sub CompareHashes($$$$;$) {
    my ($path, $src, $dst, $diff, $options) = @_;
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
            my $ptr = GetJSONPtr(\@curr_path);

            # add operation
            if (defined $options)
            {
                push @$diff, {
                    "op"    => "replace", 
                    "path"  => $ptr,
                    "value" => $dst,
                    "old"   => $src
                };
            }
            else
            {
                push @$diff, {
                    "op" => "remove",
                    "path" => $ptr
                };
            }
            
            # debug
            TRACE("DIFF updated: ", $diff);
            
            next;
        }
        # else go deeper
        @curr_path = (@$path, $key);
        CompareValues(\@curr_path, $$src{$key}, $$dst{$key}, $diff, $options);
    }
    
    foreach my $key (keys %{$dst}) 
    {
        if (! exists $$src{$key}) 
        {
            # get values
            @curr_path = (@{$path}, $key);
            my $ptr    = GetJSONPtr(\@curr_path);
            my $value  = ${$dst}{$key};

            # add opeteraion
            push @{$diff}, {
                "op"    => "add", 
                "path"  => $ptr, 
                "value" => $value
            };

            # debug
            TRACE("DIFF updated: ", $diff);
        }
    }
}

sub GetJSONPtr($) 
{
    # Returns JSON Pointer string
    # Input
    #  :path - reference to array specifying JSON path elements
    
    my @curr_path = @{$_[0]};
    my $ptr;
    
    if (!@curr_path) 
    {
        return '';        # path to whole document
    }

    foreach my $point (@curr_path)
    {
        $point =~ s/~/~0/g;   # replace ~ with ~0
        $point =~ s/\//~1/g;  # replace / with ~1
        $ptr .= '/' . $point; # prefix result with /
    }

    return $ptr;
}

sub isNum($) 
{
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

JSON::Patch::Diff

=head1 SYNOPSIS

 use JSON;
 use JSON::Patch::Diff;

 my $src_ref = from_json($src_json_text);
 my $dst_ref = from_json($dst_json_text);

 my $diff = diff($src_ref, $dst_ref);
 my $diff_text = to_json($diff);

=head1 DESCRIPTION

A minimalistic module compare two JSON perlrefs and calculate the resulting JSON Patch L<RFC6902|https://tools.ietf.org/html/rfc6902> difference.

=head1 FUNCTIONAL INTERFACE 

=over 4

=item GetPatch($src, $dst, $options)

 Inputs:   $src:      perlref: decoded JSON object (Source JSON)
           $dst:      perlref: decoded JSON object (Destination JSON)
           $options:  defined: enable saving old values for JSON patch
 
 Returns:  perlref:   [ { JSON Patch operation }, ... ]
 
 Throws:   no

Calculates and returns a JSON Patch difference between source and destination JSON objects.

=back

=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

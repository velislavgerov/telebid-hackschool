package JSON::Patch::Diff;

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
    my ($src, $dst, $options ) = @_;
    # TODO: better input handling

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
        CompareArraysExp($path, $src, $dst, $diff, $options);
    }
    else 
    {
        PushOperation("replace", $path, undef, $dst, $src, $diff, $options); 
    }
}

sub CompareHashes($$$$;$) {
    my ($path, $src, $dst, $diff, $options) = @_;
    my @curr_path;

    TRACE("Comparing HASHES:");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);

    foreach my $key (keys %{$src}) 
    {
        # remove src key if not in dst
        if (! exists $$dst{$key}) 
        {
            @curr_path = (@$path, $key);
            PushOperation("remove", \@curr_path, undef, undef, $src, $diff, $options);

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
            my $value  = ${$dst}{$key};

            PushOperation("add", \@curr_path, undef, $value, undef, $diff, $options);
        }
    }
}

sub CompareArraysSimpl($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    my @curr_path;

    TRACE("Comparing ARRAYS Exp");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);
    
    ## Goes through each element of the DST array and replaces each value from the SRC
    ## array accordingly. When the end of the SRC is reached we add to it's end.
    ## TODO: $dst_i => $i || $dst_idx
    for (my $dst_i = 0; $dst_i < scalar @{$dst}; $dst_i++)
    {
        my $target_value = $${dst}[$dst_i];;
        
        if($dst_i >= scalar @{$src})
        {
            @curr_path = (@{$path}, '-');
            PushOperation("add", \@curr_path, undef, $target_value, undef, $diff, $options);
            last;
        }
        
        my $updated_value = $${src}[$dst_i];
        
        @curr_path = (@{$path}, $dst_i);
        
        CompareValues(\@curr_path, $updated_value, $target_value, $diff);

    }
    
    ## Remove all extra values if the SRC array was longer than our desired DST
    if (scalar @{$src} > scalar @{$dst})
    {
        for (my $i = scalar(@{$src}) - 1; $i >= scalar @{$dst}; $i--)
        {
            my $old_value = $$src[$i];
            @curr_path = (@{$path}, $i);
            PushOperation("remove", \@curr_path, undef, undef, $old_value, $diff, $options);
        }
    }
}


sub CompareArraysExp($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    my @curr_path;

    TRACE("Comparing ARRAYS Exp");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);
    
    my @updated_src = @{$src};

    for (my $dst_i = 0; $dst_i <= scalar @{$dst}; $dst_i++)
    {
        my $target_value = $$dst[$dst_i];
        # XXX: updated or original?
        my $updated_value = $updated_src[$dst_i];
        for (my $src_i = $dst_i; $src_i <= scalar @updated_src; $src_i++)
        {
            TRACE("UPDATED SRC", \@updated_src);
            if ($src_i == scalar @updated_src)
            {
                if (scalar @updated_src >= scalar @{$dst})
                { 
                        if($dst_i == scalar(@{$dst}))
                        {
                            for (my $i = scalar(@updated_src) - 1; $i >= scalar @{$dst}; $i--)
                            {
                                my $old_value = $updated_src[$i];
                                @curr_path = (@{$path}, $i);
                                PushOperation("remove", \@curr_path, undef, undef, $old_value, $diff, $options);
                            }

                        }
                        else
                        {
                            @curr_path = (@{$path}, $dst_i);
                            CompareValues(\@curr_path, $updated_value, $target_value, $diff, $options);
                            #@updated_src[$dst_i] = $target_value; #XXX: Not updated
                        }
                }
                else
                {
                    if ($dst_i == (scalar(@{$dst}) - 1))
                    {
                        for (my $i = scalar(@updated_src); $i <= (scalar(@{$dst}) - 1); $i++)
                        {
                            $target_value = $$dst[$i];
                            @curr_path = (@{$path}, '-');
                            PushOperation("add", \@curr_path, undef, $target_value, undef, $diff, $options);
                        }
                    }
                    else
                    {
                        @curr_path = (@{$path}, $dst_i);
                        CompareValues(\@curr_path, $updated_value, $target_value, $diff, $options);
                        #@updated_src[$dst_i] = $target_value; #XXX: Not updated
                    }
                }
                last;
            }
            my $curr_value = $updated_src[$src_i];
            if (eq_deeply($curr_value, $target_value) && $src_i != $dst_i)
            {
                @curr_path = (@{$path}, $dst_i);
                my @from_path = (@{$path}, $src_i);
                TRACE("FROM PATH: ", \@from_path);
                TRACE("TV:        ", $target_value);
                TRACE("UP:        ", $updated_value);
                PushOperation("move", \@curr_path, \@from_path, $target_value, $updated_value, $diff, $options);
                @updated_src[$dst_i] = $target_value;
                @updated_src[$src_i] = $updated_value;
                last;
            }
        }
    }
    
}

sub CompareArrays($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
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
                ListOperationAdd($path, $i, $left, $right, \@src_new, $diff, $options);
            }
            $i += 1;
            $j = $i;
        }
        else {
            if ($j == $len_dst - 1) {
                ListOperationAdd($path, $i, $left, $right, \@src_new, $diff, $options);
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
        PushOperation("remove", \@curr_path, undef, undef, undef, $diff, $options); 
    }
}

sub ListOperationAdd($$$$$;$)
{
    my ($path, $i, $value, $old_value, $src_new, $diff, $options) = @_;
    my @curr_path = (@{$path}, $i); 

    PushOperation("add", \@curr_path, undef, $value, $old_value, $diff, $options);

    TRACE("DIFF updated: ", $diff);
    
    my $len_src_new = @{$src_new};
    @{$src_new} = (@{$src_new}[0 .. ($i - 1)],
                $value, 
                @{$src_new}[$i .. ($len_src_new-1)]
    );
}

sub PushOperation($$$$$$;$)
{
    ## Add operation to $diff
    my ($operation_name, $path, $from, $value, $old_value, $diff, $options) = @_;
    
    my $operation;
    my $pointer = GetJSONPointer($path); 
    
    TRACE("PUSH OPERATION");
    TRACE("OP:      ", $operation_name);
    TRACE("POINTER: ", $pointer);
    TRACE("VALUE:   ", $value);
    TRACE("OLD:     ", $old_value);
    TRACE("OPTION:  ", $options);

    if ($operation_name eq 'add' || $operation_name eq 'replace')
    {
        $operation = {
            "op"    => $operation_name,
            "path"  => $pointer,
            "value" => $value
        };
    }
    elsif ($operation_name eq 'remove')
    {
        $operation = {
            "op"    => $operation_name,
            "path"  => $pointer
        };
    }
    elsif ($operation_name eq 'move')
    {
        my $from_pointer = GetJSONPointer($from);
        $operation = {
            "op"    => $operation_name,
            "path"  => $pointer,
            "from"  => $from_pointer
        };
    }
    else 
    {
        die "$0: error: invalid or unsupported operation $operation_name";
    }

    if (defined $options && $operation_name ne 'add' && $operation ne 'move')
    {
        $$operation{old} = $old_value; 
    }

    push @{$diff}, $operation;

    TRACE("DIFF updated: ", $diff);
}

sub GetJSONPointer($) 
{
    # Returns JSON Pointer string
    # Input
    #  :path - reference to array specifying JSON path elements
    
    my @curr_path = @{$_[0]};
    my $pointer;
    
    if (!@curr_path) 
    {
        return '';        # path to whole document
    }

    foreach my $point (@curr_path)
    {
        $point =~ s/~/~0/g;   # replace ~ with ~0
        $point =~ s/\//~1/g;  # replace / with ~1
        $pointer  .= '/' . $point; # prefix result with /
    }

    return $pointer;
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

A minimalistic module to compare two JSON perlrefs and calculate the resulting JSON Patch L<RFC6902|https://tools.ietf.org/html/rfc6902> difference.

=head1 FUNCTIONAL INTERFACE 

=over 4

=item GetPatch($src, $dst, $options)

 Inputs:   $src:            perlref: decoded JSON object (Source JSON)
           $dst:            perlref: decoded JSON object (Destination JSON)
           $options:        defined: enable saving old values for JSON patch
 
 Returns:  perlref:         [ { JSON Patch operation }, ... ]
 
 Throws:   no

Calculates and returns a JSON Patch difference between source and destination JSON objects.

=back

=head1 INTERNAL FUNCTIONS

=over 4

=item PushOperation($operation_name, $path, $value, $old_value, $diff, $options)

 Inputs:   $operation_name  scalar:   either 'add', 'replace' or 'remove'
           $path            arrayref: each element represents a key in the JSON object
           $value:          perlref:  the value to be 'added' or 'replaced'
           $old_value:      perlref:  the old value to be used for 'replace' or 'remove'
           $diff:           arrayref: holds all of the operations
           $options:        defined:  specifies whether to use the old value
 
 Returns:  void
 
 Throws:   if '$operation_name' is invalid or unsupported

Prepareas and pushes a new operation to our '$diff' array.

=item GetJSONPointer($path)

 Inputs:   $path            arrayref: each element represents a key in the JSON object
 
 Returns:  $pointer         scalar:   JSON Pointer string
 
 Throws:   no 

Returns a JSON Pointer string created from $path.


=item CompareValues($path, $src, $dst, $diff, $options)

 Inputs:   $path            arrayref: each element represents a key in the JSON object
           $src:            perlref:  decoded JSON object (Source JSON)
           $dst:            perlref:  decoded JSON object (Destination JSON)
           $diff:           arrayref: holds all of the operations
           $options:        defined:  specifies whether to use the old value
 
 Returns:  void
 
 Throws:   no

Compares $src and $dst perlrefs and chooses the appropriate action depending on their type.

=item CompareHashes($path, $src, $dst, $diff, $options)

 Inputs:   $path            arrayref: each element represents a key in the JSON object
           $src:            hashref:  decoded JSON object (Source JSON)
           $dst:            hashref:  decoded JSON object (Destination JSON)
           $diff:           arrayref: holds all of the operations
           $options:        defined:  specifies whether to use the old value
 
 Returns:  void
 
 Throws:   no

Used when hashrefs need to be compared. Goes in depth recursively calling the CompareValues() subroutine.

=item CompareArrays($path, $src, $dst, $diff, $options)

 Inputs:   $path            arrayref: each element represents a key in the JSON object
           $src:            arrayref: decoded JSON object (Source JSON)
           $dst:            arrayref: decoded JSON object (Destination JSON)
           $diff:           arrayref: holds all of the operations
           $options:        defined:  specifies whether to use the old value
 
 Returns:  void
 
 Throws:   no

Used when arrayrefs need to be compared. Goes in depth recursively calling the CompareValues() subroutine.

=back


=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

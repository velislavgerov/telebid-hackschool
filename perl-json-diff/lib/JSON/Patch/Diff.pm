package JSON::Patch::Diff;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use Test::Deep::NoTest qw(eq_deeply);

## Main Subroutines
sub GetPatch($$;$);
sub CompareValues($$$$;$);
sub CompareHashes($$$$;$);
sub CompareArrays($$$$;$);

## Handling Arrays
sub _longestCommonSubSequence($$);
sub _splitByCommonSequence($$$$);
sub _compareWithShift($$$$$$$;$);
sub _compareLeft($$$$$;$);
sub _compareRight($$$$$;$);
sub _optimizeWithReplace($;$);
#sub _optimizeWithMove($);
sub _expandInDepth($;$);

## Helpers
sub NormalizePatch($;$);
sub PushOperation($$$$$$;$);
sub GetJSONPointer($);
sub ReverseJSONPointer($);
sub IsNum($);

## Debug
sub TRACE(@);
sub ASSERT($$;$$);
our $DEBUG = 0;

sub GetPatch($$;$)
{
    my ($src, $dst, $options ) = @_;
    # TODO: better input handling
    # Example options config:
    #
    # $options = {
    #     keep_old:    1, 
    #     use_replace: 1,
    #     use_move:    1,
    #     in_depth:    1
    # };

    my $diff = [];
    my $path = [];
    
    TRACE("JSON::Diff:GetPatch with:");
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);
        
    CompareValues($path, $src, $dst, $diff, $options);
    NormalizePatch($diff, $options);

    return $diff;
}

sub CompareValues($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    
    TRACE("Comparing VALUES");
    TRACE("PATH:   ", $path);
    TRACE("SOURCE: ", $src);
    TRACE("DEST:   ", $dst);

    my $json = JSON->new->allow_nonref;
    $json = $json->canonical([1]);

    my $src_text = $json->encode($src);
    my $dst_text = $json->encode($dst);
    
    if (eq_deeply($src_text, $dst_text)) 
    {   
        # return only if the case is not like "1" == 1
        if (IsNum($src) == IsNum($dst)) 
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
        PushOperation("replace", $path, undef, $dst, $src, $diff, $options); 
    }

    return;
}

sub CompareHashes($$$$;$)
{
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
            PushOperation("remove", \@curr_path, undef, $$src{$key}, $$src{$key}, $diff, $options);

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

    return;
}

sub CompareArrays($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    my $sequence = _splitByCommonSequence($src, $dst, [0,-1], [0,-1]);
    my $left = $$sequence[0];
    my $right = $$sequence[1];
    my $shift = 0;
   
    # only 'add' and 'remove' operations
    _compareWithShift($path, $src, $dst, $left, $right, $shift, $diff, $options);
    
    # NOTE: `use_depth` depends on `use_replace`
    if ($$options{use_depth})
    {
        $$options{use_replace} = 1;
    }

    ## Optional
    _optimizeWithReplace($diff, $options) if ($$options{use_replace});
    #_optimizeWithMove($diff)             if ($$options{use_move});
    _expandInDepth($diff, $options)       if ($$options{use_depth});

    return;
}

sub _longestCommonSubSequence($$)
{
    my ($src, $dst) = @_;
    my $len_src = scalar @{$src};
    my $len_dst = scalar @{$dst};

    my @matrix;
    for (my $i = 0; $i < $len_src; $i++)
    {
        $matrix[$i] = [(0) x $len_dst];
    }
    
    # length of the longest subsequence
    my $z = 0;

    my $range_src;
    my $range_dst;

    for (my $i = 0; $i < $len_src; $i++)
    {
        for (my $j = 0; $j < $len_dst; $j++)
        {
            if (eq_deeply($$src[$i], $$dst[$j]))
            {
                TRACE("Found match:");
                TRACE("i:", $i);
                TRACE("j:", $j);
                
                if ($i == 0 || $j == 0)
                {
                    $matrix[$i][$j] = 1;
                }
                else
                {
                    $matrix[$i][$j] = $matrix[$i - 1][$j - 1] + 1;
                }
                
                if ($matrix[$i][$j] > $z)
                {
                    $z = $matrix[$i][$j];
                    $range_src = [$i - $z + 1, $i + 1];
                    $range_dst = [$j - $z + 1, $j + 1];
                }
            }
            else
            {
                $matrix[$i][$j] = 0;
            }
        }
    }
    
    TRACE("--------------- LONGEST COMMON SEQUENCE ---------------");
    TRACE("Matrix:",    @matrix);
    TRACE("Range src:", $range_src);
    TRACE("Range dst:", $range_dst);
    TRACE("------------ END OF LONGEST COMMON SEQUENCE -----------\n\n");
    
    if (defined $range_src)
    {
        # Test source range
        ASSERT(ref($range_src) eq 'ARRAY', "Source range must be an arrayref");
        ASSERT(scalar(@{$range_src}) == 2, "Source range must be of size 2");
        ASSERT(IsNum($$range_src[0]) && IsNum($$range_src[1]),
                    "Both values in source range must be numbers");
    }

    if (defined $range_dst)
    {
        # Test destination range
        ASSERT(ref($range_dst) eq 'ARRAY',"Destination range must be an arrayref");
        ASSERT(scalar(@{$range_dst}) == 2, "Destination range must be of size 2");
        ASSERT(IsNum($$range_dst[0]) && IsNum($$range_dst[1]),
            "Both values in destination range must be numbers");
    }
    
    return ($range_src, $range_dst);
}

sub _splitByCommonSequence($$$$)
{
    my ($src, $dst, $range_src, $range_dst) = @_;
    
    # Prevent useless comparisons in future
    $range_src = ($$range_src[0] != $$range_src[1]) ? $range_src : undef;
    $range_dst = ($$range_dst[0] != $$range_dst[1])  ? $range_dst : undef;
    
    TRACE("-------------SPLIT BY COMMON SEQUENCE----------\n\n\n"); 
    TRACE("SRC: ",       $src);
    TRACE("Range SRC: ", $range_src);
    TRACE("DST: ",       $dst);
    TRACE("Range DST: ", $range_dst);

    if (!defined $src)
    {
        return [undef, $range_dst];
    }
    elsif (!defined $dst)
    {
        return [$range_src, undef];
    }

    my ($x, $y) = _longestCommonSubSequence($src, $dst);
    
    TRACE("X:", $x);
    TRACE("Y:", $y);
    
    if (!defined $x || !defined $y)
    {
        return [$range_src, $range_dst];
    }

    my $l_src = $$x[0] == -1 ? [@$src[0 .. (scalar(@{$src}) - 2)]] : [@$src[0 .. $$x[0] - 1]];
    my $l_dst = $$y[0] == -1 ? [@$dst[0 .. (scalar(@{$dst}) - 2)]] : [@$dst[0 .. $$y[0] - 1]];
    my $l_range_src = [$$range_src[0], $$range_src[0] + $$x[0]];
    my $l_range_dst = [$$range_dst[0], $$range_dst[0] + $$y[0]];

    TRACE("left src:",       $l_src);
    TRACE("left range src:", $l_range_src);
    TRACE("left dst:",       $l_dst);
    TRACE("left range dst:", $l_range_dst);
    
    my $r_src = $$x[1] == -1 ? [@$src[scalar @{$src} - 1]] : [@$src[$$x[1] .. (scalar(@{$src}) - 1)]];
    my $r_dst = $$y[1] == -1 ? [@$dst[scalar @{$dst} - 1]] : [@$dst[$$y[1] .. (scalar(@{$dst}) - 1)]];
    my $r_range_src = [$$range_src[0] + $$x[1], ($$range_src[0] + scalar @{$src})];
    my $r_range_dst = [$$range_dst[0] + $$y[1], ($$range_dst[0] + scalar @{$dst})];
    
    TRACE("righ src:",        $r_src);
    TRACE("right range src:", $r_range_src);
    TRACE("right dst:",       $r_dst);
    TRACE("right range dst:", $r_range_dst);
 

    TRACE("--------------END SPLIT-----------------\n\n\n"); 
    return [_splitByCommonSequence($l_src, $l_dst, $l_range_src, $l_range_dst),
            _splitByCommonSequence($r_src, $r_dst, $r_range_src, $r_range_dst)];
}   

sub _compareWithShift($$$$$$$;$)
{
    ## TODO: Hashify params
    my ($path, $src, $dst, $left, $right, $shift, $diff, $options) = @_;
    
    TRACE("--------------- COMPARE WITH SHIFT ---------------");
    TRACE("LEFT:",       $left);
    TRACE("RIGHT:",      $right);
    TRACE("CURR SHIFT:", $shift);
        
    if (defined $left && scalar @$left == 2 && (ref($$left[0]) eq 'ARRAY' || ref($$left[1]) eq 'ARRAY'))
    {
        $shift = _compareWithShift($path, $src, $dst, $$left[0], $$left[1], $shift, $diff, $options);
    }
    elsif(defined $$left[0] && defined $$left[1])
    {
        $shift = _compareLeft($path, $src, $left, $shift, $diff, $options);
    }
    if (defined $right && scalar @$right == 2 && (ref($$right[0]) eq 'ARRAY' || ref($$right[1]) eq 'ARRAY'))
    {
        $shift = _compareWithShift($path, $src, $dst, $$right[0], $$right[1], $shift, $diff, $options);

    }
    elsif(defined $$right[0] && defined $$right[1])
    {
        $shift = _compareRight($path, $dst, $right, $shift, $diff, $options);
    }

    TRACE("------------ END OF COMPARE WITH SHIFT -----------\n\n");

    return $shift;
}

sub _compareLeft($$$$$;$)
{
    my ($path, $src, $left, $shift, $diff, $options) = @_;
    my ($start, $end) = @{$left};
    
    TRACE("------------ COMPARE LEFT -----------\n\n");
    
    if ($end == -1)
    {   
        $end = scalar @{$src} ;
    }

    # we need to `remove` elements from list tail to not deal with index shift
    my @elements_range = reverse (($start + $shift) .. ($end + $shift - 1));

    foreach my $idx (@elements_range)
    {
        TRACE("ELEMENTS RANGE", \@elements_range);
        TRACE("SRC:",  $src);
        TRACE("IDX:",  $idx);
        TRACE("SHIFT", $shift);

        my @curr_path = (@$path, $idx);
        my $shifted_index = $idx - $shift;
        my $value     = $$src[$shifted_index];
        my $old       = $$src[$shifted_index];

        TRACE("VALUE", $value);
        TRACE("OLD", $old);
        
        PushOperation('remove', \@curr_path, undef, $value, $old, $diff, $options);    
    }
    $shift -= 1;
    
    TRACE("------------ END OF COMPARE LEFT -----------\n\n");

    return $shift;
}

sub _compareRight($$$$$;$) 
{
    my ($path, $dst, $right, $shift, $diff, $options) = @_;
    my ($start, $end) = @{$right};
    
    if ($end == -1)
    {
        #XXX: Does this happen in my impl?
        $end = scalar @{$dst} ;
    } 
    # we need to `remove` elements from list tail to not deal with index shift
    
    my @elements_range = ($start .. $end - 1);

    foreach my $idx (@elements_range)
    {
        my @curr_path = (@$path, $idx);
        
        PushOperation('add', \@curr_path, undef, $$dst[$idx], undef, $diff, $options);
        

    }
    $shift += 1;

    return $shift;
}

sub _optimizeWithReplace($;$)
{
    my ($diff, $options) = @_;
    
    my $len_diff     = scalar @{$diff};
    my $updated_diff = [@{$diff}];
    my $shift        = 0;
    my $paths        = {};
    my $paths_ids    = {};
    
    TRACE("------------ OPTIMIZE  ------------");
    TRACE("DIFF", $diff);

    for (my $i = 0; $i < $len_diff; $i++)
    {
        my $this = $$diff[$i];

        if (exists $$paths{$$this{path}})
        {
            my $prev = $$paths{$$this{path}};
            my $prev_id = $$paths_ids{$$this{path}};
            
            if ($$prev{op} eq 'remove' && $$this{op} eq 'add')
            {
                my $op = { 
                    'op'    => 'replace',
                    'path'  => $$prev{path},
                    'value' => $$this{value},
                };
                
                if ($$options{keep_old} || $$options{use_depth})
                {
                    $$op{old} = $$prev{value};
                }

                ## Update first operation and shift
                $$updated_diff[$prev_id] = $op;
                $shift -= 1;
                
                ## Update the resulting diff
                my @left_of_this  = @{$updated_diff}[0 .. $i + $shift];
                my @right_of_this = @{$updated_diff}[($i + 1) .. (scalar(@{$updated_diff}) - 1)];
                $updated_diff  = [@left_of_this, @right_of_this];
            }

            TRACE("THIS:",  $this);
            TRACE("PREV:",  $prev);
            TRACE("DIFF:",  $diff);
            TRACE("UDIFF:", $updated_diff);
            TRACE("i:",     $i);
            TRACE("SHIFT:", $shift);

            next;
        }
        
        ## Update paths hash
        $$paths{$$this{path}} = $this;
        $$paths_ids{$$this{path}} = $i + $shift;
        
        TRACE("PATHS UPDATED:",     $paths);
        TRACE("PATHS IDS UPDATED:", $paths_ids);
    }
    
    TRACE("------------ END OF OPTIMIZE  ------------");
    
    ## Update changes to original diff
    @{$diff} = @{$updated_diff};

    return;
}

sub _optimizeWithMove($)
{
    my ($diff) = @_;
    my $len_diff = scalar @{$diff};
    my $updated_diff = [@{$diff}];

    ## TODO: FIX PATHS DEPENDING ON SHIFT

    TRACE("------------ OPTIMIZE WITH MOVE ------------");

    my $shift = 0;
    my $path_shift = 0;
    my %unique_value_path;

    for (my $i = 0; $i < $len_diff; $i++)
    {
        my $this = $$diff[$i];

        if (defined $unique_value_path{$$this{value}} && $$this{op} ne $unique_value_path{$$this{value}}{op})
        {
            TRACE("HERREEEEEEE");
            my $from_id   = $unique_value_path{$$this{value}}{idx};
            my $from_path;
            my $to_path;

            my ($before_index, $index) = $$this{path} =~ /(.*)\/([-]?|[0-9]*)\z/; 
            $index += $path_shift - $shift;


            if ($unique_value_path{$$this{value}}{op} eq 'remove')
            {
                $to_path    = $before_index . '/' . $index;
                $from_path  = $unique_value_path{$$this{value}}{path};
            }
            else
            {
                $to_path    = $unique_value_path{$$this{value}}{path};
                $from_path  = $before_index . '/' . $index;
            }
                
            my $op = {
                'op'    => 'move',
                'from'  => $from_path,
                'path'  => $to_path,
                #'value' => $$this{value}
            };

            $$updated_diff[$from_id] = $op;

            $shift -= 1;

            if ($i != (scalar(@$updated_diff) - 1))
            {
                TRACE("UDIFF[0..i]:", @$updated_diff[0 .. $i - 1]);
                TRACE("UDIFF[i..0]:", @$updated_diff[$i + 1 .. scalar(@$updated_diff) + $shift]);
                $updated_diff = [@$updated_diff[0 .. $i + $shift], @$updated_diff[$i + 1 .. scalar(@$updated_diff) + $shift]];
            }
            else
            {
                $updated_diff = [@$updated_diff[0 .. $i + $shift]];
            }
            


            delete $unique_value_path{$$this{value}};
        }
        else
        {
            $unique_value_path{$$this{value}} = {
                'idx'  => $i, 
                'path' => $$this{path},
                'op'   => $$this{op}
            };

            if ($$this{op} eq 'add')
            {
                $path_shift -= 1;
            }
            elsif ($$this{op} eq 'remove')
            {
                $path_shift += 1;
            }
        }

        TRACE("THIS:",         $this);
        TRACE("UVALUES HASH:", %unique_value_path);
        TRACE("DIFF:",         $diff);
        TRACE("UDIFF:",        $updated_diff);
        TRACE("SHIFT:",        $shift);
    }

    TRACE("------- END OF OPTIMIZE WITH MOVE ---------");

    @{$diff} = @{$updated_diff};

    return;
}

sub _expandInDepth($;$)
{
    my ($diff, $options) = @_;
    my $len_diff = scalar @{$diff};
    my $updated_diff = [@{$diff}];
    
    my $shift = 0;
    
    TRACE("------------ EXPAND IN DEPTH ------------");

    for (my $i = 0; $i < $len_diff; $i++)
    {
        my $this = $$diff[$i];
        my $sub_diff = [];

        if ($$this{op} eq 'replace' && ref($$this{value}) eq ref($$this{old}) && ref($$this{old}) ne '')
        {
            TRACE("Reverse pointer:");

            my $curr_path = ReverseJSONPointer($$this{path});

            CompareValues($curr_path, $$this{old}, $$this{value}, $sub_diff, $options);
            
            TRACE("ORIGINAL DIFF",       $diff);
            TRACE("THIS:",               $this);
            TRACE("IN DIFF:",            $sub_diff);
            TRACE("BEFORE UPDATE DIFF:", $updated_diff);
            
            if (!eq_deeply($sub_diff, $this))
            {
                ## Shift for the number of operations in sub diff
                $shift += scalar @$sub_diff;
                
                ## Update our diff
                my @left_of_this  = @$updated_diff[0 .. $i - 1];
                my @right_of_this = @$updated_diff[$i + 1 .. scalar(@$updated_diff) - 1];
                $updated_diff     = [@left_of_this, @$sub_diff, @right_of_this];
            }

            TRACE("UPDATED DIFF:", $updated_diff);
        }
    }
    
    TRACE("------------ END OF EXPAND ------------");

    ## Update original diff
    @{$diff} = @{$updated_diff};

    return;
}

sub NormalizePatch($;$)
{
    my ($diff, $options) = @_;
    
    foreach my $op (@{$diff})
    {
        if (!$$options{keep_old})
        {
            delete $$op{old};
        }
        
        if ($$op{op} eq 'remove')
        {
            delete $$op{value};
        }
    }

    return;
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
            "path"  => $pointer,
            "value" => $value # XXX: keeping it for optimization
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

    if ($$options{keep_old} && $operation_name ne 'add' && $operation ne 'move')
    {
        $$operation{old} = $old_value; 
    }

    push @{$diff}, $operation;

    TRACE("DIFF updated: ", $diff);

    return;
}

sub GetJSONPointer($) 
{
    # Returns JSON Pointer string
    # Input
    #  :path - reference to array specifying JSON path elements
    
    my ($curr_path) = @_;
    my $pointer;
    
    if (!scalar @{$curr_path})
    {
        return '';        # path to whole document
    }

    foreach my $point (@{$curr_path})
    {
        $point =~ s/~/~0/g;   # replace ~ with ~0
        $point =~ s/\//~1/g;  # replace / with ~1
        $pointer  .= '/' . $point; # prefix result with /
    }

    return $pointer;
}

sub ReverseJSONPointer($)
{
    # Reverses JSON Pointer to path array
    my ($pointer) = @_;
    my $curr_path = [split(/\//, $pointer)];
    shift @$curr_path;
    
    TRACE("POINTER BEFRORE REPLACE:", $pointer);
    TRACE("PATH BEFORE REPLACE:"    , $curr_path);

    foreach my $point (@$curr_path)
    {
        $point =~ s/~1/\//g;
        $point =~ s/~0/~/g;
    }

    TRACE("PATH AFTER REPLACE:", $curr_path);

    return $curr_path;
}

sub IsNum($) 
{
    # Input: Perl Scalar
    # Returns: 1 if perl scalar is a number, 0 otherwise
    # Source: PerlMonks
    # Question: How to check if scalar value is numeric or string
    # Answer: XORing a string gives a string of nulls while XORring
    # a number gives zero
    # URL: https://tinyurl.com/ycnltx55
    
    my ($scalar) = @_;

    if ($scalar eq '')
    {
        return 0;
    }
    
    return $scalar ^ $scalar ? 0 : 1
}

sub TRACE(@) 
{
    if (!$DEBUG) 
    {
        return;
    }
    
    my $msg = '';
    foreach my $message (@_) 
    {
        if (!defined $message)
        {
            $msg .= '<undef>';
            next;
        }

        if (ref $message) 
        {
            $msg .= Dumper $message;
        }
        else
        {
            $msg .= $message;
        }
    }
    print STDERR $msg, "\n";

    return;
}

sub ASSERT($$;$$) 
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

    return;
}

1;

__END__

=encoding utf8

=head1 NAME

JSON::Patch::Diff

=head1 SYNOPSIS

    use JSON::Patch::Diff;

    ## These are usually decoded from JSON
    my $src = {"value"=> 1, "list"=> [[1,2],1,2]};
    my $dst = {"name"=> "new", "value"=> 0, "list"=> [[1,4],2,3]};
    
    my $options = {"use_depth"=> 1}; ## optional

    my $diff = GetPatch($src, $dst, $options);
    
    ## Result:  
    # $diff = 
    #   [
    #       {"op"=> "add", "path"=> "/name", "value"=> "new"},
    #       {"op"=> "replace", "path"=> "/list/0/1", "value"=> 4},
    #       {"op"=> "remove", "path"=> "/list/1"},
    #       {"op"=> "add", "path"=> "/list/2", "value"=> 3},
    #       {"op"=> "replace", "path"=> "/value", "value"=> 0}
    #   ];

=head1 DESCRIPTION

A minimalistic module to produce B<JSON Patch> difference from I<source> to I<destination> perlrefs, decoded from JSON text. This difference is a patch which when applied to our I<source> will produce our I<destination>.

See: L<RFC6902|https://tools.ietf.org/html/rfc6902>

=head1 FUNCTIONAL INTERFACE 

All functions intended to be accessed by the outside world.

=over 4

=item I<GetPatch($src, $dst, $options)>

 Inputs:    $src:            perlref: Usually decoded from JSON text (source)

            $dst:            perlref: Usually decoded from JSON text (destination)
 
 Optional:  $options:        hashref: Used to specify optional parameters for the output and
                                      the overall operation of the module
 
 Returns:   $diff:           perlref: [ { JSON Patch operation }, ... ]
 
 Throws:    no

Returns a B<JSON Patch> with the difference obtained from I<source> to I<destination>. The I<$options> hash refference is used to specify additional parameter configuration for the resulting B<JSON Patch>.

#TODO: Document I<$options>.

=back

=head1 INTERNAL FUNCTIONS

All functions inherent to the internal operations of the module.

B<WARNING>: This section is intended for I<developers>. Modify at your own risk!

=head2 VALUE COMPARISONS

Functions that recursively compare the three main categories of values - values, arrays of values and associative arrays of values (hashes). These further update the B<JSON Patch> difference when need be.

=over 4

=item I<CompareValues($path, $src, $dst, $diff, $options)>

 Inputs:    $path:           arrayref: Path array where each element relates to successive
                                       JSON object key

            $src:            perlref:  Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $dst:            perlref:  Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $diff:           arrayref: Used to hold and update the resulting JSON Patch

 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void
 
 Throws:    no

This is the main entry point to comparing I<source> to I<destination> values and updating the B<JSON Patch> accordingly. It's main operation is to compare the values and, if needed, choose the appropriate further actions depending on the value types.

=item I<CompareHashes($path, $src, $dst, $diff, $options)>

 Inputs:    $path            arrayref: Path array where each element relates to successive
                                       JSON object key

            $src:            hashref:  Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $dst:            hashref:  Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $diff:           arrayref: Used to hold and update the resulting JSON Patch

 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module

 Returns:   void
 
 Throws:    no

Called from within I<CompareValues()>, this subroutine is used to compare pairs of associative arrays (hashes). It pushes I<remove> and I<add> operations to the B<JSON Patch> difference when mismatches are found between the I<source> and I<destination> hashes. When matching keys are found, it recursively goes through I<CompareValues()>.

=item I<CompareArrays($path, $src, $dst, $diff, $options)>

 Inputs:    $path            arrayref: Path array where each element relates to successive
                                       JSON object key

            $src:            arrayref: Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $dst:            arrayref: Usually decoded from JSON text (source) or part of it,
                                       passed recursively by one of the other methods

            $diff:           arrayref: Used to hold and update the resulting JSON Patch

 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void
 
 Throws:    no

Called from within I<CompareValues()>, this function is used to compare pairs of arrays. This subroutine is the most complex by operation and it further relies on the B<ARRAY HELPERS> explained below. 

=back

=head2 ARRAY HELPERS

=over 4

=item I<_longestCommonSubSequence($src, $dst)>

 Inputs:    $src:            arrayref:  Usually decoded from JSON text (source)

            $dst:            arrayref:  Usually decoded from JSON text (destination)
 
 Returns:   ($range_src,
             $range_dst):    array:     Specifying the ranges of the longest common
                                        sequences between the source and destination
            
 Variables: $range_src:      array:     Holds the indexes of the first and last element
                                        from source that identify the longest common
                                        subsequence found between source and destination

            $range_dst:      array:     Holds the indexes of the first and last element
                                        from destination that identify the longest common
                                        subsequence found between source and destination
 
 Throws:   no

Returns a pair of ranges that specify the index ranges from source and destination of the longest common subsequence found between the two.

=item I<_splitByCommonSequence($src, $dst, $range_src, $range_dst)>

 Inputs:    $src:           arrayref:  Usually decoded from JSON text (source)
            
            $dst:           arrayref:  Usually decoded from JSON text (destination)
            
            $range_src:     array:     Holds the indexes of the first and last element
                                       from source that identify the longest common
                                       subsequence found between source and destination
            
            $range_dst:     array:     Holds the indexes of the first and last element
                                       from destination that identify the longest common
                                       subsequence found between source and destination

 
 Returns:   $shift:         scalar:    A number specifying the index shift of the array.
                                       Each time a new operation is added, this shift
                                       should be accounted for
 
 Throws:   no

TODO: Document

=item _compareWithShift($$$$$$$;$);

TODO: Document

=item _compareLeft($$$$$;$);

TODO: Document

=item _compareRight($$$$$;$); 

TODO: Document

=item I<_optimizeWithReplace($diff, $options)>

 Inputs:    $diff:           arrayref: Used to hold and update the resulting JSON Patch
            
 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void

 Throws:    no

Searches I<$diff> for pairs of I<remove> followed by I<add> operations pointing to the same path and substitutes them with a single I<replace> operation. The I<$diff> refference is then updated by the subroutine.

=item I<_optimizeWithMove($diff, $options)>

NOTE: Currently disabled.

 Inputs:    $diff:           arrayref: Used to hold and update the resulting JSON Patch
            
 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void

 Throws:    no

Searches I<$diff> for pairs of I<remove> followed by I<add> operations pointing to the same value and substitutes them with a single I<move> operation. The I<$diff> refference is then updated by the subroutine.

=item I<_expandInDepth($diff, $options)>

 Inputs:    $diff:           arrayref: Used to hold and update the resulting JSON Patch
            
 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void

 Throws:    no

Searches I<$diff> for I<replace> operations that have updated a composite object with a composite object and goes in to compare the values in depth. The I<$diff> refference is then updated by the subroutine.

=back

=head2 GENERAL HELPERS

=over 4

=item I<NormalizePatch($diff, $options)>

 Inputs:    $diff:           arrayref: Used to hold and update the resulting JSON Patch
            
 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:   void

 Throws:    no

Removes additional values stored inside the operation hashes that are neccessary for the operation of I<_optimizeWithReplace()> and I<_expandInDepth()>.

=item I<PushOperation($operation_name, $path, $value, $old_value, $diff, $options)>

 Inputs:    $operation_name  scalar:   Can be either 'add', 'replace', 'remove' or 'move'

            $path            arrayref: Path array where each element relates to successive
                                       JSON object key

            $value:          perlref:  The value to be 'added' or 'replaced'

            $old_value:      perlref:  The old value to be used if necessary

            $diff:           arrayref: Used to hold and update the resulting JSON Patch

 Optional:  $options:        hashref:  Used to specify optional parameters for the output and
                                       the overall operation of the module
 
 Returns:  void
 
 Throws:   if '$operation_name' is invalid or unsupported

Prepares and pushes a new operation to our I<$diff>.

=item I<GetJSONPointer($path)>

 Inputs:   $path            arrayref: each element represents a key in the JSON object
 
 Returns:  $pointer         scalar:   JSON Pointer string
 
 Throws:   no 

Returns a JSON Pointer string created from $path.

=item I<ReverseJSONPointer($pointer)>

 Inputs:   $pointer         scalar:   JSON Pointer string

 Returns:  $path            arrayref: Path array where each element relates to successive
                                      JSON object key
 
 Throws:   no 

Returns the $path corresponding to a JSON Pointer string.

=item I<IsNum($scalar)>

 Inputs:   $scalar         scalar:   A scalar value which can be either string or a number

 Returns:  1 or 0
 
 Throws:   no 

Returns 1 if the scalar value is a number or 0 otherwise.

=back

=head1 BUGS

=over 4

=item I<use_move>

I<_optimizeWithMove()> does not properly account for item shifts. 
Currently, the function has been disabled.

=item I<$DEBUG>

When I<$DEBUG> is truthly, the module wrongly converts JSON numbers to strings.

=back


=head1 AUTHOR

Velislav Gerov E<lt>velislav@telebid-pro.comE<gt>

=cut

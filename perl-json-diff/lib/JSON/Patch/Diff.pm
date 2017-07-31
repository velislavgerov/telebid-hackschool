package JSON::Patch::Diff;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use Test::Deep::NoTest qw(eq_deeply);
use Scalar::Util qw(looks_like_number);
use Storable 'dclone';

our $DEBUG = 0;
our $CALLED = 0; #TODO REMOVE

my $json = JSON->new->allow_nonref;

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
    
    _normalize($diff, $options);

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
        _compareLists($path, $src, $dst, $diff, $options);
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
            PushOperation("remove", \@curr_path, undef, $$src{$key}, $src, $diff, $options);

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
    ## TODO: $dst_idx => $i || $dst_idx
    for (my $dst_idx = 0; $dst_idx < scalar @{$dst}; $dst_idx++)
    {
        my $target_value = $${dst}[$dst_idx];;
        
        if($dst_idx >= scalar @{$src})
        {
            @curr_path = (@{$path}, '-');
            PushOperation("add", \@curr_path, undef, $target_value, undef, $diff, $options);
            last;
        }
        
        my $updated_value = $${src}[$dst_idx];
        
        @curr_path = (@{$path}, $dst_idx);
        
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

    ## For each index in DST
    for (my $dst_idx = 0; $dst_idx <= scalar @{$dst}; $dst_idx++)
    {
        ## Hold both SRC and DST values at the current DST index
        my $target_value = $$dst[$dst_idx];
        my $updated_value = $updated_src[$dst_idx];

        ## Loop through the src array to see if we can find a match for our target value.
        ## Note: If no match was found, we loop an extra time to replace the SRC value at
        ## our current DST index 
        for (my $src_idx = $dst_idx; $src_idx <= scalar @updated_src; $src_idx++)
        {
            TRACE("UPDATED SRC", \@updated_src);
            
            if ($src_idx == scalar @updated_src)
            {                
                if(scalar @updated_src < scalar @{$dst} && $dst_idx == (scalar(@{$dst}) - 1))
                {
                    for (my $i = scalar(@updated_src); $i <= (scalar(@{$dst}) - 1); $i++)
                    {
                        $target_value = $$dst[$i];
                        @curr_path = (@{$path}, '-');
                        PushOperation("add", \@curr_path, undef, $target_value, undef, $diff, $options);
                    }
 
                }
                
                @curr_path = (@{$path}, $dst_idx);
                CompareValues(\@curr_path, $updated_value, $target_value, $diff, $options);
                #@updated_src[$dst_idx] = $target_value; #XXX: Not sure if updated, needs checking

                last;
            }

            my $curr_value = $updated_src[$src_idx];
            
            if (eq_deeply($curr_value, $target_value) && $src_idx != $dst_idx)
            {
                @curr_path = (@{$path}, $dst_idx);
                my @from_path = (@{$path}, $src_idx);
                
                TRACE("FROM PATH: ", \@from_path);
                TRACE("TV:        ", $target_value);
                TRACE("UP:        ", $updated_value);

                PushOperation("move", \@curr_path, \@from_path, $target_value, $updated_value, $diff, $options);
                
                @updated_src[$dst_idx] = $target_value;
                @updated_src[$src_idx] = $updated_value;
                
                last;
            }
        }

        if (scalar @updated_src >= scalar @{$dst} && $dst_idx == scalar(@{$dst}))
        { 
            for (my $i = scalar(@updated_src) - 1; $i >= scalar @{$dst}; $i--)
            {
                my $old_value = $updated_src[$i];
                @curr_path = (@{$path}, $i);
                PushOperation("remove", \@curr_path, undef, undef, $old_value, $diff, $options);
            }
            last;
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
            if ($i != $j) 
            {
                ListOperationAdd($path, $i, $left, $right, \@src_new, $diff, $options);
            }
            $i += 1;
            $j = $i;
        }
        else {
            if ($j == $len_dst - 1) 
            {
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

sub _compareLists($$$$;$);
sub _compareWithShift($$$$$$$;$);
sub _splitByCommonSequence($$$$);
sub _longestCommonSubSequence($$);

sub _compareLists($$$$;$)
{
    my ($path, $src, $dst, $diff, $options) = @_;
    my $sequence = _splitByCommonSequence($src, $dst, [0,-1], [0,-1]);
    my $left = $$sequence[0];
    my $right = $$sequence[1];
    my $shift = 0;
   
    # only 'add' and 'remove' operations
    _compareWithShift($path, $src, $dst, $left, $right, \$shift, $diff, $options);
    
    # NOTE: `use depth` relies on `use_replace` and `keep_old`
    if ($$options{use_depth})
    {
        #$$options{keep_old}    = 1;
        $$options{use_replace} = 1;
    }

    # optional
    _optimize($diff, $options)      if ($$options{use_replace});

    #_optimizeWithMove($diff);
    _expandInDepth($diff, $options) if ($$options{use_depth});
}

sub _splitByCommonSequence($$$$)
{
    my ($src, $dst, $range_src, $range_dst) = @_;
    
    # Prevent useless comparisons in future
    $range_src = ($$range_src[0] != $$range_src[1]) ? $range_src : undef;
    $range_dst = ($$range_dst[0] != $$range_dst[1])  ? $range_dst : undef;
    
    TRACE("-------------SPLIT BY COMMON SEQUENCE----------\n\n\n"); 
    TRACE("SRC: ");
    TRACE($src);
    TRACE("Range SRC: ");
    TRACE($range_src);
    TRACE("DST: ");
    TRACE($dst);
    TRACE("Range DST: ");
    TRACE($range_dst);

    if (!defined $src)
    {
        return [undef, $range_dst];
    }
    elsif (!defined $dst)
    {
        return [$range_src, undef];
    }

    my ($x, $y) = _longestCommonSubSequence($src, $dst);
    
    TRACE("X:");
    TRACE($x);
    TRACE("Y:");
    TRACE($y);
    
    if (!defined $x || !defined $y)
    {
        return [$range_src, $range_dst];
    }


    my $l_src = $$x[0] == -1 ? [@$src[0 .. (scalar(@{$src}) - 2)]] : [@$src[0 .. $$x[0] - 1]];
    my $l_dst = $$y[0] == -1 ? [@$dst[0 .. (scalar(@{$dst}) - 2)]] : [@$dst[0 .. $$y[0] - 1]];
    my $l_range_src = [$$range_src[0], $$range_src[0] + $$x[0]];
    my $l_range_dst = [$$range_dst[0], $$range_dst[0] + $$y[0]];

    TRACE("left src:");
    TRACE($l_src);
    TRACE("left range src:");
    TRACE($l_range_src);
    TRACE("left dst:");
    TRACE($l_dst);
    TRACE("left range dst:");
    TRACE($l_range_dst);
    
    my $r_src = $$x[1] == -1 ? [@$src[scalar @{$src} - 1]] : [@$src[$$x[1] .. (scalar(@{$src}) - 1)]];
    my $r_dst = $$y[1] == -1 ? [@$dst[scalar @{$dst} - 1]] : [@$dst[$$y[1] .. (scalar(@{$dst}) - 1)]];
    my $r_range_src = [$$range_src[0] + $$x[1], ($$range_src[0] + scalar @{$src})];
    my $r_range_dst = [$$range_dst[0] + $$y[1], ($$range_dst[0] + scalar @{$dst})];
    
    TRACE("righ src:");
    TRACE($r_src);
    TRACE("right range src:");
    TRACE($r_range_src);
    TRACE("right dst:");
    TRACE($r_dst);
    TRACE("right range dst:");
    TRACE($r_range_dst);
 

    TRACE("--------------END SPLIT-----------------\n\n\n"); 
    return [_splitByCommonSequence($l_src, $l_dst, $l_range_src, $l_range_dst),
            _splitByCommonSequence($r_src, $r_dst, $r_range_src, $r_range_dst)];
                            
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
    TRACE("Matrix:");
    TRACE(@matrix);
    TRACE("Range src:");
    TRACE($range_src);
    TRACE("Range dst:");
    TRACE($range_dst);
    TRACE("------------ END OF LONGEST COMMON SEQUENCE -----------\n\n");
    
    if (defined $range_src)
    {
        # Test source range
        ASSERT(ref($range_src) eq 'ARRAY', "Source range must be an arrayref");
        ASSERT(scalar(@{$range_src}) == 2, "Source range must be of size 2");
        ASSERT(isNum($$range_src[0]) && isNum($$range_src[1]),
                    "Both values in source range must be numbers");
    }

    if (defined $range_dst)
    {
        # Test destination range
        ASSERT(ref($range_dst) eq 'ARRAY',"Destination range must be an arrayref");
        ASSERT(scalar(@{$range_dst}) == 2, "Destination range must be of size 2");
        ASSERT(isNum($$range_dst[0]) && isNum($$range_dst[1]),
            "Both values in destination range must be numbers");
    }
    
    return ($range_src, $range_dst);
}

sub _compareWithShift($$$$$$$;$)
{
    my ($path, $src, $dst, $left, $right, $shift, $diff, $options) = @_;
    
    TRACE("--------------- COMPARE WITH SHIFT ---------------");
    TRACE("LEFT:");
    TRACE($left);
    TRACE("RIGHT:");
    TRACE($right);
    TRACE("CURR SHIFT:");
    TRACE($$shift);
        
    if (defined $left && scalar @$left == 2 && (ref($$left[0]) eq 'ARRAY' || ref($$left[1]) eq 'ARRAY'))
    {
        _compareWithShift($path, $src, $dst, $$left[0], $$left[1], $shift, $diff, $options);
    }
    elsif(defined $$left[0] && defined $$left[1])
    {
        _compareLeft($path, $src, $left, $shift, $diff, $options);
    }
    if (defined $right && scalar @$right == 2 && (ref($$right[0]) eq 'ARRAY' || ref($$right[1]) eq 'ARRAY'))
    {
        _compareWithShift($path, $src, $dst, $$right[0], $$right[1], $shift, $diff, $options);

    }
    elsif(defined $$right[0] && defined $$right[1])
    {
        _compareRight($path, $dst, $right, $shift, $diff, $options);
    }

    TRACE("------------ END OF COMPARE WITH SHIFT -----------\n\n");
}

sub _compareLeft($$$$$;$) 
{
    my ($path, $src, $left, $shift, $diff, $options) = @_;
    my ($start, $end) = @{$left};
    
    TRACE("------------ COMPARE LEFT -----------\n\n");
    

    if ($end == -1)
    {   
        #XXX: Does this happen in my impl?
        $end = scalar @{$src};
    }
    # we need to `remove` elements from list tail to not deal with index shift
    foreach my $idx (reverse ($start + $$shift .. $end + $$shift - 1))
    {
        TRACE("SRC:");
        TRACE($src);
        TRACE("IDX:");
        TRACE($idx);
        TRACE("SHIFT");
        TRACE($$shift);
        my @curr_path = (@$path, $idx);
        my $value =  $$src[$idx - $$shift];
        my $old = $$src[$idx - $$shift];
        PushOperation('remove', \@curr_path, undef, $value, $old, $diff, $options);
        $$shift -= 1;
    }
    TRACE("------------ END OF COMPARE LEFT -----------\n\n");
}

sub _compareRight($$$$$;$) 
{
    my ($path, $dst, $right, $shift, $diff, $options) = @_;
    my ($start, $end) = @{$right};
    
    if ($end == -1)
    {
        #XXX: Does this happen in my impl?
        $end = scalar @{$dst};
    } 
    # we need to `remove` elements from list tail to not deal with index shift
    

    foreach my $idx (($start .. $end - 1))
    {
        my @curr_path = (@$path, $idx);
        PushOperation('add', \@curr_path, undef, $$dst[$idx], undef, $diff, $options);
        $$shift += 1;
    }
}

sub _optimize($;$)
{
    my $diff = shift;
    my $options = shift;
    my $len_diff = scalar @{$diff};
    my $updated_diff = [@{$diff}];
    my $shift = 0;
    my $paths = {};
    my $paths_ids = {};
    
    TRACE("------------ OPTIMIZE  ------------");
    TRACE("DIFF");
    TRACE($diff);


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

                $$op{old} = $$prev{value} if ($$options{keep_old} || $$options{use_depth});

                $shift -= 1;
                $$updated_diff[$prev_id] = $op;


                TRACE("Left OF i=$i");
                #TRACE(@$updated_diff[0 .. $i - 1]);
                TRACE("RIGHT OF i=$i");
                #TRACE(@$updated_diff[$i + 1 .. scalar(@$updated_diff) - 1]);
                
                $updated_diff = [@$updated_diff[0 .. $i + $shift], @$updated_diff[$i + 1  .. scalar(@$updated_diff) - 1]];
                
            }
            TRACE("THIS:");
            TRACE($this);
            TRACE("PREV:");
            TRACE($prev);
            TRACE("DIFF:");
            TRACE($diff);
            TRACE("UDIFF:");
            TRACE($updated_diff);
            TRACE("i:");
            TRACE($i);
            TRACE("SHIFT:");
            TRACE($shift);
            next;
        }
        $$paths{$$this{path}} = $this;
        $$paths_ids{$$this{path}} = $i + $shift;
        
        TRACE("PATHS UPDATED:");
        TRACE($paths);
        TRACE("PATHS IDS UPDATED:");
        TRACE($paths_ids);
    }
    
    TRACE("------------ END OF OPTIMIZE  ------------");
    @{$diff} = @{$updated_diff};
}

sub _optimizeWithMove($)
{
    my $diff = shift;
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
                TRACE("UDIFF[0..i]:");
                TRACE(@$updated_diff[0 .. $i - 1]);
                TRACE("UDIFF[i..0]:");
                TRACE(@$updated_diff[$i + 1 .. scalar(@$updated_diff) + $shift]);
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

        TRACE("THIS:");
        TRACE($this);
        TRACE("UVALUES HASH:");
        TRACE(%unique_value_path);
        TRACE("DIFF:");
        TRACE($diff);
        TRACE("UDIFF:");
        TRACE($updated_diff);
        TRACE("SHIFT:");
        TRACE($shift);
    }

    TRACE("------- END OF OPTIMIZE WITH MOVE ---------");

    @{$diff} = @{$updated_diff};
}

sub _expandInDepth($;$)
{
    $CALLED += 1;
    my $diff = shift;
    my $options = shift;
    my $len_diff = scalar @{$diff};
    my $updated_diff = [@{$diff}];
    
    my $shift = 0;
    
    TRACE("------------ EXPAND IN DEPTH ------------");

    for (my $i = 0; $i < $len_diff; $i++)
    {
        my $this = $$diff[$i];
        my $in_diff = [];
        if ($$this{op} eq 'replace' && ref($$this{value}) eq ref($$this{old}) && ref($$this{old}) ne '')
        {
            TRACE("Reverse pointer:");
            my $curr_path = ReverseJSONPointer($$this{path});

            CompareValues($curr_path, $$this{old}, $$this{value}, $in_diff, $options);
            
            TRACE("ORIGINAL DIFF");
            TRACE($diff);
            TRACE("THIS:");
            TRACE($this);
            TRACE("IN DIFF:");
            TRACE($in_diff);
            TRACE("BEFORE UPDATE DIFF:");
            TRACE($updated_diff);
            
            if (!eq_deeply($in_diff, $this))
            {
                $shift += scalar @$in_diff;

                if ($i != ($len_diff - 1))
                {
                    $updated_diff = [
                        (@$updated_diff[0 .. $i - 1],
                         @$in_diff, 
                         @$updated_diff[$i + 1 .. scalar(@$updated_diff) - 1])
                    ];
                }
                else
                {
                    $updated_diff = [@$updated_diff[0 .. $i - 1], @$in_diff];
                }
            }
            TRACE("UPDATED DIFF:");
            TRACE($updated_diff);
        }
    }
    
    TRACE("------------ END OF EXPAND ------------");

    @{$diff} = @{$updated_diff};
}

sub _normalize($;$)
{
    my $diff    = shift;
    my $options = shift;
    
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

sub ReverseJSONPointer($)
{
    # Reverses JSON Pointer to path array
    my $pointer = shift;
    my $curr_path = [split(/\//, $pointer)];
    shift @$curr_path;
    
    TRACE("POINTER BEFRORE REPLACE:");
    TRACE($pointer);
    TRACE("PATH BEFORE REPLACE:");
    TRACE($curr_path);

    foreach my $point (@$curr_path)
    {
        $point =~ s/~1/\//g;
        $point =~ s/~0/~/g;
    }

    TRACE("PATH AFTER REPLACE:");
    TRACE($curr_path);

    return $curr_path;
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

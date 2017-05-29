from __future__ import division # Python 2.7 compatibility 
from itertools import combinations
import collections
import math
import sys
import time

def handle_input():
    try:
        error_message = "Invalid input format"
        print("Input:")
        if (sys.version_info > (3, 0)): fl = input()
        else: fl = raw_input() # Python 2 compatibility
        n, k = [int(x) for x in fl.split(" ")]
        if n <= 0 or n >= 1001: 
            error_message = "Invalid value {0} for N. (1<=N<=1000)".format(n)
            raise ValueError
        if k <= 0 or k >= 1001: 
            error_message = "Invalid value {0} for K. (1<=K<=1000)".format(k)
            raise ValueError
        if (sys.version_info > (3, 0)): sl = input()
        else: sl = raw_input() # Python 2 compatibility
        weights = [int(x) for x in sl.split(" ")]
        # check for correct number of weights
        for w in weights:
            if w <= 0 or w >= 100000: 
                error_message = "Invalid weight value (W). (1<=W<=100000)"
                raise ValueError
        if len(weights) != n: 
            error_message = "N not equal to the number of weights provided. " + \
                    "Expected {0} but received {1}".format(n,len(weights))
            raise ValueError
    except ValueError as e:
        sys.exit("ERROR: " + error_message)
    else: 
        return n, k, weights

def calculate(k,ws):
    """\
Returns the minimum weight capacity of the boat using sums of combinations
NOTE: Nothing to gain using this method
    """
    max_w = max(ws)
    weights = ws[:]
    sum_combs = _sum_combs(ws) 
    for key, value in sum_combs.items():
        print(key)
        cap = max_w + key
        if strategy(k, weights,cap): 
            return cap

def _sum_combs(ws):
    """\
Returns ordered dictionary of sum(key) and corresponding weights(value)
    """
    tmp = ws
    tmp.remove(max(ws))
    sums = {}
    for i in range(1,len(tmp)):
        for c in combinations(tmp,i):
            sums[sum(c)] = c
    return collections.OrderedDict(sorted(sums.items()))


def calculate_bf(k,ws):
    """\
Returns the minimum weight capacity of the boat using brute force
    """
    max_w = max(ws)
    while True:
        if strategy(k, ws, max_w):
            return max_w
        max_w += 1

def calculate_bs(k,ws):
    """\
Returns the minimum weight capacity of the boat using "binary search"
    """
    max_w = max(ws)
    low = max_w
    high = _get_high(k,ws,max_w)
    guessed = False
    while not guessed:
        if __debug__:
            print("Capacity: {0}".format(max_w))
            print("Low: {0}".format(low))
            print("High: {0}".format(high))
        if strategy(k,ws,max_w): high = max_w
        else: low = max_w
        if high - low <= 1: guessed = True
        else: max_w = (low + high)//2
    return high

def _get_high(k,ws,high):
    """\
Returns the first capcity that fits the strategy (multiplying each
concequitive cap by 2)
    """
    while(not strategy(k,ws,high)):
        high*=2
    return high

def strategy(k,ws,cap):
    """\
param k - number of courses
param ws - a list of weights
param cap - max boat capacity (weight)
    """
    if __debug__: print("Testing strategy for capacity:{0}".format(cap))
    ws = sorted(ws, reverse = True)
    weights = ws[:]
    for i in range(1,k):
        if __debug__: print("Course #{0}".format(i))
        w = 0
        wl = []
        # NOTE: Funny things happen if you try to remove an
        # element whilst traversing a list. Don't do it.
        for x in weights:
            # That's why you use a different one. There should be
            # a smarter way to achieve this. ws = what's left
            if x in ws:
                if __debug__: print("{0} + {1}".format(w,x))
                w += x
                if __debug__: print(cap)
                if w > cap:
                    w -= x
                else:
                    wl.append(x)
                    ws.remove(x)
        if __debug__: print("Boat #{0}:{1}".format(i,wl))
    if __debug__: print("Boat #{0}:{1}".format(k,ws))
    if sum(ws) > cap:
        return False
    else: 
        return True

def test():
    print("""\
Enter input in the following format:
-------------------------------------------------------------------------------
<number of goats> <number of courses>
<weight of goat 1> <weight of goat 2> ... <weight of goat N>
-------------------------------------------------------------------------------

Example:
-------------------------------------------------------------------------------
6 2
26 7 10 30 5 4
-------------------------------------------------------------------------------
""")
    n, k, weights = handle_input()
    start_time = time.time()
    min_cap = calculate_bs(k,weights)
    print("Output:")
    print(min_cap)
    print("--- %s seconds ---" % (time.time() - start_time))

if __name__ == "__main__":
    test()
   

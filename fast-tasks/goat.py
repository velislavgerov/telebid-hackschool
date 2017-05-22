from itertools import combinations
import collections
import math
import sys

def handle_input():
    try:
        error_message = "Invalid format"
        print("Input:")
        fl = input()
        n, k = [int(x) for x in fl.split(" ")]
        if n <= 0 or n >= 1001: 
            error_message = "Invalid value for N. (1<=N<=1000)"
            raise ValueError
        if k <= 0 or k >= 1001: 
            error_message = "Invalid value for K. (1<=K<=1000)"
            raise ValueError
        sl = input()
        weights = [int(x) for x in sl.split(" ")]
        # check for correct number of weights
        for w in weights:
            if w <= 0 or w >= 100000: 
                error_message = "Invalid weight value (W). (1<=W<=100000)"
                raise ValueError
        if len(weights) != n: 
            error_message = "N not equal to number of weights. Expected {0} received {1}".format(n,len(weights))
            raise ValueError
    except ValueError as e:
        sys.exit(error_message)
    else: 
        return n, k, weights

def _sum_combs(ws):
    # Return ordered dictionary of sum(key) and corresponding weights(value)
    tmp = ws
    tmp.remove(max(ws))
    sums = {}
    for i in range(1,len(tmp)):
        for c in combinations(tmp,i):
            sums[sum(c)] = c
    return collections.OrderedDict(sorted(sums.items()))

def calculate(k,ws):
    # Returns the minimum weight capacity of the boat
    max_w = max(ws)
    weights = ws.copy()
    sum_combs = _sum_combs(ws) 
    for key, value in sum_combs.items():
        cap = max_w + key
        if strategy(k, weights,cap): 
            return cap

def calculate_bf(k,ws):
    # Returns the minimum weight capacity of the boat
    max_w = max(ws)
    while True:
        if strategy(k, ws, max_w):
            return max_w
        max_w += 1

def strategy(k,ws,cap):
    # param k - number of courses
    # param ws - a list of weights
    # param max_w - max boat capacity (weight)
    if __debug__: print("Testing strategy for capacity:{0}".format(cap))
    ws = sorted(ws, reverse = True)
    weights = ws.copy()
    for i in range(1,k):
        if __debug__: print("Course #{0}".format(i))
        w = 0
        wl = []
        for x in weights:
            if x in ws:
                if __debug__: print("{0} + {1}".format(w,x))
                w += x
                if __debug__: print(cap)
                if w > cap:
                    w -= x
                else:
                    wl.append(x)
                    ws.remove(x)
        if __debug__: print("Boat:{0}".format(wl))
    if __debug__: print(ws)
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
    min_cap = calculate(k, weights)
    print("Output:")
    print(min_cap)

if __name__ == "__main__":
    test()
   

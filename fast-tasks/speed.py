from __future__ import division # Python 2.7 compatibility 
import math
import sys
import time

def handle_input():
    try:
        error_message = "Invalid input format"
        print("Input:")
        if (sys.version_info > (3, 0)): fl = input()
        else: fl = raw_input() # Python 2 compatibility
        # N, M
        N, M = [int(x) for x in fl.split(" ")]
        if N < 2 or N > 1000: 
            error_message = "Invalid value {0} for N. (1<=N<=1000)".format(n)
            raise ValueError
        if M < 1 or M > 10000: 
            error_message = "Invalid value {0} for M. (1<=K<=1000)".format(k)
            raise ValueError
        
        roads = []
        cities = set()
        speeds = set()
        for i in range(0,M):
            if (sys.version_info > (3, 0)): sl = input()
            else: sl = raw_input() # Python 2 compatibility
            F, T, S = [int(x) for x in sl.split(" ")]
            # check for correct number:
            if F < 1 or F > N: 
                error_message = "Invalid value for F. (1<=W<={0})".format(N)
                raise ValueError
            if T < 1 or T > N: 
                error_message = "Invalid value for T. (1<=W<={0})".format(N)
                raise ValueError
            if S < 1 or S > 30000: 
                error_message = "Invalid value for S. (1<=W<=30000)"
                raise ValueError
            cities.add(F)
            cities.add(T)
            speeds.add(S)
            roads.append((F,T,S))
    except ValueError as e:
        sys.exit("ERROR: " + error_message)
    else: 
        return N, M, roads, speeds, cities

def filter_roads(roads,s_min,s_max):
    new_roads = roads[:]
    for x in roads:
        if s_min > x[2] or s_max < x[2]:
            new_roads.remove(x)
    return new_roads

if __name__ == "__main__":
    N, M, roads, speeds,cities = handle_input()
    S_min = min(speeds)
    S_max = max(speeds)
    print("Speeds: {0}".format(speeds))
    print("S_min: {0}".format(S_min))
    print("S_max: {0}".format(S_max))
    # Filter roads
    print(filter_roads(roads,3,7))
    # Try each road

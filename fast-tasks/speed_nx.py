from __future__ import division # Python 2.7 compatibility 
import math
import sys
import time
import networkx as nx

def handle_input():
    g = nx.Graph()
    try:
        error_message = "Invalid input format"
        print("Input:")
        if (sys.version_info > (3, 0)): fl = input()
        else: fl = raw_input() # Python 2 compatibility
        N, M = [int(x) for x in fl.split(" ")]
        if N < 2 or N > 1000: 
            error_message = "Invalid value {0} for N. (1<=N<=1000)".format(n)
            raise ValueError
        if M < 1 or M > 10000: 
            error_message = "Invalid value {0} for M. (1<=K<=1000)".format(k)
            raise ValueError
        for i in range(0,M):
            if (sys.version_info > (3, 0)): sl = input()
            else: sl = raw_input() # Python 2 compatibility
            F, T, S = [int(x) for x in sl.split(" ")]
            if F < 1 or F > N: 
                error_message = "Invalid value for F. (1<=W<={0})".format(N)
                raise ValueError
            if T < 1 or T > N: 
                error_message = "Invalid value for T. (1<=W<={0})".format(N)
                raise ValueError
            if S < 1 or S > 30000: 
                error_message = "Invalid value for S. (1<=W<=30000)"
                raise ValueError
            g.add_edge(F,T,weight=S)
    except ValueError as e:
        sys.exit("ERROR: " + error_message)
    else: 
        return N, M, g

if __name__ == "__main__":
    N, M, g = handle_input()
    t = nx.minimum_spanning_tree(g)
    s = []
    for x in t.edges(data='weight'):
        s.append(x[2])
    print("Output:\r\n{} {}".format(min(s),max(s)))

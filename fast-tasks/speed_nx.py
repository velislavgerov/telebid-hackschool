import sys
import time
import networkx as nx

def handle_input():
    g = nx.MultiGraph()
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
            g.add_edge(F,T,key=S,weight=S)
    except ValueError as e:
        sys.exit("ERROR: " + error_message)
    else: 
        return N, M, g

if __name__ == "__main__":
    N, M, G = handle_input()
    #start_time = time.time() 
    # A dictionary to refference min, max paris by their difference
    results = {}
    # All edges sorted by their weight
    edges = sorted(G.edges(keys=True),key = lambda t: t[2])
    n_edges = len(edges)
    # For each weight
    for i in range(0,n_edges):
        # The weights of the minimum spanning edges
        w = []
        # Number of edges
        count = 0
        # Calculate minimum spanning edges
        mse = nx.minimum_spanning_edges(G)
        for x in mse:
            w.append(x[2]['weight'])
            count += 1
        # If count is right, add the values to resutls
        if count == N - 1:
            diff = max(w) - min(w)
            if diff in results:
                results[diff].append((min(w),max(w)))
            else:
                results[diff] = [(min(w),max(w))]
        else:
            break
        G.remove_edge(*edges[0][:2], key=edges[0][2])
        # We're done with this edge
        edges = edges[1:]
    # Find our best
    keys = (sorted(results))
    best = results[keys[0]]
    best = sorted(best, key = lambda k: k[0])
    #print(results)
    #print(best)
    print("Output:\r\n{} {}".format(best[0][0],best[0][1]))
    #print("--- %s seconds ---" % (time.time() - start_time))
   


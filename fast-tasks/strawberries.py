from __future__ import print_function

import sys
import numpy
import copy

first_line = sys.stdin.readline()
try:
    K, L, R = [int(x) for x in first_line.split()]
except:
    print("Invalid input format.", file=sys.stderr)
    sys.exit(1)

if not 0 < K <= L <= 1000 or not 0 < R <= 100:
    print("Input value(s) out of the allowed range(s).", file=sys.stderr)
    sys.exit(1)

grid = numpy.zeros((K, L))

while 1:
    line = sys.stdin.readline()
    if line == "\n" or line == "\r\n": break
    
    try:
        k, l = [int(x) for x in line.split()]
    except:
        print("Invalid input format.", file=sys.stderr)
        sys.exit(1)
    
    if not 0 < k <= K  or not 0 < l <= L:
        print("Input value(s) out of the allowed range(s).", file=sys.stderr)
        sys.exit(1)
    
    grid[K-k][l-1] = 1

for i in range(R):
    new_grid = copy.deepcopy(grid)
    for n in range(K):
        for m in range(L):
            if grid[n][m] == 1:
                if n != 0:
                    new_grid[n-1][m] = 1
                if n != K-1:
                    new_grid[n+1][m] = 1
                if m != 0:
                    new_grid[n][m-1] = 1
                if m != L-1:
                    new_grid[n][m+1] = 1    
    grid = new_grid

print(K*L - numpy.count_nonzero(grid))

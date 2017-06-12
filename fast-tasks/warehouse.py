import sys
if sys.version[0] == 2: input = raw_input

def handle_input():
    try:
        N = int(input())
        if not 1 <= N <= 100: raise ValueError
    except (NameError, ValueError):
        print("N should be a number between 1 and 100")
        sys.exit(1)
    M = []
    for i in range(0, N):
        line = sys.stdin.readline()
        line = line.strip()
        try:
            line = [int(x) for x in line.split(' ')]
        except (NameError, ValueError):
            print("Invalid value detected")
            sys.exit(1)
        if len(line) != N:
            print("Line length should be equal to N")
            sys.exit(1)
        for x in line:
            if x != 0 and x != 1:
                print("x should be either 0 or 1 (got {})".format(x))
                sys.exit(1)
        M.append(line)
    return M, N

def main():
    print("Input")
    m, n = handle_input()

    # Find exits
    exit_r = [] #row
    exit_c = [] #column
    for i in range(0, n):
        r = m[i][0]
        c = m[0][i]
        if r == 0: exit_r.append(i)
        if c == 0: exit_c.append(i)
    
    # Find paths
    n_paths = 0
    # Find horizontal pahts
    for exit in exit_r:
        for i in range(0, n):
            if m[exit][i] != 0: break
            if i == n - 1: n_paths += 1
    # Find vertical paths
    for exit in exit_c:
        for i in range(0, n):
            if m[i][exit] != 0: break
            if i == n - 1: n_paths += 1
    
    # Find groups (analyze by row)
    groups = []
    group = []
    is_group = False
    for row in range(0, n):
        for col in range(0, n):
            if m[row][col] == 1:
                if not is_group: 
                    group = []
                    is_group = True
                    groups.append(group)
                if is_group:
                    group.append((row, col))
            else:
                if is_group: is_group = False
        is_group = False
    
    # Analyze groups by column
    n_groups = 0
    sizes = {len(x) for x in groups}
    for s in sizes:
        cur = [x for x in groups if len(x) == s]
        group = True
        count = 1
        first = cur[0][0][0]
        for x in cur:
            if x[0][0] == first: continue
            else:
                if x[0][0] - first > 1: 
                    group = False
                    n_groups += 1
        if group: n_groups += 1

    print("Output")
    print("{} {}".format(n_groups, n_paths))

if __name__ == '__main__':
    main()

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
    m_b = m[:]
    #print(m)

    #Check paths
    exit_r = [] #Exit indexes
    exit_c = []
    for i in range(0, n):
        r = m[i][0]
        c = m[0][i]
        if r == 0: exit_r.append(i)
        if c == 0: exit_c.append(i)
    
    #print(exit_r)
    #print(exit_c)

    n_exit = 0
    #Find horizontal exits
    for exit in exit_r:
        for i in range(0, n):
            if m[exit][i] != 0: break
            if i == n - 1: n_exit += 1
    #Find vertical exits
    for exit in exit_c:
        for i in range(0, n):
            if m[i][exit] != 0: break
            if i == n - 1: n_exit += 1
    #print(n_exit)

    groups = []
    n_groups = 0
    tuples = []
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
        #print(groups)
    
    #Analyze gorups
    n_groups = 0
    sizes = {len(x) for x in groups}
    for s in sizes:
        cur = [x for x in groups if len(x) == s]
        #print(cur)
        group = True
        count = 1
        first = cur[0][0][0]
        #print("First: {}".format(first))
        for x in cur:
            if x[0][0] == first: continue
            else:
                if x[0][0] - first > 1: 
                    group = False
                    n_groups += 1
        if group:  n_groups += 1

    print("Output")
    print(n_groups, n_exit)

if __name__ == '__main__':
    main()

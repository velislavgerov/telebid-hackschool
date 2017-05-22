from collections import deque

def handle_input():
    try:
        fl = input("Брой козички и максимален брой курсове - N K: ")
        n, k = [int(x) for x in fl.split(" ")]
    except ValueError:
        print("Невалиден формат")
        return
    try:
        sl = input("Теглата на козичките - A1 A2 ... AN: ")
        ws = [int(x) for x in sl.split(" ")]
        if len(ws) != n: raise ValueError
    except ValueError:
        raise
        print("Броят на козичките не съвпада с въведените тегла")
        return
    return n, k, ws

def calculate_k(n, k, ws):
    ws = sorted(ws)
    max_w = max(ws)
   
def strategy(k,ws,max_w):
    w, count = 0, 1
    wl = []
    for i in range(0,k):
        count += 1
        for x in ws:
            w += x
            if w > max_w:
                w -= x
            else:
                wl.append(x)
                ws.remove(x)
        if sum(ws) <= max_w: break
    if sum(ws) > max_w : return True
    else: return True

if __name__ == "__main__":
    n, k, ws = handle_input()
    calculate_k(n, k , ws)

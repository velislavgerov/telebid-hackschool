#!/usr/bin/env python
from python_ping import ping
import gevent
from gevent import Greenlet

import json

def pinger(host, pings):
    p = ping.Ping(host.lstrip('http://'), timeout=3000, quiet=False, silent=False, ipv6=False)
    stats = p.run(int(pings))


if __name__ == '__main__':
    file = open('tests/tbmon.json', 'r')
    from pprint import pprint
    data = json.load(file)
    threads = []
    for x in data['applications']:
        print(data['applications'][x])
        for i in data['applications'][x]['pings']:
            host = data['applications'][x]['pings'][i]['address']
            threads.append(gevent.spawn(pinger, host, i))
    print(threads)
    file.close()
    gevent.joinall(threads)
    print('Completed')

class Application(object):
    def __init__(self, data):
        self.data = data

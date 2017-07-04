#!/usr/bin/env python
from python_ping import ping
import gevent
from gevent import Greenlet

import json

def pinger(host, pings):
    p = ping.Ping(host.lstrip('http://'), timeout=3000, quiet=False, silent=False, ipv6=False)
    stats = p.run(int(pings))

def sync_ping():
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

class HTTPConfig(object):
    def __init__(self, data):
        self.data = data
        self.applications = [key for key in data['applications']]

def main():
    import gevent.pool
    import json

    from geventhttpclient import HTTPClient
    from geventhttpclient.url import URL

    import os
    import time
    
    script_path = os.path.dirname(__file__)
    rel_file_path = 'tests/http_ping_input_configuration.json'
    abs_path = os.path.join(script_path, rel_file_path)
    with open(abs_path, 'r') as file:
        data = json.load(file)
    c = HTTPConfig(data)
    print(c.applications)
    for a in data['applications']:
        name = data['applications'][a]['name']
        pings = data['applications'][a]['pings']

        for p in pings:
            name = pings[p]['name']
            url = URL(pings[p]['url'])
            #basic auth username
            #basic auth password
            erc = pings[p]['expected_response_codes']
            ehd = pings[p]['expected_headers']
            erb = pings[p]['expected_response_body'][0]
            http = HTTPClient(url.host)
            response = http.get(url.request_uri)
            if response.status_code in [int(x) for x in erc]:
                print("yes")
            else:
                print("no")
            for x, y in [x.split(':',1) for x in ehd]:
                if y == response._headers_index.get_all(x)[0]:
                    print("yes")
                else:
                    print("no")
            body = response.read() # bytes
            if erb.encode() in body:
                print("yes")
            else:
                print("no")
            timestamp = int(time.time())
            print(timestamp)


if __name__ == '__main__':
    main()



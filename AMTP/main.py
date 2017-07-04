#!/usr/bin/env python
import gevent.pool
import json

from geventhttpclient import HTTPClient
from geventhttpclient.url import URL

import os
import time
import re
from subprocess import Popen, PIPE

REQUEST_TIMEOUT = 100
REQUESTS_COUNT = 1

class Ping(object):
    """
    A class to work with our ping object as specified in TBMON
    """
    def __init__(self, data):
        """
        Accepts a single TBMON ping object and creates our http object
        """
        # TODO: validate data
        self.data = data
        
        try:
            self.request_timeout = float(data['request_timeout'])
        except KeyError:
            self.request_timeout = REQUEST_TIMEOUT
        try:
            self.requests_count = int(data['requests_count'])
        except KeyError:
            self.requests_count = REQUESTS_COUNT
        
        self.url = URL(data['url'])
        self.http = HTTPClient(self.url.host, connection_timeout=self.request_timeout)

    def run(self):
        """
        Main ping logic - answers to items query
        """
        print("Ping started ({})".format(self.data['name']))
        
        # do the ping
        res = self.get_response()

        # do the tests
        is_erc = self._test_expected_response_codes(res)
        is_ehd = self._test_expected_header(res)
        body = res.read() # bytes
        is_erb = self._test_expected_body(body)
        
        if __debug__:
            print("Testing expected status code - {}".format(
                "OK" if is_erc else "FAIL"))
            print("Testing expected header      - {}".format(
                "OK" if is_ehd else "FAIL"))
            print("Testing expected body        - {}".format(
                "OK" if is_erb else "FAIL"))

        if is_erc and is_ehd and is_erb:
            #print("continue")
            #print(self.data['items'])
            #self.do_request_loss()
            #print(self.data['items']['request_loss'])
            #print(self.url)
            #self.do_ab_test()
            for key in self.data['items']:
                eval('self.do_' + key + '()')
            #print(self.data)
    
    def get_response(self):
        """
        Makes a request and returns a geventhttpclient response object
        """
        return self.http.get(self.url.request_uri)
    
    def do_request_loss(self):
        """
        Does the request loss test. Results are written in self.data
        """
        successful = 0
        failed = 0
        for i in range(self.requests_count):
            res = self.get_response()
            body = res.read()
            if self.do_response_tests(res, body):
                successful += 1
            else:
                failed += 1
        timestamp = int(time.time())
        self.data['items']['request_loss']['timestamp'] = timestamp
        self.data['items']['request_loss']['units'] = '%'
        self.data['items']['request_loss']['type'] = 'int'
        self.data['items']['request_loss']['value'] = int(successful / self.requests_count * 100)
    
    def do_response_tests(self, response, body):
        is_erc = self._test_expected_response_codes(response)
        is_ehd = self._test_expected_header(response)
        is_erb = self._test_expected_body(body)
        
        if __debug__:
            print("Testing expected status code - {}".format(
                "OK" if is_erc else "FAIL"))
            print("Testing expected header      - {}".format(
                "OK" if is_ehd else "FAIL"))
            print("Testing expected body        - {}".format(
                "OK" if is_erb else "FAIL"))

        if is_erc and is_ehd and is_erb:
            return True
    
    def do_ab_test(self):
        if __debug__:
            print("Starting ab test")
        c = self.data['items']['ab_test']['concurrency']
        n = self.data['items']['ab_test']['requests']

        # TODO: What happens if we don't have ab on the system?
        p = Popen(['ab', '-n', n, '-c', c, str(self.url)], stdout=PIPE)
        output, err = p.communicate()
        rc = p.returncode
        output = output.decode('utf-8')
        if __debug__:
            print(output)
        
        rps = None
        for line in output.split("\n"):
            if "Requests per second" in line:
                line = line.split()
                rps = line[3]
                break
        
        timestamp = int(time.time())
        self.data['items']['ab_test']['timestamp'] = timestamp
        self.data['items']['ab_test']['units'] = 'r/sec'
        self.data['items']['ab_test']['type'] = 'float'
        self.data['items']['ab_test']['value'] = float(rps)


    def _test_expected_response_codes(self, response):
        """
        Returns True if one of the specified response codes is in the response
        
        :response - geventhttpclient response object
        """
        if response.status_code in [int(x) for x in self.data['expected_response_codes']]:
            return True
        else:
            return False
    
    def _test_expected_header(self, response):
        """
        Returns True if one of the expected headers is in the response headers
        
        :response - geventhttpclient response object
        """
        for field, value in [x.split(':',1) for x in self.data['expected_headers']]:
            if value == response._headers_index.get_all(field)[0]:
                return True
        return False

    def _test_expected_body(self, response_body):
        """
        Returns True if the string specified is to be found in the body of the response
        
        :response_body - byte string containing the body of the HTTP response
        """
        return True if self.data['expected_response_body'][0].encode() in response_body else False

class HTTPPinger(object):
    """
    Our main application object. Responsible for managing and conducting the pings
    """

    def __init__(self, data):
        """
        :data - dictionary object parsed from a TBMON json file
        """
        # TODO: validate data
        self.data = data
    
    def get_json(self):
        """
        Returns a JSON string deserilized from self.data
        """
        return json.dumps(self.data)

    def run(self):
        ping_objects = []
        for a in self.data['applications']:
            name = self.data['applications'][a]['name']
            pings = self.data['applications'][a]['pings']
            
            for p in pings:
                ping = Ping(pings[p])
                ping.run()
                self.data['applications'][a]['pings'][p] = ping.data
                #ping_objects.append(ping)
        
        #for x in ping_objects:
        #    x.run()
            
def main():      
    script_path = os.path.dirname(__file__)
    rel_file_path = 'tests/input.json'
    abs_path = os.path.join(script_path, rel_file_path)
    with open(abs_path, 'r') as file:
        data = json.load(file)
    http_pinger = HTTPPinger(data)
    http_pinger.run()

    rel_file_path = 'tests/output.json'
    out_path = os.path.join(script_path, rel_file_path)
    with open(out_path, 'w') as outfile:
        json.dump(http_pinger.data, outfile)

if __name__ == '__main__':
    main()

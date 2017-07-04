#!/usr/bin/env python
import gevent.pool
import json

from geventhttpclient import HTTPClient
from geventhttpclient.url import URL

import os
import time

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
            self.requests_count = float(data['request_timeout'])
        except KeyError:
            self.requests_count = REQUESTS_COUNT
        
        self.url = URL(data['url'])
        self.http = HTTPClient(self.url.host, connection_timeout=self.request_timeout)

   
    def get_response(self):
        """
        Makes a request and returns a geventhttpclient response object
        """
        return self.http.get(self.url.request_uri)

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
    
    def run(self):
        for a in self.data['applications']:
            name = self.data['applications'][a]['name']
            pings = self.data['applications'][a]['pings']

            for p in pings:
                name = pings[p]['name']
                print("Ping started ({})".format(name))

                # create our ping object
                ping = Ping(pings[p])

                # do the ping
                res = ping.get_response()

                # do the tests
                is_erc = ping._test_expected_response_codes(res)
                is_ehd = ping._test_expected_header(res)
                body = res.read() # bytes
                is_erb = ping._test_expected_body(body)
                
                if __debug__:
                    print("Testing expected status code - {}".format(
                        "OK" if is_erc else "FAIL"))
                    print("Testing expected header      - {}".format(
                        "OK" if is_ehd else "FAIL"))
                    print("Testing expected body        - {}".format(
                        "OK" if is_erb else "FAIL"))

                if is_erc and is_ehd and is_erb:
                    print("continue")
                timestamp = int(time.time())
                print(timestamp) 

def main():      
    script_path = os.path.dirname(__file__)
    rel_file_path = 'tests/http_ping_input_configuration.json'
    abs_path = os.path.join(script_path, rel_file_path)
    with open(abs_path, 'r') as file:
        data = json.load(file)
    http_pinger = HTTPPinger(data)
    http_pinger.run()

if __name__ == '__main__':
    main()

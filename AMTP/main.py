#!/usr/bin/env python
import gevent.pool
import json

from geventhttpclient import HTTPClient
from geventhttpclient.url import URL

import os
import time

class Ping(object):
    """
    A class to work with our ping object as specified in TBMON
    """
    def __init__(self, data):
        """
        Accepts a single TBMON ping object
        """
        # TODO: validate data
        self.data = data


class HTTPPinger(object):
    """
    Our main application object. Responsible for managing and conducting the pings
    """
    REQUEST_TIMEOUT = 100
    REQUESTS_COUNT = 1

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
                url = URL(pings[p]['url'])
                erc = pings[p]['expected_response_codes']
                ehd = pings[p]['expected_headers']
                erb = pings[p]['expected_response_body'][0]
                try:
                    timeout = float(pings[p]['request_timeout'])
                except KeyError:
                    timeout = self.REQUEST_TIMEOUT
                try:
                    requests_count = float(pings[p]['request_timeout'])
                except KeyError:
                    requests_count = self.REQUESTS_COUNT

                # making a request
                http = HTTPClient(url.host, connection_timeout=timeout)
                res = http.get(url.request_uri)
                
                # do the tests
                is_erc = self._test_expected_response_codes(erc, res)
                is_ehd = self._test_expected_header(ehd, res)
                body = res.read() # bytes
                is_erb = self._test_expected_body(erb, body)
                
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


    def _test_expected_response_codes(self, expected_response_codes, response):
        """
        Returns True if one of the specified response codes is in the response
        
        :expected_response_codes - array of strings corresponing to HTTP status codes
        :response - geventhttpclient response object

        """
        if response.status_code in [int(x) for x in expected_response_codes]:
            return True
        else:
            return False
    
    def _test_expected_header(self, expected_headers, response):
        """
        Returns True if one of the expected headers is in the response headers

        :expected_headers - array of strings in the '{field:value}' format
        :response - geventhttpclient response object
        """
        for field, value in [x.split(':',1) for x in expected_headers]:
            if value == response._headers_index.get_all(field)[0]:
                return True
        return False

    def _test_expected_body(self, expected_body, response_body):
        """
        Returns True if the string specified is to be found in the body of the response
        
        :expected_body - string content to be found in the response body
        :response_body - byte string containing the body of the HTTP response
        """
        return True if expected_body.encode() in response_body else False




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

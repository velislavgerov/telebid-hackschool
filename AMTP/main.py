#!/usr/bin/env python
from __future__ import print_function

import gevent.pool
import json

from geventhttpclient import HTTPClient
from geventhttpclient.url import URL

import os
import sys
import time
import re
import argparse
from pprint import pprint
from subprocess import Popen, PIPE

if sys.version[0] == "2":
    input = raw_input

REQUEST_TIMEOUT = 100
REQUESTS_COUNT = 1
VERBOSE = False

class Ping(object):
    """
    A class to work with our ping object as specified in TBMON
    """
    def __init__(self, application, ping,  data):
        """
        Accepts a single TBMON ping object and it's corresponding application
        """
        self.application = application
        self.ping = ping
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
        if VERBOSE:
            print("Ping started ({})".format(self.data['name']))
        
        # do the ping
        res = self.get_response()

        # do the tests
        is_erc = self._test_expected_response_codes(res)
        is_ehd = self._test_expected_header(res)
        body = res.read() # bytes
        is_erb = self._test_expected_body(body)
         
        if VERBOSE:
            print("Initial response test results for {}".format(self.data['name']))
            print("Testing expected status code - {}".format(
                "OK" if is_erc else "FAIL"))
            print("Testing expected header      - {}".format(
                "OK" if is_ehd else "FAIL"))
            print("Testing expected body        - {}".format(
                "OK" if is_erb else "FAIL"))

        if is_erc and is_ehd and is_erb:
            for key in self.data['items']:
                eval('self.do_' + key + '()') # XXX: POF
    
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
            if self.do_response_tests(res, body, i):
                successful += 1
            else:
                failed += 1
        timestamp = int(time.time())
        self.data['items']['request_loss']['timestamp'] = timestamp
        self.data['items']['request_loss']['units'] = '%'
        self.data['items']['request_loss']['type'] = 'int'
        self.data['items']['request_loss']['value'] = int(failed / self.requests_count * 100)
    
    def do_response_tests(self, response, body, i=None):
        """
        Does all of the expected_* tests (should be executed to validate the response)
        """
        is_erc = self._test_expected_response_codes(response)
        is_ehd = self._test_expected_header(response)
        is_erb = self._test_expected_body(body)
        
        if VERBOSE:
            print("Request loss test #{} results for {}".format(i+1, self.data['name']))

            print("Testing expected status code - {}".format(
                "OK" if is_erc else "FAIL"))
            print("Testing expected header      - {}".format(
                "OK" if is_ehd else "FAIL"))
            print("Testing expected body        - {}".format(
                "OK" if is_erb else "FAIL"))

        if is_erc and is_ehd and is_erb:
            return True
    
    def do_ab_test(self):
        """
        Spawns an apache bench process and performs loadtesting
        """
        if VERBOSE:
            print("Starting ab test for {}".format(self.data['name']))
        c = self.data['items']['ab_test']['concurrency']
        n = self.data['items']['ab_test']['requests']

        # TODO: What happens if we don't have ab on the system?
        p = Popen(['ab', '-n', n, '-c', c, str(self.url)], stdout=PIPE)
        output, err = p.communicate()
        rc = p.returncode
        output = output.decode('utf-8')
        if VERBOSE:
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
        self.data = data
        self.pings = []

        if not self.validate():
            sys.exit(1)
        
        # gather out Ping objects
        for application_name in self.data['applications']:
            name = self.data['applications'][application_name]['name']
            pings = self.data['applications'][application_name]['pings']

            for ping_name in pings:
                ping = Ping(application_name, ping_name, pings[ping_name])
                self.pings.append(ping)

    def dump(self, file=None):
        """
        Dumps the current TBMON json data to stdin or to a file if specified
        :file(optional) - file object used to dump the TBMON data
        """
        if VERBOSE:
            print('TBMON output:{}'.format(self.dump_json()))
        else:
            if file:
                self.dump_json(file)
            else:
                print(self.dump_json())

    def dump_json(self, file=None):
        """
        Returns a JSON string deserilized from self.data
        Optionally dumps JSON to a file
        """ 
        if file:
            json.dump(self.data, file)
        else:
            return json.dumps(self.data)

    def run(self):
        pool = gevent.pool.Pool(20)
        for x in self.pings:
            pool.spawn(x.run)
        pool.join()

    def validate(self, data=None):
        """
        Returns True if TBMON data matches the specification for HTTP Pinger
        If no data was specified, validates the data belonging to the object
        :data(optional) - deserialized JSON object to be validated as TBMON
        """
        
        if not data:
            data = self.data

        if not 'applications' in data:
            print("TBMON error: 'applications' array is required", file=sys.stderr)
            return False
        
        applications = data['applications']

        if not len(applications) >= 1:
            print("TBMON error: there are no 'application' objects in the 'applications' array"\
                    , file=sys.stderr)
            return False
        
        for application_name in applications:
            application = applications[application_name]
        
            if not 'name' in application:
                print("TBMON error ({}): the 'name' string ".format(application_name) + 
                    "is required in an application object", file=sys.stderr)
                return False

            if not 'pings' in application:
                print("TBMON error ({}): the 'pings' array ".format(application_name) + 
                    "is required in an application object", file=sys.stderr)
                return False
            
            pings = application['pings']
            
            if not len(pings) >= 1:
                print("TBMON error ({}): there are no 'ping' objects the 'pings'array "\
                        .format(application_name) + "is required in an application object"\
                        , file=sys.stderr)
                return False

            for ping_name in pings:
                ping = pings[ping_name]

                if not 'name' in ping:
                    print("TBMON error ({}:{}): ".format(application_name, ping_name) + 
                        "the 'name' string is required in a ping object", file=sys.stderr)
                    return False

                if not 'url' in ping:
                    print("TBMON error ({}:{}): ".format(application_name, ping_name) + 
                        "the 'url' string is required in a ping object", file=sys.stderr)
                    return False

                if not 'items' in ping:
                    print("TBMON error ({}:{}): ".format(application_name, ping_name) + 
                        "the 'items' array is required in a ping object", file=sys.stderr)
                    return False

                items = ping['items']

                if not len(items) >= 1:
                    print("TBMON error ({}:{}): ".format(application_name, ping_name) + 
                        "there are no 'item' objects in the 'items' array", file=sys.stderr)
                    return False

                for item_name in items:
                    item = items[item_name]

                    if not 'name' in item:
                        print("TBMON error ({}:{}:{}): ".format(application_name, ping_name,\
                            item_name) + "the 'name' string is required in an item object",\
                            file=sys.stderr)
                        return False
        return True


def get_inputs():
    """
    Returns a tuple of input file path and output file path  specified as 
    command line arguments. Additionally sets the VERBOSE mode if defined
    """
    
    # prepare parser
    parser = argparse.ArgumentParser(description="""\
Asynchronous Multi Target Pinger (AMTP)
""")
    parser.add_argument('-v', '--verbose', help='display additional information', action='store_true')
    parser.add_argument('-o', '--output', metavar="FILE", nargs=1, help='specify path to output the TBMON result file', default='stdout')
    requiredNamed = parser.add_argument_group('required arguments')
    requiredNamed.add_argument('-c', '--config', metavar="FILE", nargs=1, type=str, help='specify path to a TBMON configuration file', required=True)
    args = parser.parse_args()
    
    # set verbosity
    global VERBOSE
    VERBOSE = args.verbose

    # input file path [required]
    input_file_path = args.config[0]
    if not os.path.isabs(input_file_path):
        cwd = os.getcwd()
        file_path = os.path.join(cwd, input_file_path)
    if not os.path.isfile(file_path):
        print('{}: error: {} is not a file'.format(__file__, input_file_path),
                file=sys.stderr)
        sys.exit()

    # output file path [optional]
    if args.output[0] == 'stdout':
        output_file_path = None
    else:
        output_file_path = args.output[0]
        if not os.path.isabs(output_file_path):
            cwd = os.getcwd()
            output_file_path = os.path.join(cwd, output_file_path)
        if os.path.isfile(output_file_path):
            answer = str(input('The file {} already exists. '.format(output_file_path) +
                'Do you wish to continue and overwrite it? [Y/n] '))
            if not answer.lower() == 'y' or answer.lower() == 'yes':
                sys.exit()
        if os.path.isdir(output_file_path):
            print('{}: error: {} is a directory'.format(__file__, output_file_path),
                    file=sys.stderr)
            sys.exit()
    
    return input_file_path, output_file_path


def main():      
    inputs = get_inputs()
    with open(inputs[0], 'r') as file:
        data = json.load(file)
    http_pinger = HTTPPinger(data)
    http_pinger.run()
    if inputs[1]:
        with open(inputs[1], 'w') as file:
            http_pinger.dump(file)
    else:
        http_pinger.dump()

if __name__ == '__main__':
    main()

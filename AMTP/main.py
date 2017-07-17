#!/usr/bin/env python
from __future__ import print_function

from jsonschema import validate
from gevent.pool import Pool
import gevent.socket

from geventhttpclient import HTTPClient
from geventhttpclient.url import URL
from geventhttpclient._parser import HTTPParseError

import os
import sys
import time
import re
import argparse
from pprint import pprint
from subprocess import Popen, PIPE
import json


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
        
        url = data['url']
        
        # check whether protocol is present
        if isinstance(url, str):
            if not str.startswith(url, 'http://') or not str.startswith(url, 'https://'):
                url = 'http://' + url
        else:
            raise TypeError("invalid type for url")
        self.url = URL(url)
        self.http = HTTPClient.from_url(self.url, concurrency=500)
        self.http.connection_timeout=self.request_timeout
    
    def run(self):
        """
        Main ping logic - answers to items query
        """
        if VERBOSE:
            print("Ping started ({})".format(self.data['name']))
        
        # check if hostname resolves
        #try:
        #    gevent.socket.gethostbyname(self.url.host)
        #except gevent.socket.error:
        #    print('{}: error: hostname {} does not resolve'.format(__file__, self.url.host), file=sys.stderr)

        for key in self.data['items']:
            try:
                eval('self.do_' + key + '()')
            except AttributeError:
                print("{}: HTTPPinger does not support item '{}'". format(__file__, key), file=sys.stderr)
        
        self.http.close()

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
        res = None
        body = None
        for i in range(self.requests_count):
            try:
                res = self.get_response()
                body = res.read()
            except gevent.socket.error:
                failed += 1
            except HTTPParseError as err:
                print(err, self.url, file=sys.stderr)
                failed += 1
            if res and body:
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
        is_erc, is_ehd, is_erb = True, True, True

        if 'expected_response_codes' in self.data:
            is_erc = self._test_expected_response_codes(response)
            if VERBOSE:
                print("Testing expected status code - {} - {}".format(" OK " if is_erc else "FAIL", self.url))
        if 'expected_headers' in self.data:
            is_ehd = self._test_expected_header(response)
            if VERBOSE:
                print("Testing expected header      - {} - {}".format(" OK " if is_ehd else "FAIL", self.url))
        
        if 'expected_response_body' in self.data:
            is_erb = self._test_expected_body(body)
            if VERBOSE:
                print("Testing expected body        - {} - {}".format(" OK " if is_erb else "FAIL", self.url))

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
        # add / to host if missing (else ab fails)
        ab_url = str(self.url)

        if self.url.path == '': 
            ab_url = str(self.url) + '/'
        try:
            p = Popen(['ab', '-n', n, '-c', c, ab_url], stdout=PIPE, stderr=PIPE)
            output, err = p.communicate()
            rc = p.returncode
        except FileNotFoundError:
            print('{}: error: could not find ab'.format(__file__, self.url.host), file=sys.stderr)
            err = 1 
        timestamp = int(time.time())
        #err = None
        if not err:
            output = output.decode('utf-8')
            if VERBOSE:
                print(output)
            
            rps = None
            for line in output.split("\n"):
                if "Requests per second" in line:
                    line = line.split()
                    rps = line[3]
                    break 
            self.data['items']['ab_test']['timestamp'] = timestamp
            self.data['items']['ab_test']['units'] = 'r/sec'
            self.data['items']['ab_test']['type'] = 'float'
            self.data['items']['ab_test']['value'] = float(rps)
        else:
            self.data['items']['ab_test']['timestamp'] = timestamp
            self.data['items']['ab_test']['units'] = 'r/sec'
            self.data['items']['ab_test']['type'] = 'float'
            self.data['items']['ab_test']['value'] = ''


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
            header_value = response._headers_index.get_all(field)
            if header_value:
                if value == header_value[0]:
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

    def __init__(self, data, schema_path=None):
        """
        :data - dictionary object parsed from a TBMON json file
        """
        self.data = data
        self.pings = []
        
        # Load TBMON HTTP Ping Schema
        schema_path = schema_path or 'schema/TBMON_HTTP_Ping_Schema.json'
        file_dir = os.path.dirname(os.path.realpath(__file__))
        rel_path = os.path.join(file_dir, schema_path)
        with open(rel_path, 'r', encoding='utf8') as json_file:
            schema = json.load(json_file)
            validate(self.data, schema)

        # gather out Ping objects
        for application_name in self.data['applications']:
            name = self.data['applications'][application_name]['name']
            pings = self.data['applications'][application_name]['pings']

            for ping_name in pings:
                ping = Ping(application_name, ping_name, pings[ping_name])
                self.pings.append(ping)
    
        self.pool = Pool(500) 
    
    def shutdown(self):
        self.pool.kill()

    def dump(self, file=None):
        """
        Dumps the current TBMON json data to stdin or to a file if specified
        :file(optional) - file object used to dump the TBMON data
        """
        if file:
            self.dump_json(file)
            if VERBOSE:
                print('TBMON output:{}'.format(self.dump_json()))
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
        for x in self.pings:
            self.pool.spawn(x.run)
        self.pool.join()


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
    parser.add_argument('-i', '--interactive', help='interactive mode', action='store_true')
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
        print('{}: error: {} is not a file'.format(os.relpath(__file__), input_file_path),
                file=sys.stderr)
        sys.exit()

    # output file path [optional]
    if args.output == 'stdout':
        output_file_path = None
    else:
        output_file_path = args.output[0]
        if not os.path.isabs(output_file_path):
            cwd = os.getcwd()
            output_file_path = os.path.join(cwd, output_file_path)
        if args.interactive:
            if os.path.isfile(output_file_path):
                print('The file {} already exists. '.format(output_file_path) +
                    'Do you wish to continue and overwrite it? [Y/n] ', end='')
                answer = str(input())
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

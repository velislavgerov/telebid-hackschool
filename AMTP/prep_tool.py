#!/usr/bin/env python
import csv
import json
import copy


with open('tests/input.json') as jsonfile:
    data = json.loads(jsonfile.read())
    data['applications']['application_key_1']['name'] = 'Ping top 500 websites'
    new = data['applications']['application_key_1']['pings']['google']
    with open('urls.csv') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            print(row['URL'])
            data['applications']['application_key_1']['pings'][str(row['Rank'])] = copy.deepcopy(new)
            cur = data['applications']['application_key_1']['pings'][str(row['Rank'])]
            cur['name'] = row['URL']
            cur['request_timeout'] = 0.5
            cur['requests_count'] = 1
            cur['url'] = row['URL']
            del cur['items']['ab_test']
            print(cur['items'])

    del data['applications']['application_key_1']['pings']['google']

    with open('tests/500.json', 'w') as file:
        json.dump(data, file)
            #data['applications']
            #print(row['URL'])



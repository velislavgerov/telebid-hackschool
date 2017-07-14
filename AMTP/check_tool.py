#!/usr/bin/env python
import csv
import json
import copy


with open('tests/500_o.json') as jsonfile:
    data = json.loads(jsonfile.read())
    for name in data['applications']['application_key_1']['pings']:
        ping = data['applications']['application_key_1']['pings'][name]
        url = ping['url']
        if 'value' in ping['items']['request_loss']:
            if ping['items']['request_loss']['value'] == 100:
                print(str(ping['items']['request_loss']['value']) + "%", url)
        else:
            print("Did not get results for:", url)

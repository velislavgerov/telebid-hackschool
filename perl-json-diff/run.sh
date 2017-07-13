#!/usr/bin/env bash
mkdir json-files/
perl tests.pl
python evaluate.py

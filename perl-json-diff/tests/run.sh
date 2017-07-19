#!/usr/bin/env bash
mkdir -p json-files/
perl tests.pl
python3 evaluate.py

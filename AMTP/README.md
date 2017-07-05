# Asynchronous Multi Target Pinger (AMTP)

AMTP is implemented in Python, levaraging the gevent library 

## Input

Parses and handles a proprietery JSON specification (TBMON)

## ICMP Pinger

Purposes:
* To test the reachability of multiple hosts
* To report errors, packet loss, and a statistical summary

## HTTP Pinger

Purposes:
* To test whether HTTP requests receive the expected response
...

### Installation and usage

Note: It's best to use a [virtualenv](https://virtualenv.pypa.io/en/stable/) when installing the required packages with pip

```
git clone https://github.com/thunderstruck47/telebid-hackschool.git
cd telebid-hackschool/AMTP/
pip install -r requirements.txt
python main.py -c <path to TBMON input file>
```

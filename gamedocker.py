#!/usr/bin/python3 

import json
import sys
import os 

jfile=sys.argv[1]
try:
    with open(jfile, 'r') as file:
        data = json.load(file)
        file.close()
except FileNotFoundError:
    print(f"Error: '{jfile}' not found.")
except json.JSONDecodeError:
    print(f"Error: Could not decode JSON from '{jfile}'.")

description = data['description']
name = data['name']
driver = f"mame{data['sourcestub']}"
w = data['width']
h = data['height']
r = int(data['rotate'])
if r == 90 or r == 270:
    w,h = h,w
scale = 3
     
docker = f"""FROM arm64v8/nginx

ADD nginx/default /etc/nginx/conf.d/default.conf

RUN mkdir -p /var/www/html /var/www/html/roms

ADD index.html *.js *.wasm *.js.map logo images /var/www/html
"""
print(docker)



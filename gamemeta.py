#!/usr/bin/python3 

import sys
import json
import re
import gzip
from xml.etree.cElementTree import parse as xmlparse

# Treat a machine as arcade if it has coin slots
def is_arcade(data):
    input = data.find('input')
    return bool(input and input.attrib.get('coins'))

def machine(data):
    attr = data.attrib
    name = attr['name']
    sourcefile = attr['sourcefile']
    sourcestub = re.sub(r"[^\/]*\/(.*)\.cpp", "\\1", sourcefile)
    desc = data.find('description').text
    year = data.find('year')
    manu = data.find('manufacturer')
    inpt = data.find('input')
    sound = data.find('sound')
    display = data.find('display')

   
    info = {}
    info['name'] = name
    info['description'] = desc
    info['sourcefile'] = sourcefile
    info['sourcestub'] = sourcestub
    if year is not None:
        info['year'] = year.text
    if manu is not None:
        info['manufacturer'] = manu.text
    if inpt is not None:
        ia = inpt.attrib
        control = inpt.find('control')
        ca = control.attrib
        if 'players' in ia:
            info['players'] = ia.get('players')
        if 'type' in ca: 
            info['type'] = ca.get('type')
        if 'buttons' in ca: 
            info['buttons'] = ca.get('buttons')
        if 'ways' in ca: 
            info['ways'] = ca.get('ways')
        if 'coins' in ia: 
            info['coins'] = ia.get('coins')
    if sound is not None:
        snda = sound.attrib
        if 'channels' in snda:
            info['channels'] = snda.get('channels')
    if display is not None:
        disa = display.attrib
        info['rotate'] = disa.get('rotate', '0')
        info['height'] = disa.get('height', '240')
        info['width'] = disa.get('width', '292')

    roms = []
    for r in data.findall('rom'):
        ra = r.attrib
        if 'crc' not in ra or 'size' not in ra:
            continue
        rinfo = {
            'name': ra['name'],
            'size': ra['size'],
            'crc': ra['crc']
        }
        if 'sha1' in ra:
            rinfo['sha1'] = ra['sha1']
        roms.append(rinfo)
    #info['roms'] = roms

    return info

def get_machine(name, data):
    path = f".//machine[@name='{name}']"
    g = data.findall(path)
    minfo = machine(g[0])
    return minfo

game = get_machine(sys.argv[2], xmlparse(sys.argv[1]).getroot())
print(json.dumps(game, indent=2))
    


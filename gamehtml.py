#!/usr/bin/python3 

import json
import sys
import os 

try:
    with open(sys.argv[1], 'r') as file:
        data = json.load(file)
        file.close()
except FileNotFoundError:
    print("Error: 'example.json' not found.")
except json.JSONDecodeError:
    print("Error: Could not decode JSON from 'example.json'.")

description = data['description']
name = data['name']
driver = f"mame{data['sourcestub']}"
w = data['width']
h = data['height']
r = int(data['rotate'])
if r == 90 or r == 270:
    w,h = h,w
scale = 3
     
html = f"""
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>{description}</title>
  </head>
  <body>
    <canvas id="canvas" style="width: 50%; height: 50%; display: block; margin: 0 auto;"></canvas>
    <script type="text/javascript" src="es6-promise.js"></script>
    <script type="text/javascript" src="browserfs.min.js"></script>
    <script type="text/javascript" src="loader.js"></script>
    <script type="text/javascript">
      var emulator = 
        new Emulator(document.querySelector("#canvas"),
                     null,
                     new MAMELoader(MAMELoader.driver("{name}"),
                                    MAMELoader.nativeResolution({w}, {h}),
                                    MAMELoader.scale({scale}),
                                    MAMELoader.emulatorWASM("{driver}.wasm"),
                                    MAMELoader.emulatorJS("{driver}.js"),
                                             MAMELoader.extraArgs(['-verbose']),
                                             MAMELoader.mountFile("{name}.zip",
                                                                  MAMELoader.fetchFile("Game File",
                                                                                       "/roms/{name}.zip"))))
      emulator.start({{ waitAfterDownloading: true }});
    </script>
  </body>
</html>
"""
print(html)



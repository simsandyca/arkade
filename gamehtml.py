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
     
html = f"""
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>{description}</title>
    <style>
      html, body {{
        padding: 0; margin: 0;
        width: 100vw; height: 100vh;
      }}
      #wrapper {{
        position: absolute;
        width: fit-content;
        background-color: black;
        padding: 0; margin: 0;
        width:  100vw; height: 100vh;
      }}
      #marquee {{
        width: 100%;
        aspect-ratio: 32 / 9;
        opacity: 0.8;
        padding: 0; margin: 0;
      }}
      #bezel {{
        position: relative;
        pointer-events: none;
        z-index: 2;
        width: 100%;
        aspect-ratio: 16 / 9;
        opacity: 0.8;
        padding: 0; margin: 0;
      }}
      #emularity {{
        position: relative;
        z-index: 1;
        padding: 0; margin: 0;
      }}
    </style>

  </head>
  <body>
    <div id="wrapper">
      <img id="marquee" src="/art/marquee/{name}.png" alt="Marquee">
      <img id="bezel" src="/art/bezel/{name}.png" alt="Bezel">
      <div id="emularity">
        <canvas id="canvas" style="margin: 0; padding: 0"></canvas>
      </div>
    </div>

    <script type="text/javascript" src="es6-promise.js"></script>
    <script type="text/javascript" src="browserfs.min.js"></script>
    <script type="text/javascript" src="loader.js"></script>
    <script type="text/javascript">
      function game_scale(nr, loader, canvas) {{
         var wrapper       = document.querySelector("#wrapper");
         var marquee       = document.querySelector("#marquee");
         var bezel         = document.querySelector("#bezel");
         var emularity     = document.querySelector("#emularity");
         var nativeAR      = nr.width / nr.height;
         var rotated       = ( {r} == 90 || {r} == 270 );

         // The Bezel art is 16:9 aspect-ration and has either a 4:3 (horizontal game) or 3:4 (vertical game)
         //  transparent hole in the middle.  The height of the game should be the same as the height of the hole
         //  (which is just the height of the art).
         //  The width of the hole depends on the aspect-ratio
         //  - for e.g. centiped in a 1920x1080 bezel art the height is just 1080 and the width is 3/4*1080
         //    The actual resolution for centiped doesn't match the aspect-ratio of the hole so the game will be a
         //    little bit streched to fit the hole...
         var game_height   = bezel.height;
         var game_width    = Math.trunc(4.0/3.0 * game_height);
         if ( rotated ) {{
            game_height   = bezel.height;
            game_width    = Math.trunc(3.0/4.0 * game_height);
         }}

         // Tell the loader to draw the game in a canvas that is the computed width x height
         // and disable any scaling since those width x height values are computed to fit
         // perfectly.
         loader.nativeResolution.width   = game_width;
         loader.nativeResolution.height  = game_height;
         loader.scale                    = 1.0;

         // The game canvas is inside a div called "emularity".
         // Position the div so that it appears in the hole in the bezel art.
         // The bezel and emularity are 'position: relative' so that they can overlap *and*
         // the emularity div is declared second.
         // Set the emularity top value "-bezel.height" so that it moves from below the bezel
         // to overlapping.
        // The left edge the emularity div is the middle of the bezel minus half the game_width
         //
         // The wrapper div provides the black background stretch that out to fit the marquee and bezel
         emularity.style.height          = game_height;
         emularity.style.width           = game_width;
         emularity.style.top             = -bezel.height;
         emularity.style.left            = Math.trunc((bezel.width - game_width)/2.0);
         wrapper.style.height            = marquee.height + bezel.height;
         wrapper.style.width             = marquee.width;

         emulator.start({{ waitAfterDownloading: false }});
      }}
      var nr = {{width: {w}, height: {h} }};
      var canvas = document.querySelector("#canvas");
      var loader = new MAMELoader(MAMELoader.driver("{name}"),
                                  MAMELoader.nativeResolution(nr.width, nr.height),
                                  MAMELoader.scale(1.0),
                                  MAMELoader.emulatorWASM("{driver}.wasm"),
                                  MAMELoader.emulatorJS("{driver}.js"),
                                  MAMELoader.extraArgs(['-verbose']),
                                  MAMELoader.mountFile("{name}.zip",
                                                       MAMELoader.fetchFile("Game File",
                                                                            "/roms/{name}.zip")));

      var emulator = new Emulator(canvas, null, loader);
      window.addEventListener('onload', game_scale(nr, loader, canvas));
      window.addEventListener('resize', function() {{ location.reload(true); }});
    </script>
  </body>
</html>
"""
print(html)



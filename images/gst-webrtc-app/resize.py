import logging
import os
import re
import subprocess
from subprocess import Popen, PIPE, STDOUT

logger = logging.getLogger("gstwebrtc_app_resize")
logger.setLevel(logging.DEBUG)

def resize_display(res):
    curr_res = res
    screen_name = "screen"
    resolutions = []

    screen_pat = re.compile(r'(\w+)? connected (\d+x\d+)\+.*')
    res_pat = re.compile(r'^(\d+x\d+)\s.*$')

    #logger.debug(str(os.environ))

    with os.popen('xrandr') as pipe:
        found_screen = False
        for line in pipe:
            screen_ma = re.match(screen_pat, line.strip())
            if screen_ma:
                found_screen = True
                screen_name, curr_res = screen_ma.groups()
            if found_screen:
                res_ma = re.match(res_pat, line.strip())
                if res_ma:
                    resolutions += res_ma.groups()

    if curr_res == res:
        logger.info("target resolution is the same, skipping resize")
        return False

    logger.info("resizing display to %s" % res)
    if res not in resolutions:
        logger.info("adding mode %s to xrandr screen '%s'" % (res, screen_name))
        w, h = [int(i) for i in res.split('x')]

        # Generate modeline, this works for Xvfb, not sure about xserver with nvidia driver
        modeline = "0.00 %s 0 0 0 %s 0 0 0 -hsync +vsync" % (w, h)

        # Create new mode from modeline
        logger.info("creating new xrandr mode: %s %s" % (res, modeline))
        cmd = ['xrandr', '--newmode', res, *re.split('\s+', modeline)]
        p = Popen(cmd, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            logger.error("failed to create new xrandr mode: '%s %s': %s%s" % (res, modeline, stdout, stderr))
            return False

        # Add the mode to the screen.
        logger.info("adding xrandr mode '%s' to screen '%s'" % (res, screen_name))
        cmd = ['xrandr', '--addmode', screen_name, res]
        p = Popen(cmd, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()
        if p.returncode != 0:
            logger.error("failed to add mode '%s' using xrandr: %s%s", (res, stdout, stderr))
            return False

    # Apply the resolution change
    logger.info("applying xrandr mode: %s" % res)
    cmd = ['xrandr', '-s', res]
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)
    stdout, stderr = p.communicate()
    if p.returncode != 0:
        logger.error("failed to apply xrandr mode '%s': %s%s" % (res, stdout, stderr))
        return False

    return True

if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO)

    if len(sys.argv) < 2:
        print("USAGE: %s WxH" % sys.argv[0])
        sys.exit(1)
    res = sys.argv[1]

    resize_display(res)
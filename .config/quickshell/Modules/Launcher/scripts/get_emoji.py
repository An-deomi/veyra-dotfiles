#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import os
import runpy

HERE = os.path.dirname(os.path.abspath(__file__))
SHARED_SCRIPT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "emoji", "get_emoji.py"))

if __name__ == "__main__":
    runpy.run_path(SHARED_SCRIPT, run_name="__main__")

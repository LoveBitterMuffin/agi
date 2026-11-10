#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os

engine_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine")
search_script = os.path.join(engine_dir, "search.py")

if not os.path.exists(search_script):
    print(f"Error: search engine not found at {search_script}", file=sys.stderr)
    sys.exit(1)

import subprocess
cmd = [sys.executable, search_script] + sys.argv[1:]
result = subprocess.run(cmd)
sys.exit(result.returncode)

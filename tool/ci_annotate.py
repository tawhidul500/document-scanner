#!/usr/bin/env python3
"""Emit the first failing-test messages from a flutter test log as CI annotations."""
import re, sys
text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
blocks = re.split(r'(?=\u2550\u2550\u2561 EXCEPTION CAUGHT)', text)
seen, n = set(), 0
for block in blocks[1:]:
    key = block[:400]
    msg = block[:3500]
    first = re.sub(r'\s+', ' ', block[100:300])
    if first in seen:
        continue
    seen.add(first)
    msg = msg.replace('%', '%25').replace('\r', '').replace('\n', '%0A')
    print('::error title=flutter test failure %d::%s' % (n + 1, msg))
    n += 1
    if n >= 8:
        break
if n == 0:
    tail = text[-3500:].replace('%', '%25').replace('\n', '%0A')
    print('::error title=flutter test log tail::' + tail)

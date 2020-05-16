#!/usr/bin/python

import sys, os, os.path, re

dir = '.'
if len(sys.argv) == 2:
  dir = sys.argv[1]

locale = os.path.join(dir, 'locale')
if not os.path.isdir(locale):
  os.mkdir(locale)
files = os.listdir(dir)
for file in files:        
  if not file.endswith('.sh'):
    continue
  filename = os.path.join(dir, file)
  f = open(filename).read()
  potname = file.split('.')[0] + '.pot'
  potname = os.path.join(locale, potname)
  pot = open(potname, 'w')
  for i,j in re.findall('.*\"`gettext -s \"((\n|.)+?)\"`\".*', f):
    pot.write("#: %s:$count\nmsgid \"%s\"\nmsgstr \"\"\n" % (file, i))
  pot.close

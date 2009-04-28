#!/usr/bin/env python
# coding: utf-8
import sys
from string import Template
from substable import segments
import codecs

sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

template = open('template.html').read().decode("utf-8")
template = Template(template)

def make_row(things):
	row = [u"<tr>"]
	for thing in things:
		row.append(u"<td>%s</td>" % thing)
	row.append(u"</tr>")
	return '\n'.join(row)

htrows = []

for segment in segments:
  source = u' '.join(segment[0])
  target = u' '.join(segment[1])
  htrows.append(make_row([source,target]))

table = [u"<table>"] + htrows +  [u"</table>"]

table = u''.join(table)

d = {
 u'rows':    table,
 u'title':   u'alignment', 
 u'css':     u'http://ruphus.com/stash/subs.css'
}

page = template.substitute(d)

print page

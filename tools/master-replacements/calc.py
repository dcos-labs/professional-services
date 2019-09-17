#!/usr/bin/env python3
"""
calculate master order
"""

import json

def calculate(masters_new, masters_old):

   masters_new = json.loads(masters_new)
   masters_old = json.loads(masters_old)

   masters_new.sort()
   masters_old.sort()

   print("Replacement Order:")

   j = 0
   while len(masters_new) > 0:
       for nm in masters_new:
           found = False
           for om in masters_old:
               if nm <= om:
                   j += 1
                   print("{0:d}: {1:s} -> {2:s}"
                       .format(j, om, nm))
                   masters_old.remove(om)
                   masters_new.remove(nm)
                   found = True
                   break
           if found == False:
               j += 1
               print("{0:d}: {1:s} -> {2:s}"
                   .format(j, max(masters_old), nm))
               masters_old.pop()
               masters_new.remove(nm)

master_list_old = '["172.16.7.200", "172.16.18.34", "172.16.42.154"]'
master_list_new = '["172.16.12.188", "172.16.30.199", "172.16.34.189"]'

calculate(master_list_new, master_list_old)

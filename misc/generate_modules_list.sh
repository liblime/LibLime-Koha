#!/bin/bash

grep -r '^use ' . | cut -d: -f2- | awk '{print $2}' | sed 's/;//' | grep -v ^C4:: | sort -g | uniq | egrep -v '^strict|^autouse$|^both$|^feature$|^file$|^of$|^open$|^the$|^base$'

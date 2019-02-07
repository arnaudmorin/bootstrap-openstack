#!/bin/bash

if [[ $(python --version) =~ 'Python 3.' ]] ; then
    python -m http.server 8000
else
    python -m SimpleHTTPServer 8000
fi

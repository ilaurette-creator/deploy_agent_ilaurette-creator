#!/usr/bin/bash

if command -v python3 >/dev/null; then
    echo "python3 is  installed $(python3 --version)"
else 
    echo "python3 is not installed"
fi

if command -v zip >/dev/null; then
    echo "zip is installed$(zip -v |head -n 2 |tail -n 1)"
else
    
    echo "zip is not installed"
fi

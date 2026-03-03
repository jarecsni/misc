#!/bin/bash
PROJECT=$(osascript -e "tell application \"Xcode\" to return path of document 1")
open -a Terminal "$PROJECT"

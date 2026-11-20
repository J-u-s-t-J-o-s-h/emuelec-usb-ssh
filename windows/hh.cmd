@echo off
rem Run a command on the handheld. Usage:  hh.cmd uptime     or     hh.cmd sh -s < script.sh
ssh -o BatchMode=yes emuelec %*

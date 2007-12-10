#!/bin/sh
cd /usr/local/webadmin
tar --exclude blib --exclude .svn --exclude make-module.sh --exclude Makefile -cvzf ~/webmin.com/Webmin-API-1.0.tar.gz Webmin-API-1.0/

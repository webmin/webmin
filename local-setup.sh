#!/bin/sh
noperlpath=1
nouninstall=1
atboot=1
nochown=1
if [ "$config_dir" = "" ]; then
	config_dir=/etc/webmin
fi
if [ "$var_dir" = "" ]; then
	var_dir=/var/webmin
fi
perl=/usr/local/bin/perl
session=1
nopostinstall=1
export noperlpath nouninstall atboot nochown config_dir var_dir perl session nopostinstall
./setup.sh

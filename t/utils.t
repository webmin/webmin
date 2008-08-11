#!/usr/bin/perl -w
# Test utility functions to be sure they do something utilitiful
use strict;
use Test::More tests => 1;
use OsChooser;

# Problematic...when run from harness, will not have tty
ok(OsChooser::have_tty() == 1, "have_tty");


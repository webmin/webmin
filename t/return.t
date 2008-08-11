#!/usr/bin/perl -w
# These tests just check to be sure all functions return something
# It doesn't care what it is returned...so garbage can still pass,
# as long as the garbage is the right data type.

use strict;
use Test::More tests => 3;

use_ok( 'OsChooser' );

isa_ok(\OsChooser::have_tty(), 'SCALAR');
isa_ok(\OsChooser::has_command("cp"), 'SCALAR');

# Don't know how to test the return from a die exception
# Maybe use Test::Exception and put this into another test file
#isa_ok(OsChooser::main(), 'SCALAR');

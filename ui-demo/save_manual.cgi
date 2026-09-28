#!/usr/local/bin/perl
# Target of the Save button of edit_manual.cgi. A real module would lock
# the file, write the submitted data, unlock it, record the action with
# webmin_log and redirect back to the editor. This demo deliberately
# writes nothing, and only redirects back to the editor for the same
# file.

use strict;
use warnings;

require './ui-demo-lib.pl'; ## no critic
our (%in);

ReadParse();

# Only ever go back to one of the demo's own sample files
my $file = $in{'file'} || '';
$file = '' if (!(grep { $_ eq $file } demo_config_files()));
redirect("edit_manual.cgi".($file ne '' ? "?file=".urlize($file) : ""));

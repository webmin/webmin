#!/usr/local/bin/perl
# Removes one database from the current user's recently opened list.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%in);
require './sqlite-lib.pl';
&ReadParse();

# The path only names an entry in this user's own list, which stores the
# resolved path, so it is matched as given and needs no ACL check.
&sqlite_forget_recent($in{'db'}) if ($in{'db'} ne '');
&redirect('');

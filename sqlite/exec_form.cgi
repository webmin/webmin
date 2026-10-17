#!/usr/local/bin/perl
# Displays the SQLite SQL command form.

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access);
require './sqlite-lib.pl';
&ReadParse();
$access{'sql'} || &error($text{'exec_denied'});

# Preserve the validated database path while the user writes a statement.
my $path = &sqlite_database_path($in{'db'});
&ui_print_header(&ui_tag('tt', &html_escape($path)),
	$text{'exec_title'}, '', 'exec');
print &ui_tag('p', $text{'exec_desc'});
print &ui_form_start('exec.cgi', 'post');
print &ui_hidden('db', $path);
print &ui_textarea('sql', $in{'sql'}, 14, 90, undef, undef,
	"style='width: 100%'");
print &ui_form_end([ [ undef, $text{'exec_run'} ] ]);
&ui_print_footer('database.cgi?db='.&urlize($path),
	$text{'database_return'});

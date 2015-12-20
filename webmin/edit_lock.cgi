#!/usr/local/bin/perl
# Display the locking form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'lock_title'}, "");

print $text{'lock_desc'},"<p>\n";

print &ui_form_start("change_lock.cgi", "post");
print &ui_table_start($text{'lock_header'}, undef, 2);

@grid = ( );
push(@grid, &ui_radio("lockmode", int($gconfig{'lockmode'}),
		[ [ 0, $text{'lock_all'}."<br>" ],
		  [ 1, $text{'lock_none'}."<br>" ],
		  [ 2, $text{'lock_only'}."<br>" ],
		  [ 3, $text{'lock_except'} ] ]));
push(@grid, &ui_textarea("lockdirs",
		join("\n", split(/\t+/, $gconfig{'lockdirs'})), 10, 60));
print &ui_table_row(undef, &ui_grid_table(\@grid, 2), 2);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


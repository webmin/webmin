#!/usr/local/bin/perl
# delegation_form.cgi
# A form for creating a new delegation-only
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
# Globals
our (%access, %text, %config);

require './bind8-lib.pl';
$access{'delegation'} || &error($text{'dcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});
&ui_print_header(undef, $text{'dcreate_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Form start
print &ui_form_start("create_delegation.cgi", "post");
print &ui_table_start($text{'dcreate_opts'}, "width=100%", 4);

# Forward or reverse?
print &ui_table_row($text{'fcreate_type'},
	&ui_radio("rev", 0, [ [ 0, $text{'fcreate_fwd'} ],
			      [ 1, $text{'fcreate_rev'} ] ]), 3);

# Domain name
print &ui_table_row($text{'fcreate_dom'},
	&ui_textbox("zone", undef, 60), 3);

# In view
my $conf = &get_config();
my @views = &find("view", $conf);
if (@views) {
	my ($defview) = grep { lc($_->{'values'}->[0]) eq
			    lc($config{'default_view'}) } @views;
	print &ui_table_row($text{'mcreate_view'},
		&ui_select("view", $defview ? $defview->{'index'} : undef,
		  [ map { [ $_->{'index'}, $_->{'values'}->[0] ] }
			grep { &can_edit_view($_) } @views ]), 3);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});

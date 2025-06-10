#!/usr/local/bin/perl
# edit_acl.cgi
# Choose visible usermin modules

require './usermin-lib.pl';
$access{'acl'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'acl_title'}, "");

&read_usermin_acl(\%acl);
print "$text{'acl_desc'}<p>\n";
print &ui_form_start("save_acl.cgi");
@mods = &list_modules();
@grid = ( );
foreach $m (@mods) {
	push(@grid, &ui_checkbox("mod", $m->{'dir'}, &html_escape($m->{'desc'}),
				 $acl{'user',$m->{'dir'}}));
	}
print &ui_grid_table(\@grid, 3, 100, [ "width=33%", "width=33%", "width=33%" ]);
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


#!/usr/local/bin/perl
# edit_restrict.cgi
# Edit a user or group module restriction

require './usermin-lib.pl';
$access{'restrict'} || &error($text{'acl_ecannot'});
&ReadParse();
if ($in{'new'}) {
	&ui_print_header(undef, $text{'restrict_create'}, "");
	}
else {
	&ui_print_header(undef, $text{'restrict_edit'}, "");
	@usermods = &list_usermin_usermods();
	$um = $usermods[$in{'idx'}];
	}

print &ui_form_start("save_restrict.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("all", $in{'all'});
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start($text{'restrict_header'}, undef, 2);

$umode = $um->[0] eq "*" ? 2 :
	 $um->[0] =~ /^\@/ ? 1 :
	 $um->[0] =~ /^\// ? 3 : 0;

print &ui_table_row($text{'restrict_who2'},
	&ui_radio_table("umode", $umode,
		[ [ 2, $text{'restrict_umode2'} ],
		  [ 0, $text{'restrict_umode0'},
		    &ui_user_textbox("user", $umode == 0 ? $um->[0] : "") ],
		  [ 1, $text{'restrict_umode1'},
		    &ui_group_textbox("group",
			$umode == 1 ? substr($um->[0], 1) : "") ],
		  [ 3, $text{'restrict_umode3'},
		    &ui_filebox("file", $umode == 3 ? $um->[0] : "", 40) ] ]));
		 
&read_usermin_acl(\%acl);
my @mods = &list_modules();
my @grid;
foreach my $m (@mods) {
	push(@grid,
	    &ui_checkbox("mod", $m->{'dir'},
			 $acl{"user",$m->{'dir'}} ? $m->{'desc'} :
				"<font color=#ff0000>$m->{'desc'}</font>",
			 &indexof($m->{'dir'}, @{$um->[2]}) >= 0));
	}
print &ui_table_row($text{'restrict_mods'},
	&ui_radio("mmode", $um->[1] eq "" ? 0 :
			   $um->[1] eq "+" ? 1 : 2,
		  [ [ 0, $text{'restrict_mmode0'} ],
		    [ 1, $text{'restrict_mmode1'} ],
		    [ 2, $text{'restrict_mmode2'} ] ])."<br>\n".
	&ui_grid_table(\@grid, 3, 100)."\n".
	&ui_links_row([ &select_all_link("mod", 0),
		        &select_invert_link("mod", 0) ])."\n".
	&text('restrict_modsdesc', "edit_acl.cgi"));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_restrict.cgi", $text{'restrict_return'});


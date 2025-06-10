#!/usr/local/bin/perl
# Show module description overrides

require './usermin-lib.pl';
&ui_print_header(undef, $text{'descs_title'}, undef);
print "$text{'descs_info'}<p>\n";

&read_file("$config{'usermin_dir'}/webmin.descs", \%descs);
print &ui_form_start("save_descs.cgi");
print &ui_columns_start([ $text{'descs_mod'},
			  $text{'descs_desc'} ]);
$i = 0;
@mods = sort { $a->{'realdesc'} cmp $b->{'realdesc'} } &list_modules();
foreach $d ((sort { $a cmp $b } (keys %descs)), undef, undef, undef) {
	next if ($d =~ /^(\S+)\s+(\S+)$/);
	print &ui_columns_row([
		&ui_select("mod_$i", $d,
		   [ [ "", "&nbsp;" ],
		     map { [ $_->{'dir'}, $_->{'realdesc'} ] } @mods ]),
		&ui_textbox("desc_$i", $descs{$d}, 40) ]);
	$i++;
	}
print &ui_columns_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


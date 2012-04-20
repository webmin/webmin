#!/usr/local/bin/perl
# Show module description overrides

require './webmin-lib.pl';
&ui_print_header(undef, $text{'descs_title'}, undef);
print "$text{'descs_info'}<p>\n";

&read_file("$config_directory/webmin.descs", \%descs);
print &ui_form_start("save_descs.cgi");
@tds = ( "width=50%", "width=50%" );

# Show override titles for real modules
print &ui_columns_start([ $text{'descs_mod'},
			  $text{'descs_desc'} ], "100%", 0, \@tds);
$i = 0;
@mods = sort { $a->{'realdesc'} cmp $b->{'realdesc'} } &get_all_module_infos();
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

# Show clone titles, if any
@clones = grep { $_->{'clone'} } @mods;
if (@clones) {
	print &ui_columns_start([ $text{'descs_cmod'},
				  $text{'descs_cdesc'} ], "100%", 0, \@tds);
	$i = 0;
	foreach $mod (grep { $_->{'clone'} } @mods) {
		%orig = &get_module_info(&get_clone_source($mod->{'dir'}));
		if (%orig) {
			$cdesc = $orig{'desc'}." (".$mod->{'dir'}.")";
			}
		else {
			$cdesc = $mod->{'dir'};
			}
		print &ui_columns_row([
			&ui_hidden("clone_$i", $mod->{'dir'}).$cdesc,
			&ui_textbox("title_$i", $mod->{'desc'}, 40) ]);
		$i++;
		}
	print &ui_columns_end();
	}
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


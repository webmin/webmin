#!/usr/local/bin/perl
# Show a table of Postfix server processes

require './postfix-lib.pl';

$access{'master'} || &error($text{'master_ecannot'});
&ui_print_header(undef, $text{'master_title'}, "", "master");
$master = &get_master_config();

print &ui_link("edit_master.cgi?new=1",$text{'master_add'}),"<br>\n";
print &ui_columns_start([ $text{'master_name'},
			  $text{'master_enabled'},
			  $text{'master_type'},
			  $text{'master_private'},
			  $text{'master_unpriv'},
			  $text{'master_chroot'},
			  $text{'master_max'} ], "100%");
foreach $m (@$master) {
	print &ui_columns_row([
		"<a href='edit_master.cgi?name=".&urlize($m->{'name'}).
		 "&type=".&urlize($m->{'type'})."&enabled=$m->{'enabled'}'>".
		 $m->{'name'}."</a>",
		$m->{'enabled'} ? $text{'yes'} :
			"<font color=#ff0000>$text{'no'}</font>",
		$text{'master_'.$m->{'type'}},
		$m->{'private'} eq 'n' ? $text{'no'} : $text{'yes'},
		$m->{'unpriv'} eq 'n' ? $text{'no'} : $text{'yes'},
		$m->{'chroot'} eq 'n' ? $text{'no'} : $text{'yes'},
		$m->{'maxprocs'} eq "-" ? $text{'default'} :
		 $m->{'maxprocs'} eq "0" ? $text{'master_unlimit'} :
					  $m->{'maxprocs'},
			]);
	}
print &ui_columns_end();
print &ui_link("edit_master.cgi?new=1",$text{'master_add'}),"<br>\n";

&ui_print_footer("", $text{'index_return'});

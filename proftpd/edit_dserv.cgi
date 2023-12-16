#!/usr/local/bin/perl
# edit_dserv.cgi
# Edit <Directory> section details

require './proftpd-lib.pl';
&ReadParse();
if ($in{'global'}) {
	$conf = &get_config();
	$conf = &get_or_create_global($conf);
	}
else {
	($conf, $v) = &get_virtual_config($in{'virt'});
	}
if ($in{'anon'}) {
	$anon = &find_directive_struct("Anonymous", $conf);
	$conf = $anon->{'members'};
	}
$d = $conf->[$in{'idx'}];
$dn = $d->{'words'}->[0];
$dconf = $d->{'members'};
$desc = $in{'global'} ? &text('dir_header5', $dn) :
	$in{'anon'} ? &text('dir_header4', $dn) :
	$in{'virt'} ?  &text('dir_header1', $dn, $v->{'words'}->[0]) :
	&text('dir_header2', $dn);
&ui_print_header($desc, $text{'dserv_title'}, "",
	undef, undef, undef, undef, &restart_button());

print &ui_form_start("save_dserv.cgi", "post");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("anon", $in{'anon'});
print &ui_hidden("global", $in{'global'});
print &ui_table_start($text{'dserv_title'}, undef, 2);

print &ui_table_row($text{'dserv_dir'},
	&ui_filebox("dir", $d->{'value'}, 60, 0, undef, undef, 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ],
		     [ 'delete', $text{'dserv_delete'} ] ]);

if ($in{'global'}) {
	&ui_print_footer("dir_index.cgi?global=$in{'global'}&idx=$in{'idx'}",
		$text{'dir_return'},
		"", $text{'index_return'});
	}
elsif ($in{'anon'}) {
	&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{anon}",
		$text{'dir_return'},
		"anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}",
		$text{'dir_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}


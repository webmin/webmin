#!/usr/local/bin/perl
# dir_index.cgi
# Display a menu of icons for per-directory options

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
	$in{'virt'} ? &text('dir_header1', $dn, $v->{'words'}->[0]) :
	&text('dir_header2', $dn);
&ui_print_header($desc, $text{'dir_title'}, "",
	undef, undef, undef, undef, &restart_button());

$dir_icon = { "icon" => "images/dir.gif",
	      "name" => $text{'dir_dir'},
	      "link" => "edit_dserv.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}" };
$ed_icon = { "icon" => "images/edit.gif",
	     "name" => $text{'dir_edit'},
	     "link" => "manual_form.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}" };
&config_icons("directory", "edit_dir.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}&global=$in{'global'}&", $dir_icon, $ed_icon);

# Display limit options
@lim = &find_directive_struct("Limit", $dconf);
if (@lim) {
	print &ui_hr();
	print "<h3>$text{'dir_header'}</h3>\n";
	foreach $l (@lim) {
		push(@links, "limit_index.cgi?limit=".&indexof($l, @$dconf).
                        "&virt=$in{'virt'}&anon=$in{'anon'}".
                        "&global=$in{'global'}&idx=$in{'idx'}");
		push(@titles, &text('virt_limit', $l->{'value'}));
		push(@icons, "images/limit.gif");
		}
	&icons_table(\@links, \@titles, \@icons, 3);
	}

print &ui_form_start("create_limit.cgi");
print &ui_hidden("virt", $in{'virt'});
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("anon", $in{'anon'});
print &ui_hidden("global", $in{'global'});
print &ui_table_start($text{'virt_addlimit'}, undef, 2);
print &ui_table_row($text{'virt_cmds'},
	&ui_textbox("cmd", undef, 30));
print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

if ($in{'global'}) {
	&ui_print_footer("", $text{'index_return'});
	}
elsif ($in{'anon'}) {
	&ui_print_footer("anon_index.cgi?virt=$in{'virt'}", $text{'anon_return'},
		"virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}
else {
	&ui_print_footer("virt_index.cgi?virt=$in{'virt'}", $text{'virt_return'},
		"", $text{'index_return'});
	}


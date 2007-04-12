#!/usr/local/bin/perl
# edit_limit.cgi
# Display a form for editing some kind of limit section options

require './proftpd-lib.pl';
&ReadParse();
if ($in{'file'}) {
	$conf = &get_ftpaccess_config($in{'file'});
	}
else {
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
	if ($in{'idx'} ne '') {
		$dir = $conf->[$in{'idx'}];
		$conf = $dir->{'members'};
		}
	}
$l = $conf->[$in{'limit'}];
$conf = $l->{'members'};
$ln = $l->{'value'};

@dirs = &editable_directives($in{'type'}, 'limit');
$desc = $in{'file'} ? &text('limit_header6', $ln, &html_escape($in{'file'})) :
	$dir ? &text('limit_header4', $ln, $dir->{'words'}->[0]) :
	$in{'global'} ? &text('limit_header7', $ln) :
	$in{'anon'} ? &text('limit_header5', $ln) :
	$in{'virt'} ? &text('limit_header1', $ln, $v->{'words'}->[0]) :
	&text('limit_header2', $ln);
&ui_print_header($desc, $text{"type_$in{'type'}"}, "",
	undef, undef, undef, undef, &restart_button());

print "<form method=post action=save_limit.cgi method=post>\n";
print "<input type=hidden name=type value='$in{'type'}'>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<input type=hidden name=limit value='$in{'limit'}'>\n";
print "<input type=hidden name=virt value='$in{'virt'}'>\n";
print "<input type=hidden name=anon value='$in{'anon'}'>\n";
print "<input type=hidden name=global value='$in{'global'}'>\n";
print "<input type=hidden name=file value='$in{'file'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('limit_header3', $text{"type_$in{'type'}"},
			       $l->{'value'}),"</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
&generate_inputs(\@dirs, $conf);
print "</table></td> </tr></table>\n";
print "<input type=submit value=\"$text{'save'}\"></form>\n";

if ($in{'file'}) {
	&ui_print_footer("limit_index.cgi?file=$in{'file'}&limit=$in{'limit'}",
		$text{'limit_return'},
		"ftpaccess_index.cgi?file=$in{'file'}",$text{'ftpindex_return'},
		"ftpaccess.cgi", $text{'ftpaccess_return'},
		"", $text{'index_return'});
	}
elsif ($in{'idx'} eq '') {
	if ($in{'global'}) {
		&ui_print_footer("limit_index.cgi?limit=$in{'limit'}&global=$in{'global'}",
			$text{'limit_return'},
			"", $text{'index_return'});
		}
	elsif ($in{'anon'}) {
		&ui_print_footer("limit_index.cgi?virt=$in{'virt'}&limit=$in{'limit'}&anon=$in{'anon'}",
			$text{'limit_return'},
			"anon_index.cgi?virt=$in{'virt'}",$text{'anon_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	else {
		&ui_print_footer("limit_index.cgi?virt=$in{'virt'}&limit=$in{'limit'}",
			$text{'limit_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	}
else {
	if ($in{'global'}) {
		&ui_print_footer("limit_index.cgi?limit=$in{'limit'}&idx=$in{'idx'}&global=$in{'global'}",
			$text{'limit_return'},
			"dir_index.cgi?idx=$in{'idx'}&global=$in{'global'}",
			$text{'dir_return'},
			"", $text{'index_return'});
		}
	elsif ($in{'anon'}) {
		&ui_print_footer("limit_index.cgi?virt=$in{'virt'}&limit=$in{'limit'}&idx=$in{'idx'}&anon=$in{'anon'}",
			$text{'limit_return'},
			"dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}", $text{'dir_return'},
			"anon_index.cgi?virt=$in{'virt'}",$text{'anon_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	else {
		&ui_print_footer("limit_index.cgi?virt=$in{'virt'}&limit=$in{'limit'}&idx=$in{'idx'}",
			$text{'limit_return'},
			"dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}", $text{'dir_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	}


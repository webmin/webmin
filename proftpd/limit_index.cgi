#!/usr/local/bin/perl
# limit_index.cgi
# Display a menu of icons for per-command options

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
$ln = $l->{'value'};
$desc = $in{'file'} ? &text('limit_header6', $ln, &html_escape($in{'file'})) :
	$dir ? &text('limit_header4', $ln, $dir->{'words'}->[0]) :
	$in{'global'} ? &text('limit_header7', $ln) :
	$in{'anon'} ? &text('limit_header5', $ln) :
	$in{'virt'} ?  &text('limit_header1', $ln, $v->{'words'}->[0]) :
	&text('limit_header2', $ln);
&ui_print_header($desc, $text{'limit_title'}, "",
	undef, undef, undef, undef, &restart_button());

$limit_icon = { "icon" => "images/limit.gif",
	        "name" => $text{'limit_limit'},
	        "link" => "edit_lserv.cgi?virt=$in{'virt'}&idx=$in{'idx'}&limit=$in{'limit'}&anon=$in{'anon'}&global=$in{'global'}&file=$in{'file'}" };
$ed_icon = { "icon" => "images/edit.gif",
	     "name" => $text{'limit_edit'},
	     "link" => $in{'file'} ? "manual_form.cgi?limit=$in{'limit'}&file=$in{'file'}" : "manual_form.cgi?virt=$in{'virt'}&idx=$in{'idx'}&limit=$in{'limit'}&anon=$in{'anon'}&global=$in{'global'}" };
&config_icons("limit", "edit_limit.cgi?virt=$in{'virt'}&idx=$in{'idx'}&limit=$in{'limit'}&anon=$in{'anon'}&file=$in{'file'}&global=$in{'global'}&", $limit_icon, $ed_icon);

if ($in{'file'}) {
	&ui_print_footer("ftpaccess_index.cgi?file=$in{'file'}",$text{'ftpindex_return'},
		"ftpaccess.cgi", $text{'ftpaccess_return'},
		"", $text{'index_return'});
	}
elsif ($in{'idx'} eq '') {
	if ($in{'global'}) {
		&ui_print_footer("", $text{'index_return'});
		}
	elsif ($in{'anon'}) {
		&ui_print_footer("anon_index.cgi?virt=$in{'virt'}",$text{'anon_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	else {
		&ui_print_footer("virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	}
else {
	if ($in{'global'}) {

		&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&global=$in{'global'}", $text{'dir_return'},
			"", $text{'index_return'});
		}
	elsif ($in{'anon'}) {
		&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}", $text{'dir_return'},
			"anon_index.cgi?virt=$in{'virt'}",$text{'anon_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	else {
		&ui_print_footer("dir_index.cgi?virt=$in{'virt'}&idx=$in{'idx'}&anon=$in{'anon'}", $text{'dir_return'},
			"virt_index.cgi?virt=$in{'virt'}",$text{'virt_return'},
			"", $text{'index_return'});
		}
	}


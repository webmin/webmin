#!/usr/local/bin/perl
# standard_chooser.cgi
# Display a list of standard modules for installation

require './webmin-lib.pl';
&ui_print_header(undef, );
$mods = &list_standard_modules();
if (!ref($mods)) {
	print "<b>",&text('standard_failed', $mods),"</b><p>\n";
	}
else {
	print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
	print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value,'row',true);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000';}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
	print &ui_hr("style='width:100%;'")."</div>";
	print "<b>$text{'standard_header'}</b><br>\n";
	if ($mods->[0]->[1] > &get_webmin_version()) {
		print &text('standard_warn', $mods->[0]->[1]),"<br>\n";
		}
	print "<script type='text/javascript'>\n";
	print "function select(f)\n";
	print "{\n";
	print "opener.ifield.value = f;\n";
	print "close();\n";
	print "return false;\n";
	print "}\n";
	print "</script>\n";
	@table = ( );
    $cnt = 0;
	foreach $m (@$mods) {
		my $minfo = { 'os_support' => $m->[3] };
		next if (!&check_os_support($minfo));
		push(@table, [
		 &ui_link("#", $m->[0], undef, "onClick='return select(\"$m->[0]\");'"),
		 &html_escape($m->[4]),
		 ]);
        $cnt++;
		}
	print &ui_columns_table(undef, 100, \@table);
	}
    if ( $cnt >= 10 ) {
        print "<script type='text/javascript' src='@{[&get_webprefix()]}/unauthenticated/filter_match.js?28112013'></script>";
        print "<script type='text/javascript'>filter_match_box();</script>";
    }
&ui_print_footer();


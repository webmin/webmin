#!/usr/local/bin/perl
# third_chooser.cgi
# Display a list of third-party modules for installation

$trust_unknown_referers = 1;
require './webmin-lib.pl';
&popup_header($text{'third_title'});
$mods = &list_third_modules();
if (!ref($mods)) {
	print "<b>",&text('third_failed', $mods),"</b><p>\n";
	}
else {
	print "<div id='filter_box' style='display:none;margin:0px;padding:0px;width:100%;clear:both;'>";
	print &ui_textbox("filter",$text{'ui_filterbox'}, 50, 0, undef,"style='width:100%;color:#aaa;' onkeyup=\"filter_match(this.value,'row',true);\" onfocus=\"if (this.value == '".$text{'ui_filterbox'}."') {this.value = '';this.style.color='#000';}\" onblur=\"if (this.value == '') {this.value = '".$text{'ui_filterbox'}."';this.style.color='#aaa';}\"");
	print &ui_hr("style='wdith:100%;'")."</div>";
	print "<b>$text{'third_header'}</b><br>\n";
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
		push(@table, [
		 &ui_link("#", $m->[0], undef, "onClick='return select(\"$m->[2]\");'"),
		 $m->[1] eq "NONE" ? "" : &html_escape($m->[1]),
		 $m->[3],
		 ]);
        $cnt++;
		}
	print &ui_columns_table(undef, 100, \@table);
	}
    if ( $cnt >= 10 ) {
        print "<script type='text/javascript' src='$gconfig{'webprefix'}/unauthenticated/filter_match.js?28112013'></script>";
        print "<script type='text/javascript'>filter_match_box();</script>";
    }
&popup_footer();


#!/usr/local/bin/perl
# Show two-factor authentication options

require './webmin-lib.pl';
ui_print_header(undef, $text{'twofactor_title'}, "", "twofactor");
get_miniserv_config(\%miniserv);

print "$text{'twofactor_desc'}<p>\n";

print <<EOF;
<style>
.opener_shown {display:inline}
.opener_hidden {display:none}
</style>
EOF

@provs = &list_twofactor_providers();
print "<script>\n";
print "function show_prov(name) {\n";
foreach $p (@provs) {
	print "d = document.getElementById(\"$p->[0]\");\n";
	print "d.className = name == \"$p->[0]\" ? \"opener_shown\" : \"opener_hidden\";\n";
	}
print "}\n";
print "</script>\n";

print ui_form_start("change_twofactor.cgi", "post");
print ui_table_start($text{'twofactor_header'}, undef, 2);

# Two-factor provider
my ($name, $value, $opts, $size, $multiple, $missing, $dis, $js) = @_;
print ui_table_row($text{'twofactor_provider'},
	ui_select("twofactor_provider", $miniserv{'twofactor_provider'},
		  [ [ "", "&lt;".$text{'twofactor_none'}."&gt;" ],
		    map { [ $_->[0], $_->[1] ] } @provs ],
		  1, 0, 0, 0, "onChange='show_prov(value)'"));

foreach $p (@provs) {
	$dis = $p->[0] eq $miniserv{'twofactor_provider'} ? "opener_shown"
							  : "opener_hidden";
	print "<div id=$p->[0] name=$p->[0] class='$dis'>\n";
	$sfunc = "show_twofactor_apikey_".$p->[0];
	if (defined(&$sfunc)) {
		print &$sfunc(\%miniserv);
		}
	print "</div>\n";
	}

print ui_table_end();
print ui_form_end([ [ "save", $text{'save'} ] ]);

ui_print_footer("", $text{'index_return'});


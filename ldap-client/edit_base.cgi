#!/usr/local/bin/perl
# Show a form for editing the LDAP search bases for users, groups other objects

require './ldap-client-lib.pl';
&ui_print_header(undef, $text{'base_title'}, "", "base");

$conf = &get_config();
print &ui_form_start("save_base.cgi", "post");
print &ui_table_start($text{'base_header'}, "width=100%", 2);

@bases = &find_value("base", $conf);

if (&get_ldap_client() eq "nss") {
	# Base is just one directive
	$base = $bases[0];
	}
else {
	# Default base is the one with no DB
	($base) = grep { /^\S+$/ } @bases;
	}
print &ui_table_row($text{'base_base'},
	&ui_textbox("base", $base, 50)."\n".
	&base_chooser_button("base", 0));

$scopes = [ [ "", $text{'default'} ],
	    [ "sub", $text{'base_ssub'} ],
	    [ "one", $text{'base_sone'} ],
	    [ "base", $text{'base_sbase'} ] ];
print &ui_table_row($text{'base_scope'},
	&ui_select("scope", &find_svalue("scope", $conf), $scopes));

print &ui_table_row($text{'base_timelimit'},
	&ui_opt_textbox("timelimit", &find_svalue("timelimit", $conf), 5,
		 	$text{'default'})." ".$text{'base_secs'});

$sp = "&nbsp;" x 5;
foreach $b (@base_types) {
	local $base;
	if (&get_ldap_client() eq "nss") {
		$base = &find_svalue("nss_base_".$b, $conf);
		}
	else {
		($base) = map { /^\S+\s+(\S+)/; $1 }
			      grep { /^\Q$b\E\s/ } @bases;
		}
	local ($scope, $filter);
	if ($base =~ /^(.*)\?(.*)\?(.*)$/) {
		$base = $1;
		$scope = $2;
		$filter = $3;
		}
	elsif ($base =~ /^(.*)\?(.*)$/) {
		$base = $1;
		$scope = $2;
		}
	print &ui_table_row($text{'base_'.$b},
		&ui_opt_textbox("base_$b", $base, 50, $text{'base_global'})." ".
		&base_chooser_button("base_$b", 0).
		"<br><table>\n".
		"<tr> <td>$sp</td> <td><b>$text{'base_bscope'}</b></td>\n".
		"<td>".&ui_select("scope_$b", $scope, $scopes)."</td> </tr>\n".
		"<tr> <td>$sp</td> <td><b>$text{'base_bfilter'}</b></td>\n".
		"<td>".&ui_textbox("filter_$b", $filter, 50)."</td> </tr>\n".
		"</table>");
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});



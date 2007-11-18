#!/usr/local/bin/perl
# Show local LDAP server configuration options

require './ldap-server-lib.pl';
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
&ui_print_header(undef, $text{'slapd_title'}, "", "slapd");
&ReadParse();
$conf = &get_config();

print &ui_form_start("save_slapd.cgi", "post");
print &ui_table_start($text{'slapd_header'}, undef, 2);

# Top-level DN
$suffix = &find_value('suffix', $conf);
print &ui_table_row($text{'slapd_suffix'},
		    &ui_textbox('suffix', $suffix, 60));

# Admin login
$rootdn = &find_value('rootdn', $conf);
print &ui_table_row($text{'slapd_rootdn'},
		    &ui_textbox('rootdn', $rootdn, 60));

# Admin password
$rootpw = &find_value('rootpw', $conf);
if ($rootpw =~ /^{crypt}(.*)/i) {
	$rootmode = 1;
	$rootcrypt = $1;
	}
elsif ($rootpw =~ /^{sha1}(.*)/i) {
	$rootmode = 2;
	$rootsha1 = $1;
	}
elsif ($rootpw =~ /^{[a-z0-9]+}(.*)/i) {
	$rootmode = 3;
	$rootenc = $rootpw;
	}
else {
	$rootmode = 0;
	$rootplain = $rootpw;
	}

# Current password
print &ui_table_row($text{'slapd_rootpw'},
		    $rootmode == 1 ? &text('slapd_root1', $rootcrypt) :
		    $rootmode == 2 ? &text('slapd_root2', $rootsha1) :
		    $rootmode == 3 ? &text('slapd_root3', $rootenc) :
				     $rootplain);

# Set to new
print &ui_table_row($text{'slapd_rootchange'},
		    &ui_opt_textbox('rootchange', undef, 30,
			$text{'slapd_leave'}, $text{'slapd_set'}));

# Cache sizes
$cachesize = &find_value('cachesize', $conf);
print &ui_table_row($text{'slapd_cachesize'},
		    &ui_textbox("cachesize", $cachesize, 10));
$dbcachesize = &find_value('dbcachesize', $conf);
print &ui_table_row($text{'slapd_dbcachesize'},
		    &ui_textbox("dbcachesize", $dbcachesize, 10));

# Access control options
$allowdir = &find("allow", $conf);
@allow = $allowdir ? @{$allowdir->{'values'}} : ( );
print &ui_table_row($text{'slapd_allow'},
    &ui_select("allow", \@allow,
	       [ map { [ $_, $text{'slapd_'.$_} ] }
		     ( 'bind_v2', 'bind_anon_cred',
		       'bind_anon_dn', 'update_anon' ) ], 4, 1, 1));

# Size and time limits
$sizelimit = &find_value('sizelimit', $conf);
print &ui_table_row($text{'slapd_sizelimit'},
    &ui_opt_textbox('sizelimit', $sizelimit, 10, $text{'default'}." (500)"));
$timelimit = &find_value('timelimit', $conf);
print &ui_table_row($text{'slapd_timelimit'},
    &ui_opt_textbox('timelimit', $timelimit, 10,
		    $text{'default'}." (3600 $text{'slapd_secs'})").
    " ".$text{'slapd_secs'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


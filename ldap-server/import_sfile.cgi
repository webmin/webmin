#!/usr/local/bin/perl
# Import a schema file into the server

require './ldap-server-lib.pl';
&error_setup($text{'import_err'});
&local_ldap_server() == 1 || &error($text{'slapd_elocal'});
$access{'schema'} || &error($text{'schema_ecannot'});
&ReadParse();
&is_under_directory($config{'schema_dir'}, $in{'file'}) ||
	&error($text{'schema_edir'});
&has_command($config{'ldapadd'}) ||
	&error(&text('import_eldapadd', "<tt>$config{'ldapadd'}</tt>"));

# Get login credentials
$user = $config{'user'};
$pass = $config{'pass'};
if (&get_config_type() == 1) {
	my $conf = &get_config();
	$user ||= &find_value("rootdn", $conf);
	$pass ||= &find_value("rootpw", $conf);
	}
else {
	$defdb = &get_default_db();
	$conf = &get_ldif_config();
	$user ||= &find_ldif_value("olcRootDN", $conf, $defdb);
	$pass ||= &find_ldif_value("olcRootPW", $conf, $defdb);
	}
$user || &error($text{'import_euser'});

# Check that there's a corresponding LDIF file
$ldiffile = $in{'file'};
$ldiffile =~ s/\.schema$/.ldif/;
-r $ldiffile ||
	&error(&text('import_eldif', "<tt>".&html_escape($ldiffile)."</tt>"));

# Run the import command
$cmd = $config{'ldapadd'}.
       " -D ".quotemeta($user).
       " -w ".quotemeta($pass).
       " -H ldapi:///".
       " -Y external".
       " -f ".quotemeta($ldiffile);

&ui_print_unbuffered_header(undef, $text{'import_title'}, "");

print &text('import_doing', "<tt>".&html_escape($ldiffile)."</tt>"),"<p>\n";
print "<pre>\n";
&open_execute_command(CMD, $cmd, 2);
while(<CMD>) {
	print &html_escape($_);
	}
close(CMD);
print "</pre>\n";
if ($?) {
	print $text{'import_failed'},"<p>\n";
	}
else {
	print $text{'import_ok'},"<p>\n";
	}

&ui_print_footer("edit_schema.cgi", $text{'schema_return'});

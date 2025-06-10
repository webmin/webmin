#!/usr/local/bin/perl
# Update misc PHP options

require './phpini-lib.pl';
&error_setup($text{'misc_err'});
&ReadParse();
&can_php_config($in{'file'}) || &error($text{'list_ecannot'});

&lock_file($in{'file'});
$conf = &get_config($in{'file'});

# Save tag styles
&save_directive($conf, "short_open_tag",
		$in{"short_open_tag"} || undef);
&save_directive($conf, "asp_tags",
		$in{"asp_tags"} || undef);

# Save output options
&save_directive($conf, "zlib.output_compression",
		$in{"zlib.output_compression"} || undef);
&save_directive($conf, "implicit_flush",
		$in{"implicit_flush"} || undef);

# Save URL open options
&save_directive($conf, "allow_url_fopen",
		$in{"allow_url_fopen"} || undef);

# Save email sending options
$in{"smtp_def"} || &to_ipaddress($in{"smtp"}) || &error($text{'misc_esmtp'});
&save_directive($conf, "SMTP",
		$in{"smtp_def"} ? undef : $in{"smtp"});
$in{"smtp_port_def"} || $in{"smtp_port"} =~ /^\d+$/ ||
	&error($text{'misc_esmtp_port'});
&save_directive($conf, "smtp_port",
		$in{"smtp_port_def"} ? undef : $in{"smtp_port"});

# Save sendmail program
if ($in{"sendmail_path_def"}) {
	&save_directive($conf, "sendmail_path", undef);
	}
else {
	($fp) = split(/\s+/, $in{"sendmail_path"});
	$fp || &error($text{'misc_esendmail2'})
	&has_command($fp) || &error($text{'misc_esendmail'});
	&save_directive($conf, "sendmail_path", $in{"sendmail_path"});
	}
 
# Save Include open options
&save_directive($conf, "allow_url_include",
	$in{"allow_url_include"} || undef);

# Save CGI Fix Path
&save_directive($conf, "cgi.fix_pathinfo",
	$in{"cgi.fix_pathinfo"} || undef);

# Save Timezone
&save_directive($conf, "date.timezone",
	$in{"date.timezone"} || undef);

# Save default charset
&save_directive($conf, "default_charset",
	$in{'default_charset_def'} ? undef : $in{'default_charset'});

&flush_file_lines_as_user($in{'file'}, undef, 1);
&unlock_file($in{'file'});
&graceful_apache_restart($in{'file'});
&webmin_log("misc", undef, $in{'file'});

&redirect("list_ini.cgi?file=".&urlize($in{'file'}));


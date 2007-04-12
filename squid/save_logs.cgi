#!/usr/local/bin/perl
# save_logs.cgi
# Save logging options

require './squid-lib.pl';
$access{'logging'} || &error($text{'elogs_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'slogs_ftslo'};

if ($squid_version < 2.6) {
	# Just a single logging directive
	&save_opt("cache_access_log", \&check_file, $conf);
	}
else {
	# Supports definition of log formats and files
	for($i=0; defined($fname = $in{"fname_$i"}); $i++) {
		$ffmt = $in{"ffmt_$i"};
		next if (!$fname);
		$fname =~ /^\S+$/ || &error(&text('slogs_efname', $i+1));
		$ffmt =~ /\S/ || &error(&text('slogs_effmt', $i+1));
		push(@logformat, { 'name' => 'logformat',
				   'values' => [ $fname, $ffmt ] });
		}
	&save_directive($conf, "logformat", \@logformat);

	# Save log files
	for($i=0; defined($afile = $in{"afile_$i"}); $i++) {
		$adef = $in{"afile_def_$i"};
		next if ($adef == 1);
		$adef == 2 || $afile =~ /^\/\S+$/ ||
			&error(&text('slogs_eafile', $i+1));
		$afmt = $in{"afmt_$i"};
		$aacls = $in{"aacls_$i"};
		push(@access,
		  { 'name' => 'access_log',
		    'values' => [ $adef == 2 ? "none" : $afile,
				  $afmt ? ( $afmt ) :
				   $aacls ? ( "squid" ) : ( ),
				  split(/\s+/, $aacls) ] } );
		}
	&save_directive($conf, "access_log", \@access);
	}

&save_opt("cache_log", \&check_file, $conf);
if ($in{'cache_store_log_def'} == 2) {
	&save_directive($conf, "cache_store_log",
			[ { 'name' => 'cache_store_log',
			    'values' => [ "none" ] } ]);
	}
else {
	&save_opt("cache_store_log", \&check_file, $conf);
	}
&save_opt("cache_swap_log", \&check_file, $conf);
&save_choice("emulate_httpd_log", "off", $conf);
&save_choice("log_mime_hdrs", "off", $conf);
&save_opt("useragent_log", \&check_file, $conf);
&save_opt("pid_filename", \&check_pid_file, $conf);
if ($squid_version >= 2.2) {
	if (!$in{'complex_ident'}) {
		local @ila = split(/\0/, $in{'ident_lookup_access'});
		&save_directive($conf, "ident_lookup_access", !@ila ? [ ] :
				[ { 'name' => 'ident_lookup_access',
				    'values' => [ 'allow', @ila ] } ]);
		}
	&save_opt_time("ident_timeout", $conf);
	}
else {
	&save_choice("ident_lookup", "off", $conf);
	}
&save_choice("log_fqdn", "off", $conf);
&save_opt("client_netmask", \&check_netmask, $conf);
&save_opt("debug_options", \&check_debug, $conf);
if ($squid_version >= 2) {
	&save_opt("mime_table", \&check_file, $conf);
	}

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("logs", undef, undef, \%in);
&redirect("");

sub check_pid_file
{
return $_[0] eq 'none' ? undef : &check_file($_[0]);
}

sub check_file
{
$_[0] =~ /^\// || return &text('slogs_emsg1',$_[0]);
$_[0] =~ /^(\S*\/)([^\/\s]+)$/ || return &text('slogs_emsg2',$_[0]);
(-d $1) || return &text('slogs_emsg3',$1);
return undef;
}

sub check_netmask
{
&check_ipaddress($_[0]) || return &text('slogs_emsg4',$_[0]);
return undef;
}

sub check_debug
{
$_[0] =~ /\S+/ || return &text('slogs_emsg5',$_[0]);
return undef;
}


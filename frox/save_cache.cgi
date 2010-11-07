#!/usr/local/bin/perl
# Save caching options

require './frox-lib.pl';
&ReadParse();
&error_setup($text{'cache_err'});
$conf = &get_config();

if (!$in{'CacheModule'}) {
	&save_directive($conf, "CacheModule", [ ]);
	}
elsif ($in{'CacheModule'} eq 'local') {
	&save_directive($conf, "CacheModule", [ "local" ]);
	&save_textbox($conf, "CacheSize", \&check_size);
	}
else {
	&save_directive($conf, "CacheModule", [ "http" ]);
	&save_textbox($conf, "HTTPProxy", \&check_proxy);
	&save_textbox($conf, "MinCacheSize", \&check_size);
	}

&save_yesno($conf, "StrictCaching");
&save_yesno($conf, "CacheOnFQDN");
&save_yesno($conf, "CacheAll");

&save_opt_textbox($conf, "VirusScanner", \&check_scanner);
&save_opt_textbox($conf, "VSOK", \&check_int);
&save_opt_textbox($conf, "VSProgressMsgs", \&check_int);

&lock_file($config{'frox_conf'});
&flush_file_lines();
&unlock_file($config{'frox_conf'});
&webmin_log("cache");
&redirect("");

sub check_size
{
return $_[0] =~ /^\d+$/ ? undef : $text{'cache_esize'};
}

sub check_proxy
{
return $_[0] =~ /^(\S+):(\d+)$/ && &to_ipaddress($1) ?
	undef : $text{'cache_eproxy'};
}

sub check_scanner
{
return $_[0] =~ /^"([^"]+)"/ && -x $1 ? undef :
       $_[0] =~ /^(\S+)/ && -x $1 ? undef : $text{'cache_escanner'};
}

sub check_int
{
return $_[0] =~ /^\d+$/ ? undef : $text{'cache_eint'};
}


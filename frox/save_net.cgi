#!/usr/local/bin/perl
# Save networking-related options

require './frox-lib.pl';
&ReadParse();
&error_setup($text{'net_err'});
$conf = &get_config();

&save_opt_textbox($conf, "Listen", \&check_listen);
&save_textbox($conf, "Port", \&check_port);
&save_opt_textbox($conf, "BindToDevice", \&check_iface);
&save_yesno($conf, "FromInetd");
&save_exists($conf, "NoDetach");
&save_opt_textbox($conf, "FTPProxy", \&check_proxy);
&save_opt_textbox($conf, "TcpOutgoingAddr", \&check_ip);
&save_opt_textbox($conf, "PASVAddress", \&check_ip);
&save_opt_textbox($conf, "ResolvLoadHack", \&check_resolv);

&lock_file($config{'frox_conf'});
&flush_file_lines();
&unlock_file($config{'frox_conf'});
&webmin_log("net");
&redirect("");

sub check_listen
{
return &to_ipaddress($_[0]) ? undef : $text{'net_ehost'};
}

sub check_port
{
return $_[0] =~ /^\d+$/ ? undef : $text{'net_eport'};
}

sub check_iface
{
return $_[0] =~ /^[a-z]+(\d*)(:\d+)?$/ ? undef : $text{'net_eiface'};
}

sub check_proxy
{
return $_[0] =~ /^(\S+):(\d+)$/ && &to_ipaddress($1) ?
	undef : $text{'net_eproxy'};
}

sub check_ip
{
return &check_ipaddress($_[0]) ? undef : $text{'net_eip'};
}

sub check_resolv
{
return $_[0] =~ /^[a-z0-9\.\-\_]+$/i ? undef : $text{'net_eresolv'};
}


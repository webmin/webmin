#!/usr/local/bin/perl
# save_white.cgi
# Save white and black lists of to and from addresses

require './spam-lib.pl';
&error_setup($text{'white_err'});
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("white");
&execute_before("white");
&lock_spam_files();
$conf = &get_config();

&parse_textbox($conf, "whitelist_from");

&parse_textbox($conf, 'unwhitelist_from');

if (!$config{'show_global'}) {
	@rcvd = &parse_table("whitelist_from_rcvd", \&rcvd_parser);
	&save_directives($conf, 'whitelist_from_rcvd', \@rcvd, 1);
	}

&parse_textbox($conf, 'blacklist_from');

&parse_textbox($conf, 'unblacklist_from');

if (!$config{'show_global'}) {
	@to = &parse_table("whitelist_to", \&to_parser);
	@oldto = ( &find("whitelist_to", $conf),
		   &find("more_spam_to", $conf),
		   &find("all_spam_to", $conf) );
	&save_directives($conf, \@oldto, \@to, 0);
	}

&flush_file_lines();
&unlock_spam_files();
&execute_after("white");
&webmin_log("white");
&redirect($redirect_url);

sub from_parser
{
return undef if (!$_[1]);
$_[1] =~ /^\S+$/ || &error(&text('white_efrom', $_[1]));
return $_[1];
}

sub rcvd_parser
{
local $a = &from_parser($_[0], $_[1]);
return undef if (!$a);
$_[2] =~ /^[A-Za-z0-9\.\-]+$/ || &error(&text('white_ercvd', $_[2]));
return "$a $_[2]";
}

sub to_parser
{
local $a = &from_parser($_[0], $_[1]);
return undef if (!$a);
return { 'name' => $_[2] == 0 ? 'whitelist_to' :
		   $_[2] == 1 ? 'more_spam_to' : 'all_spam_to',
	 'value' => $a };
}


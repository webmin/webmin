#!/usr/local/bin/perl
# edit_nauth.cgi
# Display a list of proxy users

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config, $module_name);
require './squid-lib.pl';

if ($config{'crypt_conf'} == 1) {
	eval "use Digest::MD5";
	if ($@) {
        	&error(&text('eauth_nomd5', $module_name));
		}
	}

$access{'proxyauth'} || &error($text{'eauth_ecannot'});
&ui_print_header(undef, $text{'eauth_header'}, "", undef, 0, 0, 0, &restart_button());
my $conf = &get_config();
my $authfile = &get_auth_file($conf);

print &text('eauth_nmsgaccess', "<tt>$authfile</tt>"),"<p>\n";
my @users = &list_auth_users($authfile);
if (@users) {
	print &ui_links_row([ &ui_link("edit_nuser.cgi?new=1",
				       $text{'eauth_addpuser'}) ]);
	my @grid;
	for(my $i=0; $i<@users; $i++) {
		my ($it, $unit) = $users[$i]->{'enabled'} ? ('', '') :
					('<i>', '</i>');
		push(@grid, &ui_link("edit_nuser.cgi?index=$i",
				     $it.$users[$i]->{'user'}.$unit));
		}
	print &ui_grid_table(\@grid, 4, 100, undef, undef,
			     $text{'eauth_pusers'});
	}
else {
	print "<b>$text{'eauth_nopusers'}</b> <p>\n";
	}
print &ui_links_row([ &ui_link("edit_nuser.cgi?new=1",
			       $text{'eauth_addpuser'}) ]);

&ui_print_footer("", $text{'eauth_return'});


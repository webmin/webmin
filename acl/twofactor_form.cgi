#!/usr/local/bin/perl
# Show a form for enabling two-factor authentication

use strict;
use warnings;
require './acl-lib.pl';
our (%in, %text, %config, %access, $base_remote_user);
&foreign_require("webmin");
&error_setup($text{'twofactor_err'});
&ReadParse();

my %miniserv;
&get_miniserv_config(\%miniserv);
if (!$miniserv{'twofactor_provider'}) {
	&ui_print_header(undef, $text{'twofactor_title'}, "");
	print &text('twofactor_setup', '../webmin/edit_twofactor.cgi'),"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	return;
	}

# Get the user
my @users = &list_users();
my $user;
if ($in{'user'}) {
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	($user) = grep { $_->{'name'} eq $in{'user'} } @users;
	}
else {
	($user) = grep { $_->{'name'} eq $base_remote_user } @users;
	}
$user || &error($text{'twofactor_euser'});

&ui_print_header(undef, $text{'twofactor_title'}, "");

print &ui_form_start("save_twofactor.cgi", "post");
print &ui_hidden("user", $in{'user'});
my @buts;
if ($user->{'twofactor_provider'}) {
	@buts = ( [ "disable", $text{'twofactor_disable'} ] );
	my ($prov) = grep { $_->[0] eq $user->{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text($in{'user'} ? 'twofactor_already2' : 'twofactor_already',
		    "<i>$prov->[1]</i>",
		    "<tt>$user->{'twofactor_id'}</tt>",
		    "<tt>$in{'user'}</tt>"),"<p>\n";
	}
else {
	my ($prov) = grep { $_->[0] eq $miniserv{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text($in{'user'} ? 'twofactor_desc2' : 'twofactor_desc',
		    "<i>$prov->[1]</i>",
		    $prov->[2],
		    "<tt>$in{'user'}</tt>"),"<p>\n";
	my $ffunc = "webmin::show_twofactor_form_".
		    $miniserv{'twofactor_provider'};
	if (defined(&$ffunc)) {
		print &ui_table_start($text{'twofactor_header'}, undef, 2);
		print &{\&{$ffunc}}($user);
		print &ui_table_end();
		}
	@buts = ( [ "enable", $text{'twofactor_enable'} ] );
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

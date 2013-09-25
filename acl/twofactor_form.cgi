#!/usr/local/bin/perl
# Show a form for enabling two-factor authentication

require './acl-lib.pl';
&foreign_require("webmin");
&error_setup($text{'twofactor_err'});
&get_miniserv_config(\%miniserv);

# Get the user
($user) = grep { $_->{'name'} eq $base_remote_user } &list_users();
$user || &error($twxt{'twofactor_euser'});

&ui_print_header(undef, $text{'twofactor_title'}, "");

print &ui_form_start("save_twofactor.cgi", "post");
if ($user->{'twofactor_provider'}) {
	@buts = ( [ "disable", $text{'twofactor_disable'} ] );
	($prov) = grep { $_->[0] eq $user->{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text('twofactor_already', "<i>$prov->[1]</i>",
		    "<tt>$user->{'twofactor_id'}</tt>"),"<p>\n";
	}
else {
	($prov) = grep { $_->[0] eq $miniserv{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text('twofactor_desc', $prov->[1], $prov->[2]),"<p>\n";
	print &ui_table_start($text{'twofactor_header'}, undef, 2);
	$ffunc = "webmin::show_twofactor_form_".$miniserv{'twofactor_provider'};
	print &$ffunc($user);
	print &ui_table_end();
	@buts = ( [ "enable", $text{'twofactor_enable'} ] );
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

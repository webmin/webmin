#!/usr/local/bin/perl
# Show a form for enabling two-factor authentication

require './acl-lib.pl';
&foreign_require("webmin");
&error_setup($text{'twofactor_err'});
&get_miniserv_config(\%miniserv);
&ReadParse();

if (!$miniserv{'twofactor_provider'}) {
	&ui_print_header(undef, $text{'twofactor_title'});
	&ui_print_endpage(&text('twofactor_setup',
				'../webmin/edit_twofactor.cgi'));
	return;
	}

# Get the user
@users = &list_users();
if ($in{'user'}) {
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	($user) = grep { $_->{'name'} eq $in{'user'} } @users;
	}
else {
	($user) = grep { $_->{'name'} eq $base_remote_user } @users;
	}
$user || &error($twxt{'twofactor_euser'});

&ui_print_header(undef, $text{'twofactor_title'}, "");

print &ui_form_start("save_twofactor.cgi", "post");
print &ui_hidden("user", $in{'user'});
if ($user->{'twofactor_provider'}) {
	@buts = ( [ "disable", $text{'twofactor_disable'} ] );
	($prov) = grep { $_->[0] eq $user->{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text($in{'user'} ? 'twofactor_already2' : 'twofactor_already',
		    "<i>$prov->[1]</i>",
		    "<tt>$user->{'twofactor_id'}</tt>",
		    "<tt>$in{'user'}</tt>"),"<p>\n";
	}
else {
	($prov) = grep { $_->[0] eq $miniserv{'twofactor_provider'} }
		       &webmin::list_twofactor_providers();
	print &text($in{'user'} ? 'twofactor_desc2' : 'twofactor_desc',
		    "<i>$prov->[1]</i>",
		    $prov->[2],
		    "<tt>$in{'user'}</tt>"),"<p>\n";
	$ffunc = "webmin::show_twofactor_form_".$miniserv{'twofactor_provider'};
	if (defined(&$ffunc)) {
		print &ui_table_start($text{'twofactor_header'}, undef, 2);
		print &$ffunc($user);
		print &ui_table_end();
		}
	@buts = ( [ "enable", $text{'twofactor_enable'} ] );
	}
print &ui_form_end(\@buts);

&ui_print_footer("", $text{'index_return'});

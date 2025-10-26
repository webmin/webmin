#!/usr/local/bin/perl
# edit_unix.cgi
# Choose a user whose permissions will be used for logins that don't
# match any webmin user, but have unix accounts

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'unix'} && $access{'create'} && $access{'delete'} ||
	&error($text{'unix_ecannot'});
&ui_print_header(undef, $text{'unix_title'}, "");

print "$text{'unix_desc'}<p>\n";
my %miniserv;
&get_miniserv_config(\%miniserv);

print &ui_form_start("save_unix.cgi", "post");
print &ui_table_start($text{'unix_header'}, undef, 2);

# Enable Unix auth
my @unixauth = &get_unixauth(\%miniserv);
my $utable = "";
$utable .= &ui_radio("unix_def", @unixauth ? 0 : 1,
	[ [ 1, $text{'unix_def'} ], [ 0, $text{'unix_sel'} ] ])."<br>\n";
$utable .= &ui_columns_start([ $text{'unix_mode'}, $text{'unix_who'},
			  $text{'unix_to'} ]);
my $i = 0;
my @webmins = map { [ $_->{'name'} ] }
	       sort { $a->{'name'} cmp $b->{'name'} } &list_users();
foreach my $ua (@unixauth, [ ], [ ]) {
	$utable .= &ui_columns_row([
		&ui_select("mode_$i", !defined($ua->[0]) ? 0 :
				      $ua->[0] eq "" ? 0 :
				      $ua->[0] eq "*" ? 1 :
				      $ua->[0] =~ /^\@/ ? 2 : 3,
			   [ [ 0, " " ],
			     [ 1, $text{'unix_mall'} ],
			     [ 2, $text{'unix_group'} ],
			     [ 3, $text{'unix_user'} ] ]),
		&ui_textbox("who_$i", $ua->[0] eq "*" || $ua->[0] eq "" ? "" :
			      $ua->[0] =~ /^\@(.*)$/ ? $1 : $ua->[0], 20),
		&ui_select("to_$i", $ua->[1], \@webmins),
		]);
	$i++;
	}
$utable .= &ui_columns_end();
print &ui_table_row($text{'unix_utable'}, $utable);

# Allow users who can sudo to root?
print &ui_table_row("",
	&ui_checkbox("sudo", 1, $text{'unix_sudo'},
		     $miniserv{'sudo'}));

# Allow PAM-only users?
print &ui_table_row("",
	&ui_checkbox("pamany", 1, &text('unix_pamany',
				      &ui_select("pamany_user",
						 $miniserv{'pamany'}, 
						 \@webmins)),
		   $miniserv{'pamany'}));

print &ui_table_hr();

# Who can do Unix auth?
my $users = $miniserv{"allowusers"} ?
		join("\n", split(/\s+/, $miniserv{"allowusers"})) :
	 $miniserv{"denyusers"} ?
		join("\n", split(/\s+/, $miniserv{"denyusers"})) : "";
print &ui_table_row($text{'unix_restrict2'},
	&ui_radio("access", $miniserv{"allowusers"} ? 1 :
			    $miniserv{"denyusers"} ? 2 : 0,
		  [ [ 0, $text{'unix_all'} ],
		    [ 1, $text{'unix_allow'} ],
		    [ 2, $text{'unix_deny'} ] ])."<br>\n".
	&ui_textarea("users", $users, 6, 60));


# Block login by shell?
print &ui_table_row("",
	&ui_checkbox("shells_deny", 1, $text{'unix_shells'},
		     $miniserv{'shells_deny'} ? 1 : 0)." ".
	&ui_filebox("shells", $miniserv{'shells_deny'} || "/etc/shells", 25));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});


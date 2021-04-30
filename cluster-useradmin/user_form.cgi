#!/usr/local/bin/perl
# user_form.cgi
# Display a form for creating a new user

require './cluster-useradmin-lib.pl';
use Time::Local;
&ReadParse();
&foreign_require("useradmin", "user-lib.pl");

&ui_print_header(undef, $text{'uedit_title2'}, "");
@hosts = &list_useradmin_hosts();
@servers = &list_servers();

# build list of used shells and uids
foreach $h (@hosts) {
	foreach $u (@{$h->{'users'}}) {
		push(@shlist, $u->{'shell'}) if ($u->{'shell'});
		$used{$u->{'uid'}}++;
		}
	foreach $g (@{$h->{'groups'}}) {
		push(@glist, $g) if (!$donegroup{$g->{'group'}}++);
		}
	}
open(SHELLS, "</etc/shells");
while(<SHELLS>) {
	s/\r|\n//g;
	s/#.*$//;
	push(@shlist, $_) if (/\S/);
	}
close(SHELLS);

print &ui_form_start("create_user.cgi", "post");
print &ui_table_start($text{'uedit_details'}, "width=100%", 2);

# Username
print &ui_table_row($text{'user'},
	&ui_textbox("user", undef, 40));

# Find the first free UID above the base
$newuid = int($uconfig{'base_uid'});
while($used{$newuid}) {
	$newuid++;
	}
print &ui_table_row($text{'uid'},
	&ui_textbox("uid", $newuid, 10));

# Real name and possibly other fields
if ($uconfig{'extra_real'}) {
        print &ui_table_row($text{'real'},
                &ui_textbox("real", undef, 40));

        print &ui_table_row($text{'office'},
		&ui_textbox("office", undef, 20));

        print &ui_table_row($text{'workph'},
		&ui_textbox("workph", undef, 20));

        print &ui_table_row($text{'homeph'},
		&ui_textbox("homeph", undef, 20));

        print &ui_table_row($text{'extra'},
		&ui_textbox("extra", undef, 20));
	}
else {
	print &ui_table_row($text{'real'},
		&ui_textbox("real", undef, 40));
	}

# Home directory
print &ui_table_row($text{'home'},
	$uconfig{'home_base'} ?
		&ui_radio("home_base", 1,
			  [ [ 1, $text{'uedit_auto'} ],
			    [ 0, &ui_filebox("home", "", 40) ] ]) :
		&ui_filebox("home", "", 40));

# Login shell
@shlist = &unique(@shlist);
push(@shlist, [ "*", $text{'uedit_other'} ]);
print &ui_table_row($text{'shell'},
	&ui_select("shell", undef, \@shlist)." ".
	&ui_filebox("othersh", undef, 25));

# Password or locked account
$rp = $uconfig{'random_password'} ? &useradmin::generate_random_password() : "";
$pfield = $uconfig{'passwd_stars'} ? &ui_password("pass", $rp, 40)
				   : &ui_textbox("pass", $rp, 40);
print &ui_table_row($text{'pass'},
	&ui_radio_table("passmode", 1,
	    [ [ 0, $uconfig{'empty_mode'} ? $text{'none1'} : $text{'none2'} ],
	      [ 1, $text{'nologin'} ],
	      [ 3, $text{'clear'}, $pfield ],
	      [ 2, &ui_textbox("encpass", undef, 40) ] ]));

print &ui_table_end();

$pft = &foreign_call("useradmin", "passfiles_type");
if ($pft == 1 || $pft == 6) {
	# This is a BSD system.. a few extra password options are supported
	print &ui_table_start($text{'uedit_passopts'}, undef, 2);

	print &ui_table_row($text{'change2'},
		&useradmin::date_input("", "", "", 'change')." ".
		&ui_textbox("changeh", "", 3).":".
		&ui_textbox("changemi", "", 3));

	print &ui_table_row($text{'expire2'},
		&useradmin::date_input("", "", "", 'expire')." ".
		&ui_textbox("expireh", "", 3).":".
		&ui_textbox("expiremi", "", 3));

	print &ui_table_row($text{'class'},
		&ui_textbox("class", "", 10));

	print &ui_table_end();
	}
elsif ($pft == 2) {
	# System has a shadow password file as well.. which means it supports
	# password expiry and so on
	print &ui_table_start($text{'uedit_passopts'}, undef, 2);

	print &ui_table_row($text{'expire'},
		&useradmin::date_input($eday, $emon, $eyear, 'expire'));

	print &ui_table_row($text{'min'},
		&ui_textbox("min", undef, 5));

	print &ui_table_row($text{'max'},
		&ui_textbox("max", undef, 5));

	print &ui_table_row($text{'warn'},
		&ui_textbox("warn", undef, 5));

	print &ui_table_row($text{'inactive'},
		&ui_textbox("inactive", undef, 5));

	print &ui_table_end();
	}
elsif ($pft == 4) {
	# This is an AIX system
	print &ui_table_start($text{'uedit_passopts'}, undef, 2);

	print &ui_table_row($text{'expire'},
		&useradmin::date_input("", "", "", 'expire')." ".
		&ui_textbox("expireh", undef, 3).":".
		&ui_textbox("expiremi", undef, 3));

	print &ui_table_row($text{'min_weeks'},
		&ui_textbox("min", undef, 5));

	print &ui_table_row($text{'max_weeks'},
		&ui_textbox("max", undef, 5));

	print &ui_table_row($text{'warn'},
		&ui_textbox("warn", undef, 5));

	print &ui_table_row($text{'flags'},
		&ui_checkbox("flags", "admin", $text{'uedit_admin'})." ".
		&ui_checkbox("flags", "admchg", $text{'uedit_admchg'})." ".
		&ui_checkbox("flags", "nocheck", $text{'uedit_nocheck'}));

	print &ui_table_end();
	}

print &ui_table_start($text{'uedit_gmem'}, "width=100%", 2);

# Primary group
print &ui_table_row($text{'group'},
	&ui_group_textbox("gid", $uconfig{'default_group'}));

# Secondary groups
@glist = sort { $a->{'group'} cmp $b->{'group'} } @glist
	if ($uconfig{'sort_mode'});
print &ui_table_row($text{'uedit_2nd'},
	&ui_select("sgid", undef,
		[ map { [ $_->{'gid'}, $_->{'group'} ] } @glist ],
		5, 1));

print &ui_table_end();

print &ui_table_start($text{'uedit_oncreate'}, "width=100%", 2);

# Create home dir?
print &ui_table_row($text{'uedit_makehome'},
	&ui_yesno_radio("makehome", 1));

# Copy home dir files?
if ($uconfig{'user_files'} =~ /\S/) {
	print &ui_table_row($text{'uedit_copy'},
		&ui_yesno_radio("copy_files", 1));
	}

# Create home dir on all servers?
print &ui_table_row($text{'uedit_servs'},
	&ui_radio("servs", 0, [ [ 1, $text{'uedit_mall'} ],
			 	[ 0, $text{'uedit_mthis'} ] ]));

# Show other modules option
print &ui_table_row($text{'uedit_others'},
        &ui_yesno_radio("others", 1));

# Show selector for hosts to create on
print &ui_table_row($text{'uedit_servers'},
	&create_on_input());

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});


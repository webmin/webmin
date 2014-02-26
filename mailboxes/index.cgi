#!/usr/local/bin/perl
# index.cgi
# Display all users on the system

require './mailboxes-lib.pl';

if ($config{'mail_system'} == 3) {
	# Need to detect mail server
	$ms = &detect_mail_system();
	if ($ms == 3) {
		&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
		&ui_print_endpage(&text('index_esystem',
					"../config.cgi?$module_name"));
		}
	else {
		$config{'mail_system'} = $ms;
		&save_module_config();
		}
	}
elsif (!$config{'send_mode'} || $config{'auto'}) {
	# Make sure mail system is valid
	local ($ms) = grep { $_->[1] == $config{'mail_system'} }
			   @mail_system_modules;
	if (!&check_mail_system($ms)) {
		&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
		&ui_print_endpage(&text('index_esystem2',
					"../config.cgi?$module_name"));
		}
	}

# Make sure mail system is running
$err = &test_mail_system();
if ($err) {
	&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
	&ui_print_endpage(&text('index_esystem3',
				"../config.cgi?$module_name", $err));
	}

# Show main page header
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
		 undef, undef, undef,
		 $text{'index_system'.$config{'mail_system'}});

# Check for Perl modules for SMTP authentication
if ($config{'smtp_user'}) {
	local @needed = ( "Authen::SASL" );
	local $smode = $config{'smtp_auth'} || "Cram-MD5";
	$smode = uc($smode);
	$smode =~ s/-/_/g;
	push(@needed, "Authen::SASL::Perl::$smode");
	foreach $n (@needed) {
		eval "use $n";
		if ($@) {
			&ui_print_endpage(
				"<p>".&text('index_eperl', "<tt>$n</tt>",
				  "/cpan/download.cgi?source=3&cpan=$n&mode=2&".
				  "return=/$module_name/&returndesc=".
				  &urlize($text{'index_return'}))."<p>\n".
				"$text{'index_eperl2'}\n".
				"<pre>$@</pre>\n");
			}
		}
	}

# Build a list of all available users
@users = &list_mail_users($config{'max_records'}, \&can_user);

$form = 0;
if (!@users) {
	# No users!
	print "<b>$text{'index_none'}</b> <p>\n";
	}
elsif ($config{'max_records'} && @users > $config{'max_records'}) {
	# Show input for searching for a user
	print $text{'index_toomany'},"<p>\n";
	print &ui_form_start("find.cgi");
	print &ui_submit($text{'index_find'}),"\n";
	print &ui_select("match", undef, [ [ "0", $text{'index_equals'} ],
					   [ "1", $text{'index_contains'} ] ]),"\n";
	print &ui_user_textbox("user"),"\n";
	print &ui_form_end();
	$form++;
	}
else {
	# Show using selected mode and sort
	&show_users_table(\@users, $config{'show_mail'});
	}

if (&allowed_directory()) {
	# Show form to view any mail file
	print &ui_hr();
	print &ui_form_start("list_mail.cgi");
	print &ui_submit($text{'index_file'}),"\n";
	print &ui_textbox("user", undef, 40),"\n",
	      &file_chooser_button("user", $form),"<br>\n";
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});


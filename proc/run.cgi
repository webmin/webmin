#!/usr/local/bin/perl
# run.cgi
# Run a command, and maybe display it's output

require './proc-lib.pl';
&ReadParse();
$access{'run'} || &error($text{'run_ecannot'});

# Force run as user from ACL. This is done instead of calling
# switch_acl_uid, so that commands can be run with su
if (!$module_info{'usermin'}) {
	if ($access{'uid'} < 0) {
		$in{'user'} = $remote_user;
		}
	elsif ($access{'uid'}) {
		$in{'user'} = getpwuid($access{'uid'});
		}
	}

$in{'input'} =~ s/\r//g;
$cmd = $in{'cmd'};
if (&supports_users()) {
	defined(getpwnam($in{'user'})) || &error($text{'run_euser'});
	&can_edit_process($in{'user'}) || &error($text{'run_euser2'});
	if ($in{'user'} ne getpwuid($<)) {
		$cmd = &command_as_user($in{'user'}, 0, $cmd);
		}
	}

if ($in{'mode'}) {
	# fork and run..
	if (!($pid = fork())) {
		close(STDIN); close(STDOUT); close(STDERR);
		&open_execute_command(PROC, "($cmd)", 0);
		print PROC $in{'input'};
		close(PROC);
		exit;
		}
	&redirect("index_tree.cgi");
	}
else {
	# run and display output..
	&ui_print_unbuffered_header(undef, $text{'run_title'}, "");
	print "<p>\n";
	print &text('run_output', "<tt>".&html_escape($in{'cmd'})."</tt>"),"<p>\n";
	print "<pre>";
	$got = &safe_process_exec_logged($cmd, 0, 0,
					 STDOUT, $in{'input'}, 1);
	if (!$got) { print "<i>$text{'run_none'}</i>\n"; }
	print "</pre>\n";
	&ui_print_footer("", $text{'index'});
	}
&webmin_log("run", undef, undef, \%in);


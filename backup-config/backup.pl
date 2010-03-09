#!/usr/local/bin/perl
# Execute a backup on schedule

$no_acl_check++;
require './backup-config-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Get the backup
$backup = &get_backup($ARGV[0]);
$backup || die "Failed to find backup $ARGV[0]";

# Run the pre-backup command, if any
if ($backup->{'pre'}) {
	$preout = &backquote_command("($backup->{'pre'}) 2>&1 </dev/null");
	$premsg = &text('email_pre', $backup->{'pre'})."\n".
		  $preout."\n";
	if ($?) {
		$err = $text{'email_prefailed'};
		}
	}

# Do it
@mods = split(/\s+/, $backup->{'mods'});
if (!$err) {
	$err = &execute_backup(\@mods, $backup->{'dest'}, \$size, undef,
			       $backup->{'configfile'}, $backup->{'nofiles'},
			       [ split(/\t+/, $backup->{'others'}) ]);
	}

# Run the post-backup command, if any
if (!$err) {
	$postout = &backquote_command("($backup->{'post'}) 2>&1 </dev/null");
	$postmsg = "\n".
		  &text('email_post', $backup->{'post'})."\n".
		  $postout."\n";
	}

# Send off the results
if (($err || $backup->{'emode'} == 0) && $backup->{'email'}) {
	foreach $m (@mods) {
		%minfo = &get_module_info($m);
		$mlist .= "    $minfo{'desc'}\n";
		}
	$host = &get_system_hostname();
	$nice = &nice_dest($backup->{'dest'}, 1);
	$nice =~ s/<[^>]+>//g;
	$err =~ s/<[^>]+>//g;
	if ($err) {
		$msg = $premsg.
		       $text{'email_mods'}."\n".
		       $mlist.
		       "\n".
		       &text('email_failed', $nice)."\n\n".
		       "    $err\n";
		$subject = &text('email_sfailed', $host);
		}
	else {
		$msg = $premsg.
		       $text{'email_mods'}."\n".
		       $mlist.
		       "\n".
		       &text('email_ok', $nice)."\n".
		       &text('email_final', &nice_size($size))."\n".
		       $postmsg;
		$subject = &text('email_sok', $host);
		}
	print STDERR $msg,"\n";
	&mailboxes::send_text_mail($config{'from_addr'} ||
				   &mailboxes::get_from_address(),
				   $backup->{'email'},
				   undef,
				   $subject,
				   $msg);
	}


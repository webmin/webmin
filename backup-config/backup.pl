#!/usr/local/bin/perl
# Execute a backup on schedule

$no_acl_check++;
require './backup-config-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Get the backup
$backup = &get_backup($ARGV[0]);
$backup || die "Failed to find backup $ARGV[0]";

# Do it
@mods = split(/\s+/, $backup->{'mods'});
$err = &execute_backup(\@mods, $backup->{'dest'}, \$size, undef,
		       $backup->{'configfile'}, $backup->{'nofiles'},
		       [ split(/\t+/, $backup->{'others'}) ]);

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
		$msg = $text{'email_mods'}."\n".
		       $mlist.
		       "\n".
		       &text('email_failed', $nice)."\n\n".
		       "    $err\n";
		$subject = &text('email_sfailed', $host);
		}
	else {
		$msg = $text{'email_mods'}."\n".
		       $mlist.
		       "\n".
		       &text('email_ok', $nice)."\n".
		       &text('email_final', &nice_size($size))."\n";
		$subject = &text('email_sok', $host);
		}
	&mailboxes::send_text_mail($config{'from_addr'} ||
				   &mailboxes::get_from_address(),
				   $backup->{'email'},
				   undef,
				   $subject,
				   $msg);
	}


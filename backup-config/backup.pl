#!/usr/local/bin/perl
# Execute a backup on schedule

use strict;
use warnings;
our (%text, %config, $no_acl_check);
$no_acl_check++;
require './backup-config-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Get the backup
my $backup = &get_backup($ARGV[0]);
$backup || die "Failed to find backup $ARGV[0]";

# Run the pre-backup command, if any
my $err;
my $premsg = "";
if ($backup->{'pre'} =~ /\S/) {
	my $preout = &backquote_command("($backup->{'pre'}) 2>&1 </dev/null");
	$premsg = &text('email_pre', $backup->{'pre'})."\n".
		  $preout."\n";
	if ($?) {
		$err = $text{'email_prefailed'};
		}
	}

# Do it
my @mods = split(/\s+/, $backup->{'mods'});
my $size;
if (!$err) {
	$err = &execute_backup(\@mods, $backup->{'dest'}, \$size, undef,
			       $backup->{'configfile'}, $backup->{'nofiles'},
			       [ split(/\t+/, $backup->{'others'}) ]);
	}

# Run the post-backup command, if any
my $postmsg = "";
if (!$err && $backup->{'post'} =~ /\S/) {
	my $postout = &backquote_command("($backup->{'post'}) 2>&1 </dev/null");
	$postmsg = "\n".
		  &text('email_post', $backup->{'post'})."\n".
		  $postout."\n";
	}

# Send off the results
if (($err || $backup->{'emode'} == 0) && $backup->{'email'}) {
	my $mlist;
	foreach my $m (@mods) {
		my %minfo = &get_module_info($m);
		$mlist .= "    $minfo{'desc'}\n";
		}
	my $host = &get_system_hostname();
	my $nice = &nice_dest($backup->{'dest'}, 1);
	$nice =~ s/<[^>]+>//g;
	my $msg;
	my $subject;
	if ($err) {
		$err =~ s/<[^>]+>//g;
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
	&mailboxes::send_text_mail($config{'from_addr'} ||
				   &mailboxes::get_from_address(),
				   $backup->{'email'},
				   undef,
				   $subject,
				   $msg);
	}


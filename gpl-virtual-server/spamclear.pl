#!/usr/local/bin/perl
# Clear spam folders in virtual servers that have requested it

package virtual_server;
$main::no_acl_check++;
$no_virtualmin_plugins = 1;
require './virtual-server-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Parse command-line args
while(@ARGV) {
	$a = shift(@ARGV);
	if ($a eq "--debug") {
		$debug = 1;
		}
	else {
		$ucheck{$a}++;
		}
	}

# hack to force correct DBM mode
$temp = &transname();
&make_dir($temp, 0700);
&mailboxes::open_dbm_db(\%dummy, "$temp/dummy", 0700);

foreach $d (&list_domains()) {
	# Is clearing enabled?
	if (!$d->{'spam'}) {
		print STDERR "$d->{'dom'}: spam filtering is not enabled\n"
			if ($debug);
		next;
		}
	$auto = &get_domain_spam_autoclear($d);
	if (!$auto) {
		print STDERR "$d->{'dom'}: spam clearing is not enabled\n"
			if ($debug);
		next;
		}
	print STDERR "$d->{'dom'}: finding mailboxes\n" if ($debug);

	# Check all mailboxes
	@users = &list_domain_users($d, 0, 1, 1, 1);
	foreach $u (@users) {
		# Find spam folder
		next if (keys %ucheck && !$ucheck{$u->{'user'}});
		print STDERR " $u->{'user'}: finding folders\n" if ($debug);
		@uinfo = ( $u->{'user'}, $u->{'pass'}, $u->{'uid'},
			   $u->{'gid'}, undef, undef, $u->{'real'},
			   $u->{'home'}, $u->{'shell'} );
		@folders = &mailboxes::list_user_folders(@uinfo);
		foreach $fn ("spam", "virus") {
			($folder) = grep { $_->{'file'} =~ /\/(\.?)\Q$fn\E$/i &&
					   $_->{'index'} != 0 } @folders;
			if (!$folder) {
				print STDERR "  $u->{'user'}: no $fn folder\n"
					if ($debug);
				next;
				}
			print STDERR "  $u->{'user'}: $fn folder is $folder->{'file'}\n" if ($debug);

			# Verify the index on the spam folder
			if ($folder->{'type'} == 0) {
				local $ifile = &mailboxes::user_index_file(
						$folder->{'file'});
				local %index;
				eval {
					&mailboxes::build_dbm_index(
						$folder->{'file'}, \%index);
					dbmclose(%index);
					};
				if ($@) {
					# Bad .. need to clear
					unlink($ifile.".dir",
					       $ifile.".pag",
					       $ifile.".db");
					}
				}

			# Get email in the folder, and check criteria
			my @mail = &mailboxes::mailbox_list_mails(
				undef, undef, $folder, 1);
			print STDERR "  $u->{'user'}: mail count ",
				     scalar(@mail),"\n" if ($debug);
			my @delmail;
			if ($auto->{'days'}) {
				# Find mail older than some number of days
				$cutoff = time() - $auto->{'days'}*24*60*60;
				foreach $m (@mail) {
					$time = &mailboxes::parse_mail_date(
						$m->{'header'}->{'date'});
					$time ||= $m->{'time'};
					if ($time && $time < $cutoff) {
						#print STDERR "deleting $m->{'header'}->{'subject'} dated $time\n";
						push(@delmail, $m);
						}
					}
				}
			else {
				# Find oldest mail that is too large
				$needsize = &mailboxes::folder_size($folder) -
					    $auto->{'size'};
				print STDERR "  $u->{'user'}: mail size ",
					&mailboxes::folder_size($folder),"\n"
					if ($debug);
				foreach $m (@mail) {
					last if ($needsize <= 0);
					push(@delmail, $m);
					#print STDERR "deleting $m->{'header'}->{'subject'} with size $m->{'size'}\n";
					$needsize -= $m->{'size'};
					}
				}

			# Delete any mail found
			if (@delmail) {
				print STDERR "  $u->{'user'}: deleting ",
					scalar(@delmail)," messages\n"
					if ($debug);
				&mailboxes::mailbox_delete_mail(
					$folder, reverse(@delmail));
				}
			}
		}
	}


#!/usr/local/bin/perl
# index.cgi
# Display a list of all local filesystems, and allow editing of quotas
# on those which have quotas turned on. The actual turning on of quotas must
# be done in the mount module first.

require './quota-lib.pl';
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("quota", "man", "howto"));

$err = &quotas_init();
if ($err) {
	print "<p><b>$err</b><p>\n";
	&ui_print_footer("/", $text{'index_return'});
	exit;
	}

@list = &list_filesystems();
if (@list) {
	print &ui_columns_start([
		$text{'index_fs'},
		$text{'index_type'},
		$text{'index_mount'},
		$text{'index_status'},
		$access{'enable'} ? ( $text{'index_action'} ) : (),
		], 100);
	@tds = ( "", "valign=top", "valign=top", "valign=top", "valign=top" );
	foreach $f (@list) {
		$qc = $f->[4];
		$qc = $qc&1 if ($access{'gmode'} == 3);
		$qs = $f->[6];
		next if (!$qc && !$qs);
		next if (!&can_edit_filesys($f->[0]));
		$qn = $f->[5];
		if ($qc == 1) { $msg = $text{'index_quser'}; }
		elsif ($qc == 2) { $msg = $text{'index_qgroup'}; }
		elsif ($qc == 3) { $msg = $text{'index_qboth'}; }
		$canactivate = 1;
		if ($qn >= 4) {
			$chg = $text{'index_mountonly'};
			$qn -= 4;
			$canactivate = 0;
			if ($qn) {
				$msg .= " $text{'index_active'}";
				}
			else {
				$msg .= " $text{'index_inactive'}";
				}
			}
		elsif ($qn) {
			# Currently active
			$msg .= " $text{'index_active'}";
			$chg = $text{'index_disable'};
			}
		elsif ($qc) {
			# Not active, but could be
			$msg .= " $text{'index_inactive'}";
			$chg = $text{'index_enable'};
			}
		else {
			# Not active, and needs setup in /etc/fstab
			$msg = $text{'index_supported'};
			$chg = $text{'index_enable2'};
			}
		if ($qn%2 == 1) { $useractive++; }
		if ($qn > 1) { $groupactive++; }

		local @cols;
		$dir = $f->[0];
		if (!$qn) {
			push(@cols, $dir);
			}
		elsif ($qc == 1) {
			push(@cols, &ui_link("list_users.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir) );
			}
		elsif ($qc == 2) {
			push(@cols, &ui_link("list_groups.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir) );
			}
		elsif ($qc == 3) {
			push(@cols, &ui_link("list_users.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir." (users)").
                    "<br>".
                    &ui_link("list_groups.cgi?dir=".&urlize($dir)."&can=".&urlize($qc), $dir." (groups)") );
			}

		push(@cols, &foreign_call("mount", "fstype_name", $f->[2]));
		push(@cols, &foreign_call("mount", "device_name", $f->[1]));
		push(@cols, $msg);
		if ($access{'enable'}) {
			if ($canactivate) {
				push(@cols, &ui_link("activate.cgi?dir=$dir&active=$qn&mode=$qc", $chg) );
				}
			else {
				push(@cols, $chg);
				}
			}
		print &ui_columns_row(\@cols, \@tds);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_nosupport'}</b><p>\n";
	if (&foreign_available("mount")) {
		print &text('index_mountmod', "../mount/"),"<p>\n";
		}
	}

# Buttons to edit and specific user or group
if ($useractive || $groupactive) {
	print &ui_hr();
	print &ui_buttons_start();
	}
if ($useractive) {
	print &ui_buttons_row("user_filesys.cgi", $text{'index_euser'},
			      $text{'index_euserdesc'}, undef,
			      &ui_user_textbox("user"));
	}
if ($groupactive) {
	print &ui_buttons_row("group_filesys.cgi", $text{'index_egroup'},
			      $text{'index_egroupdesc'}, undef,
			      &ui_group_textbox("group"));
	}
if ($useractive || $groupactive) {
	print &ui_buttons_end();
	}

&ui_print_footer("/", $text{'index_return'});


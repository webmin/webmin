# folders-lib.pl
# Functions for dealing with mail folders in various formats

$pop3_port = 110;
$imap_port = 143;

@index_fields = ( "subject", "from", "to", "date", "size",
		  "x-spam-status", "message-id" );
$create_cid_count = 0;

# get_folder_cache_directory(&folder)
# Returns a directory used to cache IMAP or POP3 files for some folder
sub get_folder_cache_directory
{
my ($folder) = @_;
if ($user_module_config_directory) {
	return $user_module_config_directory."/".$folder->{'id'}.".cache";
	}
else {
	my $rv = $module_config_directory."/".$folder->{'id'}.".cache";
	if (!-d $rv) {
		$rv = $module_var_directory."/".$folder->{'id'}.".cache";
		}
	return $rv;
	}
}

# mailbox_list_mails(start, end, &folder, [headersonly], [&error])
# Returns an array whose size is that of the entire folder, with messages
# in the specified range filled in.
sub mailbox_list_mails
{
my @mail;
&switch_to_folder_user($_[2]);
if ($_[2]->{'type'} == 0) {
	# List a single mbox formatted file
	@mail = &list_mails($_[2]->{'file'}, $_[0], $_[1]);
	}
elsif ($_[2]->{'type'} == 1) {
	# List a qmail maildir
	local $md = $_[2]->{'file'};
	@mail = &list_maildir($md, $_[0], $_[1], $_[3]);
	}
elsif ($_[2]->{'type'} == 2) {
	# Get mail headers/body from a remote POP3 server

	# Login first
	local @rv = &pop3_login($_[2]);
	if ($rv[0] != 1) {
		# Failed to connect or login
		if ($_[4]) {
			@{$_[4]} = @rv;
			return ();
			}
		elsif ($rv[0] == 0) { &error($rv[1]); }
		else { &error(&text('save_elogin', $rv[1])); }
		}
	local $h = $rv[1];
	local @uidl = &pop3_uidl($h);
	local %onserver = map { &safe_uidl($_), 1 } @uidl;

	# Work out what range we want
	local ($start, $end) = &compute_start_end($_[0], $_[1], scalar(@uidl));
	@mail = map { undef } @uidl;

	# For each message in the range, get the headers or body
	local ($i, $f, %cached, %sizeneed);
	local $cd = &get_folder_cache_directory($_[2]);
	if (opendir(CACHE, $cd)) {
		while($f = readdir(CACHE)) {
			if ($f =~ /^(\S+)\.body$/) {
				$cached{$1} = 2;
				}
			elsif ($f =~ /^(\S+)\.headers$/) {
				$cached{$1} = 1;
				}
			}
		closedir(CACHE);
		}
	else {
		mkdir($cd, 0700);
		}
	for($i=$start; $i<=$end; $i++) {
		local $u = &safe_uidl($uidl[$i]);
		if ($cached{$u} == 2 || $cached{$u} == 1 && $_[3]) {
			# We already have everything that we need
			}
		elsif ($cached{$u} == 1 || !$_[3]) {
			# We need to get the entire mail
			&pop3_command($h, "retr ".($i+1));
			open(CACHE, ">", "$cd/$u.body");
			while(<$h>) {
				s/\r//g;
				last if ($_ eq ".\n");
				print CACHE $_;
				}
			close(CACHE);
			unlink("$cd/$u.headers");
			$cached{$u} = 2;
			}
		else {
			# We just need the headers
			&pop3_command($h, "top ".($i+1)." 0");
			open(CACHE, ">", "$cd/$u.headers");
			while(<$h>) {
				s/\r//g;
				last if ($_ eq ".\n");
				print CACHE $_;
				}
			close(CACHE);
			$cached{$u} = 1;
			}
		local $mail = &read_mail_file($cached{$u} == 2 ?
				"$cd/$u.body" : "$cd/$u.headers");
		if ($cached{$u} == 1) {
			if ($mail->{'body'} ne "") {
				$mail->{'size'} = int($mail->{'body'});
				}
			else {
				$sizeneed{$i} = 1;
				}
			}
		$mail->{'idx'} = $i;
		$mail->{'id'} = $uidl[$i];
		$mail[$i] = $mail;
		}

	# Get sizes for mails if needed
	if (%sizeneed) {
		&pop3_command($h, "list");
		while(<$h>) {
			s/\r//g;
			last if ($_ eq ".\n");
			if (/^(\d+)\s+(\d+)/ && $sizeneed{$1-1}) {
				# Add size to the mail cache
				$mail[$1-1]->{'size'} = $2;
				local $u = &safe_uidl($uidl[$1-1]);
				open(CACHE, ">>", "$cd/$u.headers");
				print CACHE $2,"\n";
				close(CACHE);
				}
			}
		}

	# Clean up any cached mails that no longer exist on the server
	foreach $f (keys %cached) {
		if (!$onserver{$f}) {
			unlink($cached{$f} == 1 ? "$cd/$f.headers"
						: "$cd/$f.body");
			}
		}
	}
elsif ($_[2]->{'type'} == 3) {
	# List an MH directory
	local $md = $_[2]->{'file'};
	@mail = &list_mhdir($md, $_[0], $_[1], $_[3]);
	}
elsif ($_[2]->{'type'} == 4) {
	# Get headers and possibly bodies from an IMAP server

	# Login and select the specified mailbox
	local @rv = &imap_login($_[2]);
	if ($rv[0] != 1) {
		# Something went wrong
		if ($_[4]) {
			@{$_[4]} = @rv;
			return ();
			}
		elsif ($rv[0] == 0) { &error($rv[1]); }
		elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
		elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
		}
	local $h = $rv[1];
	local $count = $rv[2];
	return () if (!$count);
	$_[2]->{'lastchange'} = $rv[3] if ($rv[3]);

	# Work out what range we want
	local ($start, $end) = &compute_start_end($_[0], $_[1], $count);
	@mail = map { undef } (0 .. $count-1);

	# Get the headers or body of messages in the specified range
	local @rv;
	if ($_[3]) {
		# Just the headers
		@rv = &imap_command($h,
			sprintf "FETCH %d:%d (RFC822.SIZE UID FLAGS RFC822.HEADER)",
				$start+1, $end+1);
		}
	else {
		# Whole messages
		@rv = &imap_command($h,
			sprintf "FETCH %d:%d (UID FLAGS BODY.PEEK[])", $start+1, $end+1);
		}

	# Parse the headers or whole messages that came back
	local $i;
	for($i=0; $i<@{$rv[1]}; $i++) {
		# Extract the actual mail part
		local $mail = &parse_imap_mail($rv[1]->[$i]);
		if ($mail) {
			$mail->{'idx'} = $start+$i;
			$mail[$start+$i] = $mail;
			}
		}
	}
elsif ($_[2]->{'type'} == 5) {
	# A composite folder, which combined two or more others.

	# Work out exactly how big the total is
	local ($sf, %len, $count);
	foreach $sf (@{$_[2]->{'subfolders'}}) {
		print DEBUG "working out size of ",&folder_name($sf),"\n";
		$len{$sf} = &mailbox_folder_size($sf);
		$count += $len{$sf};
		}

	# Work out what range we need
	local ($start, $end) = &compute_start_end($_[0], $_[1], $count);

	# Fetch the needed part of each sub-folder
	local $pos = 0;
	foreach $sf (@{$_[2]->{'subfolders'}}) {
		local ($sfstart, $sfend);
		local $sfn = &folder_name($sf);
		$sfstart = $start - $pos;
		$sfend = $end - $pos;
		$sfstart = $sfstart < 0 ? 0 :
			   $sfstart >= $len{$sf} ? $len{$sf}-1 : $sfstart;
		$sfend = $sfend < 0 ? 0 :
			 $sfend >= $len{$sf} ? $len{$sf}-1 : $sfend;
		print DEBUG "getting mail from $sfstart to $sfend in $sfn\n";
		local @submail =
			&mailbox_list_mails($sfstart, $sfend, $sf, $_[3]);
		local $sm;
		foreach $sm (@submail) {
			if ($sm) {
				# ID is the original folder and ID
				$sm->{'id'} = $sfn."\t".$sm->{'id'};
				}
			}
		push(@mail, @submail);
		$pos += $len{$sf};
		}
	}
elsif ($_[2]->{'type'} == 6) {
	# A virtual folder, which just contains ids of mails in other folders
	local $mems = $folder->{'members'};
	local ($start, $end) = &compute_start_end($_[0], $_[1], scalar(@$mems));

	# Build a map from sub-folder names to IDs in them
	local (%wantmap, %namemap);
	for(my $i=$start; $i<=$end; $i++) {
		local $sf = $mems->[$i]->[0];
		local $sid = $mems->[$i]->[1];
		local $sfn = &folder_name($sf);
		$namemap{$sfn} = $sf;
		push(@{$wantmap{$sfn}}, [ $sid, $i ]);
		}

	# For each sub-folder, get the IDs we need, and put them into the
	# return array at the right place
	@mail = map { undef } (0 .. @$mems-1);
	local $changed = 0;
	foreach my $sfn (keys %wantmap) {
		local $sf = $namemap{$sfn};
		local @wantids = map { $_->[0] } @{$wantmap{$sfn}};
		local @wantidxs = map { $_->[1] } @{$wantmap{$sfn}};
		local @sfmail = &mailbox_select_mails($sf, \@wantids, $_[3]);
		for(my $i=0; $i<@sfmail; $i++) {
			$mail[$wantidxs[$i]] = $sfmail[$i];
			if ($sfmail[$i]) {
				# Original mail exists .. add to results
				if ($sfmail[$i]->{'id'} ne $wantids[$i]) {
					# Under new ID now - fix up index
					print DEBUG "wanted ID ",$wantids[$i],
						" got ",$sfmail[$i]->{'id'},"\n";
					local ($m) = grep {
						$_->[1] eq $wantids[$i] } @$mems;
					if ($m) {
						$m->[1] = $sfmail[$i]->{'id'};
						$changed = 1;
						}
					}
				$sfmail[$i]->{'idx'} = $wantidxs[$i];
				$sfmail[$i]->{'id'} =
					$sfn."\t".$sfmail[$i]->{'id'};
				}
			else {
				# Take out of virtual folder index
				print DEBUG "underlying email $sfn $wantids[$i] is gone!\n";
				$mems = [ grep { $_->[0] ne $sf ||
					 $_->[1] ne $wantids[$i] } @$mems ];
				$changed = 1;
				$mail[$wantidxs[$i]] = 'GONE';
				}
			}
		}
	if ($changed) {
		# Need to save virtual folder
		$folder->{'members'} = $mems;
		&save_folder($folder, $folder);
		}

	# Filter out messages that don't exist anymore
	@mail = grep { $_ ne 'GONE' } @mail;
	}
elsif ($_[2]->{'type'} == 7) {
	# MBX format folder
	print DEBUG "listing MBX $_[2]->{'file'}\n";
	@mail = &list_mbxfile($_[2]->{'file'}, $_[0], $_[1]);
	}
&switch_from_folder_user($_[2]);
return @mail;
}

# mailbox_select_mails(&folder, &ids, headersonly)
# Returns only messages from a folder with unique IDs in the given array
sub mailbox_select_mails
{
local ($folder, $ids, $headersonly) = @_;
my @mail;
&switch_to_folder_user($_[0]);
if ($folder->{'type'} == 0) {
	# mbox folder
	@mail = &select_mails($folder->{'file'}, $ids, $headersonly);
	}
elsif ($folder->{'type'} == 1) {
	# Maildir folder
	@mail = &select_maildir($folder->{'file'}, $ids, $headersonly);
	}
elsif ($folder->{'type'} == 3) {
	# MH folder
	@mail = &select_mhdir($folder->{'file'}, $ids, $headersonly);
	}
elsif ($folder->{'type'} == 2) {
	# POP folder

	# Login first
	local @rv = &pop3_login($folder);
	if ($rv[0] != 1) {
		# Failed to connect or login
		if ($_[4]) {
			@{$_[4]} = @rv;
			return ();
			}
		elsif ($rv[0] == 0) { &error($rv[1]); }
		else { &error(&text('save_elogin', $rv[1])); }
		}
	local $h = $rv[1];
	local @uidl = &pop3_uidl($h);
	local %uidlmap;		# Map from UIDLs to POP3 indexes
	for(my $i=0; $i<@uidl; $i++) {
		$uidlmap{$uidl[$i]} = $i+1;
		}

	# Work out what we have cached
	local ($i, $f, %cached, %sizeneed);
	local $cd = &get_folder_cache_directory($_[2]);
	if (opendir(CACHE, $cd)) {
		while($f = readdir(CACHE)) {
			if ($f =~ /^(\S+)\.body$/) {
				$cached{$1} = 2;
				}
			elsif ($f =~ /^(\S+)\.headers$/) {
				$cached{$1} = 1;
				}
			}
		closedir(CACHE);
		}
	else {
		mkdir($cd, 0700);
		}

	# For each requested uidl, get the headers or body
	foreach my $i (@$ids) {
		local $u = &safe_uidl($i);
		print DEBUG "need uidl $i -> $uidlmap{$i}\n";
		if ($cached{$u} == 2 || $cached{$u} == 1 && $headersonly) {
			# We already have everything that we need
			}
		elsif ($cached{$u} == 1 || !$headersonly) {
			# We need to get the entire mail
			&pop3_command($h, "retr ".$uidlmap{$i});
			open(CACHE, ">", "$cd/$u.body");
			while(<$h>) {
				s/\r//g;
				last if ($_ eq ".\n");
				print CACHE $_;
				}
			close(CACHE);
			unlink("$cd/$u.headers");
			$cached{$u} = 2;
			}
		else {
			# We just need the headers
			&pop3_command($h, "top ".$uidlmap{$i}." 0");
			open(CACHE, ">", "$cd/$u.headers");
			while(<$h>) {
				s/\r//g;
				last if ($_ eq ".\n");
				print CACHE $_;
				}
			close(CACHE);
			$cached{$u} = 1;
			}
		local $mail = &read_mail_file($cached{$u} == 2 ?
				"$cd/$u.body" : "$cd/$u.headers");
		if ($cached{$u} == 1) {
			if ($mail->{'body'} ne "") {
				$mail->{'size'} = length($mail->{'body'});
				}
			else {
				$sizeneed{$uidlmap{$i}} = $mail;
				}
			}
		$mail->{'idx'} = $uidlmap{$i}-1;
		$mail->{'id'} = $i;
		push(@mail, $mail);
		}

	# Get sizes for mails if needed
	if (%sizeneed) {
		&pop3_command($h, "list");
		while(<$h>) {
			s/\r//g;
			last if ($_ eq ".\n");
			if (/^(\d+)\s+(\d+)/ && $sizeneed{$1}) {
				# Find mail in results, and set its size
				local ($ns) = $sizeneed{$1};
				$ns->{'size'} = $2;
				local $u = &safe_uidl($uidl[$1-1]);
				open(CACHE, ">>", "$cd/$u.headers");
				print CACHE $2,"\n";
				close(CACHE);
				}
			}
		}
	}
elsif ($folder->{'type'} == 4) {
	# IMAP folder

	# Login and select the specified mailbox
	local @irv = &imap_login($folder);
	if ($irv[0] != 1) {
		# Something went wrong
		if ($_[4]) {
			@{$_[4]} = @irv;
			return ();
			}
		elsif ($irv[0] == 0) { &error($irv[1]); }
		elsif ($irv[0] == 3) { &error(&text('save_emailbox', $irv[1]));}
		elsif ($irv[0] == 2) { &error(&text('save_elogin2', $irv[1])); }
		}
	local $h = $irv[1];
	local $count = $irv[2];
	return () if (!$count);
        $folder->{'lastchange'} = $irv[3] if ($irv[3]);

	# Build map from IDs to original order, as UID FETCH doesn't return
	# mail in the order we asked for!
	local %wantpos;
	for(my $i=0; $i<@$ids; $i++) {
		$wantpos{$ids->[$i]} = $i;
		}

	# Fetch each mail by ID. This is done in blocks of 1000, to avoid
	# hitting a the IMAP server's max request limit
	@mail = map { undef } @$ids;
	local $wanted = $headersonly ? "(RFC822.SIZE UID FLAGS RFC822.HEADER)"
				     : "(UID FLAGS BODY.PEEK[])";
	if (@$ids) {
		for(my $chunk=0; $chunk<@$ids; $chunk+=1000) {
			local $chunkend = $chunk+999;
			if ($chunkend >= @$ids) { $chunkend = @$ids-1; }
			local @cids = @$ids[$chunk .. $chunkend];
			local @idxrv = &imap_command($h,
				"UID FETCH ".join(",", @cids)." $wanted");
			foreach my $idxrv (@{idxrv->[1]}) {
				local $mail = &parse_imap_mail($idxrv);
				if ($mail) {
					$mail->{'idx'} = $mail->{'imapidx'}-1;
					$mail[$wantpos{$mail->{'id'}}] = $mail;
					}
				}
			}
		}
	print DEBUG "imap rv = ",scalar(@mail),"\n";
	}
elsif ($folder->{'type'} == 5 || $folder->{'type'} == 6) {
	# Virtual or composite folder .. for each ID, work out the folder and
	# build a map from folders to ID lists
	print DEBUG "selecting ",scalar(@$ids)," ids\n";

	# Build a map from sub-folder names to IDs in them
	my $i = 0;
	my %wantmap;
	foreach my $id (@$ids) {
		local ($sfn, $sid) = split(/\t+/, $id, 2);
		push(@{$wantmap{$sfn}}, [ $sid, $i ]);
		$i++;
		}

	# Build map from sub-folder names to IDs
	my (%namemap, @allids, $mems);
	if ($folder->{'type'} == 6) {
		# For a virtual folder, we need to find all sub-folders
		$mems = $folder->{'members'};
		foreach my $m (@$mems) {
			local $sfn = &folder_name($m->[0]);
			$namemap{$sfn} = $m->[0];
			push(@allids, $sfn."\t".$m->[1]);
			}
		}
	else {
		# For a composite, they are simply listed
		foreach my $sf (@{$folder->{'subfolders'}}) {
			local $sfn = &folder_name($sf);
			$namemap{$sfn} = $sf;
			}
		@allids = &mailbox_idlist($folder);
		}

	# For each sub-folder, get the IDs we need, and put them into the
        # return array at the right place
	@mail = map { undef } @$ids;
	foreach my $sfn (keys %wantmap) {
		local $sf = $namemap{$sfn};
		local @wantids = map { $_->[0] } @{$wantmap{$sfn}};
		local @wantidxs = map { $_->[1] } @{$wantmap{$sfn}};
		local @sfmail = &mailbox_select_mails($sf, \@wantids,
						      $headersonly);
		for(my $i=0; $i<@sfmail; $i++) {
			$mail[$wantidxs[$i]] = $sfmail[$i];
			if ($sfmail[$i]) {
				# Original mail exists .. add to results
				$sfmail[$i]->{'id'} =
					$sfn."\t".$sfmail[$i]->{'id'};
				$sfmail[$i]->{'idx'} = &indexof(
					$sfmail[$i]->{'id'}, @allids);
				print DEBUG "looking for ",$sfmail[$i]->{'id'}," found at ",$sfmail[$i]->{'idx'},"\n";
				}
			else {
				# Take out of virtual folder index
				print DEBUG "underlying email $sfn $wantids[$i] is gone!\n";
				$mems = [ grep { $_->[0] ne $sf ||
					 $_->[1] ne $wantids[$i] } @$mems ];
				$changed = 1;
				}
			}
		}
	if ($changed && $folder->{'type'} == 6) {
		# Need to save virtual folder
		$folder->{'members'} = $mems;
		&save_folder($folder, $folder);
		}
	}
elsif ($folder->{'type'} == 7) {
	# MBX folder
	@mail = &select_mbxfile($folder->{'file'}, $ids, $headersonly);
	}
&switch_from_folder_user($_[0]);
return @mail;
}

# mailbox_get_mail(&folder, id, headersonly)
# Convenience function to get a single mail by ID
sub mailbox_get_mail
{
local ($folder, $id, $headersonly) = @_;
local ($mail) = &mailbox_select_mails($folder, [ $id ], $headersonly);
if ($mail) {
	# Find the sort index for this message
	local ($field, $dir) = &get_sort_field($folder);
	if (!$field || !$folder->{'sortable'}) {
		# No sorting, so sort index is the opposite of real
		$mail->{'sortidx'} = &mailbox_folder_size($folder, 1) -
				     $mail->{'idx'} - 1;
		print DEBUG "idx=$mail->{'idx'} sortidx=$mail->{'sortidx'} size=",&mailbox_folder_size($folder, 1),"\n";
		}
	else {
		# Need to extract from sort index
		local @sorter = &build_sorted_ids($folder, $field, $dir);
		$mail->{'sortidx'} = &indexof($id, @sorter);
		}
	}
return $mail;
}

# mailbox_idlist(&folder)
# Returns a list of IDs of messages in some folder
sub mailbox_idlist
{
local ($folder) = @_;
&switch_to_folder_user($_[0]);
my @idlist;
if ($folder->{'type'} == 0) {
	# mbox, for which IDs are mail positions
	print DEBUG "starting to get IDs from $folder->{'file'}\n";
	@idlist = &idlist_mails($folder->{'file'});
	print DEBUG "got ",scalar(@idlist)," ids\n";
	}
elsif ($folder->{'type'} == 1) {
	# maildir, for which IDs are filenames
	@idlist = &idlist_maildir($folder->{'file'});
	}
elsif ($folder->{'type'} == 2) {
	# pop3, for which IDs are uidls
	local @rv = &pop3_login($folder);
	if ($rv[0] != 1) {
		# Failed to connect or login
		if ($rv[0] == 0) { &error($rv[1]); }
		else { &error(&text('save_elogin', $rv[1])); }
		}
	local $h = $rv[1];
	@idlist = &pop3_uidl($h);
	}
elsif ($folder->{'type'} == 3) {
	# MH directory, for which IDs are file numbers
	@idlist = &idlist_mhdir($folder->{'file'});
	}
elsif ($folder->{'type'} == 4) {
	# IMAP, for which IDs are IMAP UIDs
	local @rv = &imap_login($folder);
	if ($rv[0] != 1) {
		# Something went wrong
		if ($rv[0] == 0) { &error($rv[1]); }
		elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
		elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
		}
	local $h = $rv[1];
	local $count = $rv[2];
	return () if (!$count);
        $folder->{'lastchange'} = $irv[3] if ($irv[3]);

	@rv = &imap_command($h, "FETCH 1:$count UID");
	foreach my $uid (@{$rv[1]}) {
		if ($uid =~ /UID\s+(\d+)/) {
			push(@idlist, $1);
			}
		}
	}
elsif ($folder->{'type'} == 5) {
	# Composite, IDs come from sub-folders
	foreach my $sf (@{$folder->{'subfolders'}}) {
		local $sfn = &folder_name($sf);
		push(@idlist, map { $sfn."\t".$_ } &mailbox_idlist($sf));
		}
	}
elsif ($folder->{'type'} == 6) {
	# Virtual, IDs come from sub-folders (where they exist)
	my (%wantmap, %namemap);
	foreach my $m (@{$folder->{'members'}}) {
		local $sf = $m->[0];
		local $sid = $m->[1];
		local $sfn = &folder_name($sf);
		push(@{$wantmap{$sfn}}, $sid);
		$namemap{$sfn} = $sf;
		}
	foreach my $sfn (keys %wantmap) {
		local %wantids = map { $_, 1 } @{$wantmap{$sfn}};
		local $sf = $namemap{$sfn};
		foreach my $sfid (&mailbox_idlist($sf)) {
			if ($wantids{$sfid}) {
				push(@idlist, $sfn."\t".$sfid);
				}
			}
		}
	}
&switch_from_folder_user($_[0]);
return @idlist;
}

# compute_start_end(start, end, count)
# Given start and end indexes (which may be negative or undef), returns the
# real mail file indexes.
sub compute_start_end
{
local ($start, $end, $count) = @_;
if (!defined($start)) {
	return (0, $count-1);
	}
elsif ($end < 0) {
	local $rstart = $count+$_[1]-1;
	local $rend = $count+$_[0]-1;
	$rstart = $rstart < 0 ? 0 : $rstart;
	$rend = $count - 1 if ($rend >= $count);
	return ($rstart, $rend);
	}
else {
	local $rend = $_[1];
	$rend = $count - 1 if ($rend >= $count);
	return ($start, $rend);
	}
}

# mailbox_list_mails_sorted(start, end, &folder, [headeronly], [&error],
#			    [sort-field, sort-dir])
# Returns messages in a folder within the given range, but sorted by the
# given field and condition.
sub mailbox_list_mails_sorted
{
local ($start, $end, $folder, $headersonly, $error, $field, $dir) = @_;
print DEBUG "mailbox_list_mails_sorted from $start to $end\n";
if (!$field) {
	# Default to current ordering
	($field, $dir) = &get_sort_field($folder);
	}
if (!$field || !$folder->{'sortable'}) {
	# No sorting .. just return newest first
	local @rv = reverse(&mailbox_list_mails(
		-$start, -$end-1, $folder, $headersonly, $error));
	local $i = 0;
	foreach my $m (@rv) {
		$m->{'sortidx'} = $i++;
		}
	return @rv;
	}

# For IMAP, login first so that the lastchange can be found
if ($folder->{'type'} == 4 && !$folder->{'lastchange'}) {
	&mailbox_select_mails($folder, [ ], 1);
	}

# Get a sorted list of IDs, and then find the real emails within the range
local @sorter = &build_sorted_ids($folder, $field, $dir);
($start, $end) = &compute_start_end($start, $end, scalar(@sorter));
print DEBUG "for ",&folder_name($folder)," sorter = ",scalar(@sorter),"\n";
print DEBUG "start = $start end = $end\n";
local @rv = map { undef } (0 .. scalar(@sorter)-1);
local @wantids = map { $sorter[$_] } ($start .. $end);
print DEBUG "wantids = ",scalar(@wantids),"\n";
local @mails = &mailbox_select_mails($folder, \@wantids, $headersonly);
for(my $i=0; $i<@mails; $i++) {
	$rv[$start+$i] = $mails[$i];
	print DEBUG "setting $start+$i to ",$mails[$i]," id ",$wantids[$i],"\n";
	$mails[$i]->{'sortidx'} = $start+$i;
	}
print DEBUG "rv = ",scalar(@rv),"\n";
return @rv;
}

# build_sorted_ids(&folder, field, dir)
# Returns a list of message IDs in some folder, sorted on some field
sub build_sorted_ids
{
local ($folder, $field, $dir) = @_;

# Delete old sort indexes
&delete_old_sort_index($folder);

# Build or update the sort index. This is a file mapping unique IDs and fields
# to sortable values.
local %index;
&build_new_sort_index($folder, $field, \%index);

# Get message indexes, sorted by the field
my @sorter;
while(my ($k, $v) = each %index) {
	if ($k =~ /^(.*)_\Q$field\E$/) {
		push(@sorter, [ $1, lc($v) ]);
		}
	}
if ($field eq "size" || $field eq "date" || $field eq "x-spam-status") {
	# Numeric sort
	@sorter = sort { my $s = $a->[1] <=> $b->[1]; $dir ? $s : -$s } @sorter;
	}
else {
	# Alpha sort
	@sorter = sort { my $s = $a->[1] cmp $b->[1]; $dir ? $s : -$s } @sorter;
	}
return map { $_->[0] } @sorter;
}

# delete_old_sort_index(&folder)
# Delete old index DBM files
sub delete_old_sort_index
{
local ($folder) = @_;
local $ifile = &folder_sort_index_file($folder);
$ifile =~ /^(.*)\/([^\/]+)$/;
local ($idir, $iname) = ($1, $2);
opendir(IDIR, $idir);
foreach my $f (readdir(IDIR)) {
	if ($f eq $iname || $f =~ /^\Q$iname\E\.[^\.]+$/) {
		unlink("$idir/$f");
		}
	}
closedir(IDIR);
}

# build_new_sort_index(&folder, field, &index)
# Builds and/or loads the index for sorting a folder on some field. The
# index uses the mail number as the key, and the field value as the value.
sub build_new_sort_index
{
local ($folder, $field, $index) = @_;
return 0 if (!$folder->{'sortable'});
local $ifile = &folder_new_sort_index_file($folder);

&open_dbm_db($index, $ifile, 0600);
print DEBUG "indexchange=$index->{'lastchange'} folderchange=$folder->{'lastchange'}\n";
if ($index->{'lastchange'} != $folder->{'lastchange'} ||
    !$folder->{'lastchange'}) {
	# The mail file has changed .. get IDs and update the index with any
	# that are missing
	local @ids = &mailbox_idlist($folder);

	# Find IDs that are new
	local @newids;
	foreach my $id (@ids) {
		if (!defined($index->{$id."_size"})) {
			push(@newids, $id);
			}
		}
	local @mails = scalar(@newids) ?
			&mailbox_select_mails($folder, \@newids, 1) : ( );
	foreach my $mail (@mails) {
		foreach my $f (@index_fields) {
			if ($f eq "date") {
				# Convert date to Unix time
				$index->{$mail->{'id'}."_date"} =
				  &parse_mail_date($mail->{'header'}->{'date'});
				}
			elsif ($f eq "size") {
				# Get mail size
				$index->{$mail->{'id'}."_size"} =
					$mail->{'size'};
				}
			elsif ($f eq "from" || $f eq "to") {
				# From: header .. convert to display version
				$index->{$mail->{'id'}."_".$f} =
					&simplify_from($mail->{'header'}->{$f});
				}
			elsif ($f eq "subject") {
				# Convert subject to display version
				$index->{$mail->{'id'}."_".$f} =
				    &simplify_subject($mail->{'header'}->{$f});
				}
			elsif ($f eq "x-spam-status") {
				# Extract spam score
				$index->{$mail->{'id'}."_".$f} =
					$mail->{'header'}->{$f} =~ /(hits|score)=([0-9\.]+)/ ? $2 : undef;
				}
			else {
				# Just a header
				$index->{$mail->{'id'}."_".$f} =
					$mail->{'header'}->{$f};
				}
			}
		}
	print DEBUG "added ",scalar(@mails)," messages to index\n";

	# Remove IDs that no longer exist
	local %ids = map { $_, 1 } (@ids, @wantids);
	local $dc = 0;
	local @todelete;
	while(my ($k, $v) = each %$index) {
		if ($k =~ /^(.*)_([^_]+)$/ && !$ids{$1}) {
			push(@todelete, $k);
			$dc++ if ($2 eq "size");
			}
		}
	foreach my $k (@todelete) {
		delete($index->{$k});
		}
	print DEBUG "deleted $dc messages from index\n";

	# Record index update time
	$index->{'lastchange'} = $folder->{'lastchange'} || time();
	$index->{'mailcount'} = scalar(@ids);
	print DEBUG "new indexchange=$index->{'lastchange'}\n";
	}
return 1;
}

# delete_new_sort_index_message(&folder, id)
# Removes a message ID from a sort index
sub delete_new_sort_index_message
{
local ($folder, $id) = @_;
local %index;
&build_new_sort_index($folder, undef, \%index);
foreach my $field (@index_fields) {
	delete($index{$id."_".$field});
	}
dbmclose(%index);
if ($folder->{'type'} == 5 || $folder->{'type'} == 6) {
	# Remove from underlying folder's index too
	local ($sfn, $sid) = split(/\t+/, $id, 2);
	local $sf = &find_subfolder($folder, $sfn);
	if ($sf) {
		&delete_new_sort_index_message($sf, $sid);
		}
	}
}

# force_new_index_recheck(&folder)
# Resets the last-updated time on a folder's index, to force a re-check
sub force_new_index_recheck
{
local ($folder) = @_;
local %index;
&build_new_sort_index($folder, undef, \%index);
$index{'lastchange'} = 0;
dbmclose(%index);
}

# delete_new_sort_index(&folder)
# Trashes the sort index for a folder, to force a rebuild
sub delete_new_sort_index
{
local ($folder) = @_;
local $ifile = &folder_new_sort_index_file($folder);

my %index;
&open_dbm_db(\%index, $ifile, 0600);
%index = ( );
}

# folder_sort_index_file(&folder)
# Returns the index file to use for some folder
sub folder_sort_index_file
{
local ($folder) = @_;
return &user_index_file(($folder->{'file'} || $folder->{'id'}).".sort");
}

# folder_new_sort_index_file(&folder)
# Returns the new ID-style index file to use for some folder
sub folder_new_sort_index_file
{
local ($folder) = @_;
return &user_index_file(($folder->{'file'} || $folder->{'id'}).".byid");
}

# mailbox_search_mail(&fields, andmode, &folder, [&limit], [headersonly])
# Search a mailbox for multiple matching fields
sub mailbox_search_mail
{
local ($fields, $andmode, $folder, $limit, $headersonly) = @_;

# For folders other than IMAP and composite and mbox where we already have
# an index, build a sort index and use that for
# the search, if it is simple enough (Subject, From and To only)
local @idxfields = grep { $_->[0] eq 'from' || $_->[0] eq 'to' ||
                          $_->[0] eq 'subject' } @{$_[0]};
if ($folder->{'type'} != 4 &&
    $folder->{'type'} != 5 &&
    $folder->{'type'} != 6 &&
    ($folder->{'type'} != 0 || !&has_dbm_index($folder->{'file'})) &&
    scalar(@idxfields) == scalar(@$fields) && @idxfields &&
    &get_product_name() eq 'usermin') {
	print DEBUG "using index to search\n";
	local %index;
	&build_new_sort_index($folder, undef, \%index);
	local @rv;

	# Work out which mail IDs match the requested headers
	local %idxmatches = map { ("$_->[0]/$_->[1]", [ ]) } @idxfields;
	while(my ($k, $v) = each %index) {
		$k =~ /^(.+)_(\S+)$/ || next;
                local ($ki, $kf) = ($1, $2);
                next if (!$kf || $ki eq '');

		# Check all of the fields to see which ones match
		foreach my $if (@idxfields) {
			local $iff = $if->[0];
			local ($neg) = ($iff =~ s/^\!//);
			next if ($kf ne $iff);
			local $re = $if->[2] ? $if->[1] : "\Q$if->[1]\E";
			if (!$neg && $v =~ /$re/i ||
			    $neg && $v !~ /$re/i) {
				push(@{$idxmatches{"$if->[0]/$if->[1]"}}, $ki);
				}
			}
		}
	local @matches;
	if ($_[1]) {
		# Find indexes in all arrays
		local %icount;
		foreach my $if (keys %idxmatches) {
			foreach my $i (@{$idxmatches{$if}}) {
				$icount{$i}++;
				}
			}
		foreach my $i (keys %icount) {
			}
		local $fif = $idxfields[0];
		@matches = grep { $icount{$_} == scalar(@idxfields) }
				@{$idxmatches{"$fif->[0]/$fif->[1]"}};
		}
	else {
		# Find indexes in any array
		foreach my $if (keys %idxmatches) {
			push(@matches, @{$idxmatches{$if}});
			}
		@matches = &unique(@matches);
		}
	@matches = sort { $a cmp $b } @matches;
	print DEBUG "matches = ",join(" ", @matches),"\n";

	# Select the actual mails
	return &mailbox_select_mails($_[2], \@matches, $headersonly);
	}

if ($folder->{'type'} == 0) {
	# Just search an mbox format file (which will use its own special
	# field-level index)
	return &advanced_search_mail($folder->{'file'}, $fields,
				     $andmode, $limit, $headersonly);
	}
elsif ($folder->{'type'} == 1) {
	# Search a maildir directory
	return &advanced_search_maildir($folder->{'file'}, $fields,
				        $andmode, $limit, $headersonly);
	}
elsif ($folder->{'type'} == 2) {
	# Get all of the mail from the POP3 server and search it
	local ($min, $max);
	if ($limit && $limit->{'latest'}) {
		$min = -1;
		$max = -$limit->{'latest'};
		}
	local @mails = &mailbox_list_mails($min, $max, $folder,
			&indexof('body', &search_fields($fields)) < 0 &&
			$headersonly);
	local @rv = grep { $_ && &mail_matches($fields, $andmode, $_) } @mails;
	}
elsif ($folder->{'type'} == 3) {
	# Search an MH directory
	return &advanced_search_mhdir($folder->{'file'}, $fields,
				      $andmode, $limit, $headersonly);
	}
elsif ($folder->{'type'} == 4) {
	# Use IMAP's remote search feature
	local @rv = &imap_login($_[2]);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
	local $h = $rv[1];
        $_[2]->{'lastchange'} = $rv[3] if ($rv[3]);

	# Do the search to get back a list of matching numbers
	local @search;
	foreach $f (@{$_[0]}) {
		local $field = $f->[0] eq "date" ? "on" : $f->[0];
		local $neg = ($field =~ s/^\!//);
		local $what = $f->[1];
		if ($field ne "size") {
			$what = "\"".$what."\""
			}
		$field = "LARGER" if ($field eq "size");
		local $search;
		if ($field =~ /^X-/i) {
			$search = "header ".uc($field)." ".$what."";
			}
		else {
			$search = uc($field)." ".$what."";
			}
		$search = "NOT $search" if ($neg);
		push(@searches, $search);
		}
	local $searches;
	if (@searches == 1) {
		$searches = $searches[0];
		}
	elsif ($_[1]) {
		$searches = join(" ", @searches);
		}
	else {
		$searches = $searches[$#searches];
		for($i=$#searches-1; $i>=0; $i--) {
			$searches = "or $searches[$i] ($searches)";
			}
		}
	@rv = &imap_command($h, "UID SEARCH $searches");
	&error(&text('save_esearch', $rv[3])) if (!$rv[0]);

	# Get back the IDs we want
	local ($srch) = grep { $_ =~ /^\*\s+SEARCH/i } @{$rv[1]};
	local @ids = split(/\s+/, $srch);
	shift(@ids); shift(@ids);	# lose * SEARCH

	# Call the select function to get the mails
	return &mailbox_select_mails($folder, \@ids, $headersonly);
	}
elsif ($folder->{'type'} == 5) {
	# Search each sub-folder and combine the results - taking any count
	# limits into effect
	local $sf;
	local $pos = 0;
	local @mail;
	local (%start, %len);
	foreach $sf (@{$folder->{'subfolders'}}) {
		$len{$sf} = &mailbox_folder_size($sf);
		$start{$sf} = $pos;
		$pos += $len{$sf};
		}
	local $limit = $limit ? { %$limit } : undef;
	$limit = undef;
	foreach $sf (reverse(@{$folder->{'subfolders'}})) {
		local $sfn = &folder_name($sf);
		print DEBUG "searching on sub-folder ",&folder_name($sf),"\n";
		local @submail = &mailbox_search_mail($fields, $andmode, $sf,
					$limit, $headersonly);
		print DEBUG "found ",scalar(@submail),"\n";
		foreach my $sm (@submail) {
			$sm->{'id'} = $sfn."\t".$sm->{'id'};
			}
		push(@mail, reverse(@submail));
		if ($limit && $limit->{'latest'}) {
			# Adjust latest down by size of this folder
			$limit->{'latest'} -= $len{$sf};
			last if ($limit->{'latest'} <= 0);
			}
		}
	return reverse(@mail);
	}
elsif ($folder->{'type'} == 6) {
	# Just run a search on the sub-mails
	local @rv;
	local ($min, $max);
	if ($limit && $limit->{'latest'}) {
		$min = -1;
		$max = -$limit->{'latest'};
		}
	local $mail;
	local $sfn = &folder_name($sf);
	print DEBUG "searching virtual folder ",&folder_name($folder),"\n";
	foreach $mail (&mailbox_list_mails($min, $max, $folder)) {
		if ($mail && &mail_matches($fields, $andmode, $mail)) {
			push(@rv, $mail);
			}
		}
	return @rv;
	}
}

# mailbox_delete_mail(&folder, mail, ...)
# Delete multiple messages from some folder
sub mailbox_delete_mail
{
return undef if (&is_readonly_mode());
local $f = shift(@_);
&switch_to_folder_user($f);
if ($userconfig{'delete_mode'} == 1 && !$f->{'trash'} && !$f->{'spam'} &&
    !$f->{'notrash'}) {
	# Copy to trash folder first .. if we have one
	local ($trash) = grep { $_->{'trash'} } &list_folders();
	if ($trash) {
		my $r;
		my $save_read = &get_product_name() eq "usermin";
		foreach my $m (@_) {
			$r = &get_mail_read($f, $m) if ($save_read);
			my $mcopy = { %$m };	  # Because writing changes id
			&write_mail_folder($mcopy, $trash);
			&set_mail_read($trash, $mcopy, $r) if ($save_read);
			}
		}
	}

if ($f->{'type'} == 0) {
	# Delete from mbox
	&delete_mail($f->{'file'}, @_);
	}
elsif ($f->{'type'} == 1) {
	# Delete from Maildir
	&delete_maildir(@_);
	}
elsif ($f->{'type'} == 2) {
	# Login and delete from the POP3 server
	local @rv = &pop3_login($f);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin', $rv[1])); }
	local $h = $rv[1];
	local @uidl = &pop3_uidl($h);
	local $m;
	local $cd = &get_folder_cache_directory($f);
	foreach $m (@_) {
		local $idx = &indexof($m->{'id'}, @uidl);
		if ($idx >= 0) {
			&pop3_command($h, "dele ".($idx+1));
			local $u = &safe_uidl($m->{'id'});
			unlink("$cd/$u.headers", "$cd/$u.body");
			}
		}
	}
elsif ($f->{'type'} == 3) {
	# Delete from MH dir
	&delete_mhdir(@_);
	}
elsif ($f->{'type'} == 4) {
	# Delete from the IMAP server
	local @rv = &imap_login($f);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
	local $h = $rv[1];

	local $m;
	foreach $m (@_) {
		@rv = &imap_command($h, "UID STORE ".$m->{'id'}.
					" +FLAGS (\\Deleted)");
		&error(&text('save_edelete', $rv[3])) if (!$rv[0]);
		}
	@rv = &imap_command($h, "EXPUNGE");
	&error(&text('save_edelete', $rv[3])) if (!$rv[0]);
	}
elsif ($f->{'type'} == 5 || $f->{'type'} == 6) {
	# Delete from underlying folder(s), and from virtual index
	foreach my $sm (@_) {
		local ($sfn, $sid) = split(/\t+/, $sm->{'id'}, 2);
		local $sf = &find_subfolder($f, $sfn);
		$sf || &error("Failed to find sub-folder named $sfn");
		if ($f->{'type'} == 5 || $f->{'type'} == 6 && $f->{'delete'}) {
			$sm->{'id'} = $sid;
			&mailbox_delete_mail($sf, $sm);
			$sm->{'id'} = $sfn."\t".$sm->{'id'};
			}
		if ($f->{'type'} == 6) {
			$f->{'members'} = [
				grep { $_->[0] ne $sf ||
				       $_->[1] ne $sid } @{$f->{'members'}} ];
			}
		}
	if ($f->{'type'} == 6) {
		# Save new ID list
		&save_folder($f, $f);
		}
	}
&switch_from_folder_user($f);

# Always force a re-check of the index when deleting, as we may not detect
# the change (especially for IMAP, where UIDNEXT may not change). This isn't
# needed for Maildir or MH, as indexing is reliable enough
if ($f->{'type'} != 1 && $f->{'type'} != 3) {
	&force_new_index_recheck($f);
	}
}

# mailbox_empty_folder(&folder)
# Remove the entire contents of a mail folder
sub mailbox_empty_folder
{
return undef if (&is_readonly_mode());
local $f = $_[0];
&switch_to_folder_user($f);
if ($f->{'type'} == 0) {
	# mbox format mail file
	&empty_mail($f->{'file'});
	}
elsif ($f->{'type'} == 1) {
	# qmail format maildir
	&empty_maildir($f->{'file'});
	}
elsif ($f->{'type'} == 2) {
	# POP3 server .. delete all messages
	local @rv = &pop3_login($f);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin', $rv[1])); }
	local $h = $rv[1];
	@rv = &pop3_command($h, "stat");
	$rv[1] =~ /^(\d+)/ || return;
	local $count = $1;
	local $i;
	for($i=1; $i<=$count; $i++) {
		&pop3_command($h, "dele ".$i);
		}
	}
elsif ($f->{'type'} == 3) {
	# mh format maildir
	&empty_mhdir($f->{'file'});
	}
elsif ($f->{'type'} == 4) {
	# IMAP server .. delete all messages
	local @rv = &imap_login($f);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
	local $h = $rv[1];
	local $count = $rv[2];
	local $i;
	for($i=1; $i<=$count; $i++) {
		@rv = &imap_command($h, "STORE ".$i.
					" +FLAGS (\\Deleted)");
		&error(&text('save_edelete', $rv[3])) if (!$rv[0]);
		}
	@rv = &imap_command($h, "EXPUNGE");
	&error(&text('save_edelete', $rv[3])) if (!$rv[0]);
	}
elsif ($f->{'type'} == 5) {
	# Empty each sub-folder
	local $sf;
	foreach $sf (@{$f->{'subfolders'}}) {
		&mailbox_empty_folder($sf);
		}
	}
elsif ($f->{'type'} == 6) {
	if ($folder->{'delete'}) {
		# Delete all underlying messages
		local @dmails = &mailbox_list_mails(undef, undef, $f, 1);
		&mailbox_delete_mail($f, @dmails);
		}
	else {
		# Clear the virtual index
		$f->{'members'} = [ ];
		&save_folder($f);
		}
	}
&switch_from_folder_user($f);

# Trash the folder index
if ($folder->{'sortable'}) {
	&delete_new_sort_index($folder);
	}
}

# mailbox_copy_folder(&source, &dest)
# Copy all messages from one folder to another. This is done in an optimized
# way if possible.
sub mailbox_copy_folder
{
local ($src, $dest) = @_;
if ($src->{'type'} == 0 && $dest->{'type'} == 0) {
	# mbox to mbox .. just read and write the files
	&switch_to_folder_user($src);
	&open_as_mail_user(SOURCE, $src->{'file'});
	&switch_from_folder_user($src);
	&switch_to_folder_user($dest);
	&open_as_mail_user(DEST, ">>$dest->{'file'}");
	while(read(SOURCE, $buf, 32768) > 0) {
		print DEST $buf;
		}
	close(DEST);
	close(SOURCE);
	&switch_from_folder_user($dest);
	}
elsif ($src->{'type'} == 1 && $dest->{'type'} == 1) {
	# maildir to maildir .. just copy the files
	local @files = &get_maildir_files($src->{'file'});
	foreach my $f (@files) {
		local $fn = &unique_maildir_filename($dest);
		&copy_source_dest_as_mail_user($f, "$dest->{'file'}/$fn");
		}
	&mailbox_fix_permissions($dest);
	}
elsif ($src->{'type'} == 1 && $dest->{'type'} == 0) {
	# maildir to mbox .. append all the files
	&switch_to_folder_user($dest);
	&open_as_mail_user(DEST, ">>$dest->{'file'}");
	&switch_from_folder_user($dest);
	local $fromline = &make_from_line("webmin\@example.com")."\n";
	&switch_to_folder_user($src);
	local @files = &get_maildir_files($src->{'file'});
	foreach my $f (@files) {
		&open_as_mail_user(SOURCE, $f);
		print DEST $fromline;
		while(read(SOURCE, $buf, 1024) > 0) {
			print DEST $buf;
			}
		close(SOURCE);
		}
	close(DEST);
	&switch_from_folder_user($src);
	}
else {
	# read in all mail and write out, in 100 message blocks
	local $max = &mailbox_folder_size($src);
	for(my $s=0; $s<$max; $s+=100) {
		local $e = $s+99;
		$e = $max-1 if ($e >= $max);
		local @mail = &mailbox_list_mails($s, $e, $src);
		local @want = @mail[$s..$e];
		&mailbox_copy_mail($src, $dest, @want);
		}
	}
}

# mailbox_move_mail(&source, &dest, mail, ...)
# Move mail from one folder to another
sub mailbox_move_mail
{
return undef if (&is_readonly_mode());
local $src = shift(@_);
local $dst = shift(@_);
local $now = time();
local $hn = &get_system_hostname();
local $fix_index;
if (($src->{'type'} == 1 || $src->{'type'} == 3) && $dst->{'type'} == 1) {
	# Can just move mail files to Maildir names
	if ($src->{'user'} eq $dst->{'user'}) {
		&switch_to_folder_user($dst);
		}
	&create_folder_maildir($dst);
	local $dd = $dst->{'file'};
	foreach my $m (@_) {
		&rename_as_mail_user($m->{'file'}, "$dd/cur/$now.$$.$hn");
		$now++;
		}
	&mailbox_fix_permissions($dst);
	if ($src->{'user'} eq $dst->{'user'}) {
		&switch_from_folder_user($dst);
		}
	$fix_index = 1;
	}
elsif (($src->{'type'} == 1 || $src->{'type'} == 3) && $dst->{'type'} == 3) {
	# Can move and rename to MH numbering
	if ($src->{'user'} eq $dst->{'user'}) {
		&switch_to_folder_user($dst);
		}
	&create_folder_maildir($dst);
	local $dd = $dst->{'file'};
	local $num = &max_mhdir($dst->{'file'}) + 1;
	foreach my $m (@_) {
		&rename_as_mail_user($m->{'file'}, "$dd/$num");
		$num++;
		}
	&mailbox_fix_permissions($dst);
	if ($src->{'user'} eq $dst->{'user'}) {
		&switch_from_folder_user($dst);
		}
	$fix_index = 1;
	}
else {
	# Append to new folder file, or create in folder directory
	my @mdel;
	my $r;
	my $save_read = &get_product_name() eq "usermin";
	&switch_to_folder_user($dst);
	&create_folder_maildir($dst);
	foreach my $m (@_) {
		$r = &get_mail_read($src, $m) if ($save_read);
		my $mcopy = { %$m };
		&write_mail_folder($mcopy, $dst);
		&set_mail_read($dst, $mcopy, $r) if ($save_read);
		push(@mdel, $m);
		}
	local $src->{'notrash'} = 1;	# Prevent saving to trash
	&switch_from_folder_user($dst);
	&mailbox_delete_mail($src, @mdel);
	}
}

# mailbox_fix_permissions(&folder, [&stat])
# Set the ownership on all files in a folder correctly, either based on its
# current stat or a structure passed in.
sub mailbox_fix_permissions
{
local ($f, $st) = @_;
return 0 if ($< != 0);			# Only makes sense when running as root
return 0 if ($main::mail_open_user);	# File ops are already done as the
					# correct user
$st ||= [ stat($f->{'file'}) ];
if ($f->{'type'} == 0) {
	# Set perms on a single file
	&set_ownership_permissions($st->[4], $st->[5], $st->[2], $f->{'file'});
	return 1;
	}
elsif ($f->{'type'} == 1 || $f->{'type'} == 3) {
	# Do a whole directory
	&execute_command("chown -R $st->[4]:$st->[5] ".
			 quotemeta($dst->{'file'}));
	return 1;
	}
return 0;
}

# mailbox_move_folder(&source, &dest)
# Moves all mail from one folder to another, possibly converting the type
sub mailbox_move_folder
{
local ($src, $dst) = @_;
return undef if (&is_readonly_mode());
&switch_to_folder_user($dst);
if ($src->{'type'} == $dst->{'type'} && !$src->{'remote'}) {
	# Can just move the file or dir
	local @st = stat($src->{'file'});
	&unlink_file($dst->{'file'});
	&rename_as_mail_user($src->{'file'}, $dst->{'file'});
	if (@st) {
		&mailbox_fix_permissions($dst, \@st);
		}
	}
elsif (($src->{'type'} == 1 || $src->{'type'} == 3) && $dst->{'type'} == 0) {
	# For Maildir or MH to mbox moves, just append files
	local @files = $src->{'type'} == 1 ? &get_maildir_files($src->{'file'})
					   : &get_mhdir_files($src->{'file'});
	&open_as_mail_user(DEST, ">>$dst->{'file'}");
	local $fromline = &make_from_line("webmin\@example.com");
	foreach my $f (@files) {
		&open_as_mail_user(SOURCE, $f);
		print DEST $fromline;
		while(read(SOURCE, $buf, 32768) > 0) {
			print DEST $buf;
			}
		close(SOURCE);
		&unlink_as_mail_user($f);
		}
	close(DEST);
	}
else {
	# Need to read in and write out. But do it in 1000-message blocks
	local $count = &mailbox_folder_size($src);
	local $step = 1000;
	for(my $start=0; $start<$count; $start+=$step) {
		local $end = $start + $step - 1;
		$end = $count-1 if ($end >= $count);
		local @mails = &mailbox_list_mails($start, $end, $src);
		@mails = @mails[$start..$end];
		&mailbox_copy_mail($src, $dst, @mails);
		}
	&mailbox_empty_folder($src);
	}
&switch_from_folder_user($dst);

# Delete source folder index
if ($src->{'sortable'}) {
	&delete_new_sort_index($src);
	}
}

# mailbox_copy_mail(&source, &dest, mail, ...)
# Copy mail from one folder to another
sub mailbox_copy_mail
{
return undef if (&is_readonly_mode());
local $src = shift(@_);
local $dst = shift(@_);
local $now = time();
if ($src->{'type'} == 6 && $dst->{'type'} == 6) {
	# Copying from one virtual folder to another, so just copy the
	# reference
	foreach my $m (@_) {
		push(@{$dst->{'members'}}, [ $m->{'subfolder'}, $m->{'subid'},
					     $m->{'header'}->{'message-id'} ]);
		}
	}
elsif ($dst->{'type'} == 6) {
	# Add this mail to the index of the virtual folder
	foreach my $m (@_) {
		push(@{$dst->{'members'}}, [ $src, $m->{'idx'},
					     $m->{'header'}->{'message-id'} ]);
		}
	&save_folder($dst);
	}
else {
	# Just write to destination folder. The read status is preserved, but
	# only if in Usermin.
	my $r;
	my $save_read = &get_product_name() eq "usermin";
	&switch_to_folder_user($dst);
	&create_folder_maildir($dst);
	foreach my $m (@_) {
		$r = &get_mail_read($src, $m) if ($save_read);
		my $mcopy = { %$m };
		&write_mail_folder($mcopy, $dst);
		&set_mail_read($dst, $mcopy, $r) if ($save_read);
		}
	&switch_from_folder_user($dst);
	}
}

# folder_type(file_or_dir)
# Returns a numeric folder type based on the contents
sub folder_type
{
my ($f) = @_;
if (-d "$f/cur") {
	# Maildir directory
	return 1;
	}
elsif (-d $f) {
	# MH directory
	return 3;
	}
else {
	# Check for MBX format
	open(MBXTEST, "<", $f);
	my $first;
	read(MBXTEST, $first, 5);
	close(MBXTEST);
	return $first eq "*mbx*" ? 7 : 0;
	}
}

# create_folder_maildir(&folder)
# Ensure that a maildir folder has the needed new, cur and tmp directories
sub create_folder_maildir
{
if ($folders_dir) {
	mkdir($folders_dir, 0700);
	}
if ($_[0]->{'type'} == 1) {
	local $id = $_[0]->{'file'};
	&mkdir_as_mail_user($id, 0700);
	&mkdir_as_mail_user("$id/cur", 0700);
	&mkdir_as_mail_user("$id/new", 0700);
	&mkdir_as_mail_user("$id/tmp", 0700);
	}
}

# write_mail_folder(&mail, &folder, textonly)
# Writes some mail message to a folder
sub write_mail_folder
{
return undef if (&is_readonly_mode());
&switch_to_folder_user($_[1]);
&create_folder_maildir($_[1]);
local $needid;
if ($_[1]->{'type'} == 1) {
	# Add to a maildir directory. ID is set by write_maildir to the new
	# relative filename
	local $md = $_[1]->{'file'};
	&write_maildir($_[0], $md, $_[2]);
	}
elsif ($_[1]->{'type'} == 3) {
	# Create a new MH file. ID is just the new message number
	local $num = &max_mhdir($_[1]->{'file'}) + 1;
	local $md = $_[1]->{'file'};
	local @st = stat($_[1]->{'file'});
	&send_mail($_[0], "$md/$num", $_[2], 1);
	if ($< == 0) {
		&set_ownership_permissions($st[4], $st[5], undef, "$md/$num");
		}
	$_[0]->{'id'} = $num;
	}
elsif ($_[1]->{'type'} == 0) {
	# Just append to the folder file.
	&send_mail($_[0], $_[1]->{'file'}, $_[2], 1);
	$needid = 1;
	}
elsif ($_[1]->{'type'} == 4) {
	# Upload to the IMAP server
	local @rv = &imap_login($_[1]);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
	local $h = $rv[1];

	# Create a temp file and use it to create the IMAP command
	local $temp = &transname();
	&send_mail($_[0], $temp, $_[2], 0, "dummy");
	local $text = &read_file_contents($temp);
	unlink($temp);
	$text =~ s/^From.*\r?\n//;	# Not part of IMAP format
	@rv = &imap_command($h, sprintf "APPEND \"%s\" {%d}\r\n%s",
			$_[1]->{'mailbox'} || "INBOX", length($text), $text);
	&error(&text('save_eappend', $rv[3])) if (!$rv[0]);
	$needid = 1;
	}
elsif ($_[1]->{'type'} == 5) {
	# Just append to the last subfolder
	local @sf = @{$_[1]->{'subfolders'}};
	&write_mail_folder($_[0], $sf[$#sf], $_[2]);
	$needid = 1;
	}
elsif ($_[1]->{'type'} == 6) {
	# Add mail to first sub-folder, and to virtual index
	# XXX not done
	&error("Cannot add mail to virtual folders");
	}
&switch_from_folder_user($_[1]);
if ($needid) {
	# Get the ID of the new mail
	local @idlist = &mailbox_idlist($_[1]);
	print DEBUG "new idlist=",join(" ", @idlist),"\n";
	$_[0]->{'id'} = $idlist[$#idlist];
	}
}

# mailbox_modify_mail(&oldmail, &newmail, &folder, textonly)
# Replaces some mail message with a new one
sub mailbox_modify_mail
{
local ($oldmail, $mail, $folder, $textonly) = @_;
return undef if (&is_readonly_mode());
&switch_to_folder_user($_[2]);
if ($folder->{'type'} == 1) {
	# Just replace the existing file
	&modify_maildir($oldmail, $mail, $textonly);
	}
elsif ($folder->{'type'} == 3) {
	# Just replace the existing file
	&modify_mhdir($oldmail, $mail, $textonly);
	}
elsif ($folder->{'type'} == 0) {
	# Modify the mail file
	&modify_mail($folder->{'file'}, $oldmail, $mail, $textonly);
	}
elsif ($folder->{'type'} == 5 || $folder->{'type'} == 6) {
	# Modify in the underlying folder
	local ($oldsfn, $oldsid) = split(/\t+/, $oldmail->{'id'}, 2);
	local ($sfn, $sid) = split(/\t+/, $mail->{'id'}, 2);
	local $sf = &find_subfolder($folder, $sfn);
	$oldmail->{'id'} = $oldsid;
	$mail->{'id'} = $sid;
	&mailbox_modify_mail($oldmail, $mail, $sf, $textonly);
	$oldmail->{'id'} = $oldsfn."\t".$oldsid;
	$mail->{'id'} = $sfn."\t".$sid;
	}
else {
	&error("Cannot modify mail in this type of folder!");
	}
&switch_from_folder_user($_[2]);

# Delete the message being modified from its index, to force re-generation
# with new details
$mail->{'id'} = $oldmail->{'id'};	# Assume that it will replace the old
if ($folder->{'sortable'}) {
	&delete_new_sort_index_message($folder, $mail->{'id'});
	}
}

# mailbox_folder_size(&folder, [estimate])
# Returns the number of messages in some folder
sub mailbox_folder_size
{
local ($f, $est) = @_;
&switch_to_folder_user($f);
local $rv;
if ($f->{'type'} == 0) {
	# A mbox formatted file
	$rv = &count_mail($f->{'file'});
	}
elsif ($f->{'type'} == 1) {
	# A qmail maildir
	$rv = &count_maildir($f->{'file'});
	}
elsif ($f->{'type'} == 2) {
	# A POP3 server
	local @rv = &pop3_login($f);
	if ($rv[0] != 1) {
		if ($rv[0] == 0) { &error($rv[1]); }
		else { &error(&text('save_elogin', $rv[1])); }
		}
	local @st = &pop3_command($rv[1], "stat");
	if ($st[0] == 1) {
		local ($count, $size) = split(/\s+/, $st[1]);
		return $count;
		}
	else {
		&error($st[1]);
		}
	}
elsif ($f->{'type'} == 3) {
	# An MH directory
	$rv = &count_mhdir($f->{'file'});
	}
elsif ($f->{'type'} == 4) {
	# An IMAP server
	local @rv = &imap_login($f);
	if ($rv[0] != 1) {
		if ($rv[0] == 0) { &error($rv[1]); }
		elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
		elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
		}
        $f->{'lastchange'} = $rv[3];
	$rv = $rv[2];
	}
elsif ($f->{'type'} == 5) {
	# A composite folder - the size is just that of the sub-folders
	$rv = 0;
	foreach my $sf (@{$f->{'subfolders'}}) {
		$rv += &mailbox_folder_size($sf);
		}
	}
elsif ($f->{'type'} == 6 && !$est) {
	# A virtual folder .. we need to exclude messages that no longer
	# exist in the parent folders
	$rv = 0;
	foreach my $msg (@{$f->{'members'}}) {
		if (&mailbox_get_mail($msg->[0], $msg->[1])) {
			$rv++;
			}
		}
	}
elsif ($f->{'type'} == 6 && $est) {
	# A virtual folder .. but we can just use the last member count
	$rv = scalar(@{$f->{'members'}});
	}
&switch_from_folder_user($f);
return $rv;
}

# mailbox_folder_unread(&folder)
# Returns the total messages in some folder, the number unread and the number
# flagged as special.
sub mailbox_folder_unread
{
local ($folder) = @_;
if ($folder->{'type'} == 4) {
	# For IMAP, the server knows
	local @rv = &imap_login($folder);
	if ($rv[0] != 1) {
		return ( );
		}
	local @data = ( $rv[2] );
	local $h = $rv[1];
	foreach my $s ("UNSEEN", "FLAGGED") {
		@rv = &imap_command($h, "SEARCH ".$s);
		local ($srch) = grep { $_ =~ /^\*\s+SEARCH/i } @{$rv[1]};
		local @ids = split(/\s+/, $srch);
		shift(@ids); shift(@ids);	# lose * SEARCH
		push(@data, scalar(@ids));
		}
	return @data;
	}
elsif ($folder->{'type'} == 5) {
	# Composite folder - counts are sums of sub-folders
	local @data;
	foreach my $sf (@{$folder->{'subfolders'}}) {
		local @sfdata = &mailbox_folder_unread($sf);
		if (scalar(@sfdata)) {
			$data[0] += $sfdata[0];
			$data[1] += $sfdata[1];
			$data[2] += $sfdata[2];
			}
		}
	return @data;
	}
else {
	# For all other folders, just check individual messages
	# XXX faster for maildir?
	local @data = ( 0, 0, 0 );
	local @mails;
	eval {
		$main::error_must_die = 1;
		@mails = &mailbox_list_mails(undef, undef, $folder, 1);
		};
	return ( ) if ($@);
	foreach my $m (@mails) {
		local $rf = &get_mail_read($folder, $m);
		if ($rf == 2) {
			$data[2]++;
			}
		elsif ($rf == 0) {
			$data[1]++;
			}
		$data[0]++;
		}
	return @data;
	}
}

# mailbox_set_read_flags(&folder, &mail, read, special, replied)
# Updates the status flags on some message
sub mailbox_set_read_flag
{
local ($folder, $mail, $read, $special, $replied) = @_;
if ($folder->{'type'} == 4) {
	# Set flags on IMAP server
	local @rv = &imap_login($folder);
	if ($rv[0] == 0) { &error($rv[1]); }
	elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
	elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
	local $h = $rv[1];
	foreach my $f ([ $read, "\\Seen" ],
		       [ $special, "\\Flagged" ],
		       [ $replied, "\\Answered" ]) {
		print DEBUG "setting '$f->[0]' '$f->[1]' for $mail->{'id'}\n";
		next if (!defined($f->[0]));
		local $pm = $f->[0] ? "+" : "-";
		@rv = &imap_command($h, "UID STORE ".$mail->{'id'}.
					" ".$pm."FLAGS (".$f->[1].")");
		&error(&text('save_eflag', $rv[3])) if (!$rv[0]);
		}
	}
elsif ($folder->{'type'} == 1) {
	# Add flag to special characters at end of filename
	my $file = $mail->{'file'} || $mail->{'id'};
	my $path;
	if (!$mail->{'file'}) {
		$path = "$folder->{'file'}/";
		}
	my ($base, %flags);
	if ($file =~ /^(.*):2,([A-Z]*)$/) {
		$base = $1;
		%flags = map { $_, 1 } split(//, $2);
		}
	else {
		$base = $file;
		}
	$flags{'S'} = $read;
	$flags{'F'} = $special;
	$flags{'R'} = $replied if (defined($replied));
	my $newfile = $base.":2,".
			 join("", grep { $flags{$_} } sort(keys %flags));
	if ($newfile ne $file) {
		# Need to rename file
		rename("$path$file", "$path$newfile");
		$newfile =~ s/^(.*)\/((cur|tmp|new)\/.*)$/$2/;
		$mail->{'id'} = $newfile;
		&flush_maildir_cachefile($folder->{'file'});
		}
	}
else {
	&error("Read flags cannot be set on folders of type $folder->{'type'}");
	}

# Update the mail object too
$mail->{'read'} = $read if (defined($read));
$mail->{'special'} = $special if (defined($special));
$mail->{'replied'} = $replied if (defined($replied));
}

# pop3_login(&folder)
# Logs into a POP3 server and returns a status (1=ok, 0=connect failed,
# 2=login failed) and handle or error message
sub pop3_login
{
local $h = $pop3_login_handle{$_[0]->{'id'}};
return (1, $h) if ($h);
$h = "POP3".time().++$pop3_login_count;
local $error;
&open_socket($_[0]->{'server'}, $_[0]->{'port'} || 110, $h, \$error);
print DEBUG "pop3 open_socket to $_[0]->{'server'} : $error\n";
return (0, $error) if ($error);
local $os = select($h); $| = 1; select($os);
local @rv = &pop3_command($h);
return (0, $rv[1]) if (!$rv[0]);
local $user = $_[0]->{'user'} eq '*' ? $remote_user : $_[0]->{'user'};
@rv = &pop3_command($h, "user $user");
return (2, $rv[1]) if (!$rv[0]);
@rv = &pop3_command($h, "pass $_[0]->{'pass'}");
return (2, $rv[1]) if (!$rv[0]);
return (1, $pop3_login_handle{$_[0]->{'id'}} = $h);
}

# pop3_command(handle, command)
# Executes a command and returns the status (1 or 0 for OK or ERR) and message
sub pop3_command
{
local ($h, $c) = @_;
print $h "$c\r\n" if ($c);
local $rv = <$h>;
$rv =~ s/\r|\n//g;
print DEBUG "pop3 $c -> $rv\n";
return !$rv ? ( 0, "Connection closed" ) :
       $rv =~ /^\+OK\s*(.*)/ ? ( 1, $1 ) :
       $rv =~ /^\-ERR\s*(.*)/ ? ( 0, $1 ) : ( 0, $rv );
}

# pop3_logout(handle, doquit)
sub pop3_logout
{
local @rv = $_[1] ? &pop3_command($_[0], "quit") : (1, undef);
local $f;
foreach $f (keys %pop3_login_handle) {
	delete($pop3_login_handle{$f}) if ($pop3_login_handle{$f} eq $_[0]);
	}
close($_[0]);
return @rv;
}

# pop3_uidl(handle)
# Returns the uidl list
sub pop3_uidl
{
local @rv;
local $h = $_[0];
local @urv = &pop3_command($h, "uidl");
if (!$urv[0] && $urv[1] =~ /not\s+implemented/i) {
	# UIDL is not available?! Use numeric list instead
	&pop3_command($h, "list");
	while(<$h>) {
		s/\r//g;
		last if ($_ eq ".\n");
		if (/^(\d+)\s+(\d+)/) {
			push(@rv, "size$2");
			}
		}
	}
elsif (!$urv[0]) {
	&error("uidl failed! $urv[1]") if (!$urv[0]);
	}
else {
	# Can get normal UIDL list
	while(<$h>) {
		s/\r//g;
		last if ($_ eq ".\n");
		if (/^(\d+)\s+(\S+)/) {
			push(@rv, $2);
			}
		}
	}
return @rv;
}

# pop3_logout_all()
# Properly closes all open POP3 and IMAP sessions
sub pop3_logout_all
{
local $f;
foreach $f (keys %pop3_login_handle) {
	&pop3_logout($pop3_login_handle{$f}, 1);
	}
foreach $f (keys %imap_login_handle) {
	&imap_logout($imap_login_handle{$f}, 1);
	}
}

# imap_login(&folder)
# Logs into a POP3 server, selects a mailbox and returns a status
# (1=ok, 0=connect failed, 2=login failed, 3=mailbox error), a handle or error
# message, the number of messages in the mailbox, the next UID, the number
# unread, and the number special.
sub imap_login
{
local ($folder) = @_;
local $key = join("/", $folder->{'server'}, $folder->{'port'},
		       $folder->{'user'});
local $h = $imap_login_handle{$key};
local @rv;
if (!$h) {
	# Need to open socket
	$h = "IMAP".time().++$imap_login_count;
	local $error;
	print DEBUG "Connecting to IMAP server $folder->{'server'}:$folder->{'port'}\n";
	&open_socket($folder->{'server'}, $folder->{'port'} || $imap_port,
		     $h, \$error);
	print DEBUG "IMAP error=$error\n" if ($error);
	return (0, $error) if ($error);
	local $os = select($h); $| = 1; select($os);

	# Login normally
	@rv = &imap_command($h);
	return (0, $rv[3]) if (!$rv[0]);
	local $user = $folder->{'user'} eq '*' ? $remote_user
					       : $folder->{'user'};
	local $pass = $folder->{'pass'};
	$pass =~ s/\\/\\\\/g;
	$pass =~ s/"/\\"/g;
	@rv = &imap_command($h,"login \"$user\" \"$pass\"");
	return (2, $rv[3]) if (!$rv[0]);

	$imap_login_handle{$key} = $h;
	}

# Select the right folder (if one was given)
@rv = &imap_command($h, "select \"".($folder->{'mailbox'} || "INBOX")."\"");
return (3, $rv[3]) if (!$rv[0]);
local $count = $rv[2] =~ /\*\s+(\d+)\s+EXISTS/i ? $1 : undef;
local $uidnext = $rv[2] =~ /UIDNEXT\s+(\d+)/ ? $1 : undef;
return (1, $h, $count, $uidnext);
}

# imap_command(handle, command)
# Executes an IMAP command and returns 1 for success or 0 for failure, and
# a reference to an array of results (some of which may be multiline), and
# all of the results joined together, and the stuff after OK/BAD
sub imap_command
{
local ($h, $c) = @_;
if (!$h) {
	local $err = "Invalid IMAP handle";
	return (0, [ $err ], $err, $err);
	}
local @rv;

# Send the command, and read lines until a non-* one is found
local $id = $$."-".$imap_command_count++;
local ($first, $rest) = split(/\r?\n/, $c, 2);
if ($rest) {
	# Multi-line - send first line, then wait for continuation, then rest
	print $h "$id $first\r\n";
	print DEBUG "imap command $id $first\n";
	local $l = <$h>;
	print DEBUG "imap line $l";
	if ($l =~ /^\+/) {
		print $h $rest."\r\n";
		}
	else {
		local $err = "Server did not ask for continuation : $l";
		return (0, [ $err ], $err, $err);
		}
	}
elsif ($c) {
	print $h "$id $c\r\n";
	print DEBUG "imap command $id $c\n";
	}
while(1) {
	local $l = <$h>;
	print DEBUG "imap line $l";
	last if (!$l);
	if ($l =~ /^(\*|\+)/) {
		# Another response, and possibly the only one if no command
		# was sent.
		push(@rv, $l);
		last if (!$c);
		if ($l =~ /\{(\d+)\}\s*$/) {
			# Start of multi-line text .. read the specified size
			local $size = $1;
			local $got;
			local $err = "Error reading email";
			while($got < $size) {
				local $buf;
				local $r = read($h, $buf, $size-$got);
				return (0, [ $err ], $err, $err) if ($r <= 0);
				$rv[$#rv] .= $buf;
				$got += $r;
				}
			}
		}
	elsif ($l =~ /^(\S+)\s+/ && $1 eq $id) {
		# End of responses
		push(@rv, $l);
		last;
		}
	else {
		# Part of last response
		if (!@rv) {
			local $err = "Got unknown line $l";
			return (0, [ $err ], $err, $err);
			}
		$rv[$#rv] .= $l;
		}
	}
local $j = join("", @rv);
print DEBUG "imap response $j\n";
local $lline = $rv[$#rv];
if ($lline =~ /^(\S+)\s+OK\s*(.*)/) {
	# Looks like the command worked
	return (1, \@rv, $j, $2);
	}
else {
	# Command failed!
	return (0, \@rv, $j, $lline =~ /^(\S+)\s+(\S+)\s*(.*)/ ? $3 : $lline);
	}
}

# imap_logout(handle, doquit)
sub imap_logout
{
local @rv = $_[1] ? &imap_command($_[0], "close") : (1, undef);
local $f;
foreach $f (keys %imap_login_handle) {
	delete($imap_login_handle{$f}) if ($imap_login_handle{$f} eq $_[0]);
	}
close($_[0]);
return @rv;
}

# lock_folder(&folder)
sub lock_folder
{
return if ($_[0]->{'remote'} || $_[0]->{'type'} == 5 || $_[0]->{'type'} == 6);
local $f = $_[0]->{'file'} ? $_[0]->{'file'} :
	   $_[0]->{'type'} == 0 ? &user_mail_file($remote_user) :
				  $qmail_maildir;
if (&lock_file($f)) {
	$_[0]->{'lock'} = $f;
	}
else {
	# Cannot lock if in /var/mail
	local $ff = $f;
	$ff =~ s/\//_/g;
	$ff = "/tmp/$ff";
	$_[0]->{'lock'} = $ff;
	&lock_file($ff);
	}

# Also, check for a .filename.pop3 file
if ($config{'pop_locks'} && $f =~ /^(\S+)\/([^\/]+)$/) {
	local $poplf = "$1/.$2.pop";
	local $count = 0;
	while(-r $poplf) {
		sleep(1);
		if ($count++ > 5*60) {
			# Give up after 5 minutes
			&error(&text('epop3lock_tries', "<tt>$f</tt>", 5));
			}
		}
	}
}

# unlock_folder(&folder)
sub unlock_folder
{
return if ($_[0]->{'remote'});
&unlock_file($_[0]->{'lock'});
}

# folder_file(&folder)
# Returns the full path to the file or directory containing the folder's mail,
# or undef if not appropriate (such as for POP3)
sub folder_file
{
return $_[0]->{'remote'} ? undef : $_[0]->{'file'};
}

# parse_imap_mail(response)
# Parses a response from the IMAP server into a standard mail structure
sub parse_imap_mail
{
local ($imap) = @_;

# Extract the actual mail part
local $mail = { };
local $realsize;
if ($imap =~ /RFC822.SIZE\s+(\d+)/) {
	$realsize = $1;
	}
if ($imap =~ /UID\s+(\d+)/) {
	$mail->{'id'} = $1;
	}
if ($imap =~ /FLAGS\s+\(([^\)]+)\)/ ||
    $imap =~ /FLAGS\s+(\S+)/) {
	# Got read flags .. use them
	local @flags = split(/\s+/, $1);
	$mail->{'read'} = &indexoflc("\\Seen", @flags) >= 0 ? 1 : 0;
	$mail->{'special'} = &indexoflc("\\Flagged", @flags) >= 0 ? 1 : 0;
	$mail->{'replied'} = &indexoflc("\\Answered", @flags) >= 0 ? 1 : 0;
	$mail->{'deleted'} = &indexoflc("\\Deleted", @flags) >= 0 ? 1 : 0;
	}
$imap =~ s/^\*\s+(\d+)\s+FETCH.*\{(\d+)\}\r?\n// || return undef;
$mail->{'imapidx'} = $1;
local $size = $2;
local @lines = split(/\n/, substr($imap, 0, $size));

# Parse the headers
local $lnum = 0;
local @headers;
while(1) {
	local $line = $lines[$lnum++];
	$mail->{'size'} += length($line);
	$line =~ s/\r//g;
	last if ($line eq '');
	if ($line =~ /^(\S+):\s*(.*)/) {
		push(@headers, [ $1, $2 ]);
		}
	elsif ($line =~ /^(\s+.*)/) {
		$headers[$#headers]->[1] .= $1
			unless($#headers < 0);
		}
	}
$mail->{'headers'} = \@headers;
foreach $h (@headers) {
	$mail->{'header'}->{lc($h->[0])} = $h->[1];
	}

# Parse the body
while($lnum < @lines) {
	$mail->{'size'} += length($lines[$lnum]+1);
	$mail->{'body'} .= $lines[$lnum]."\n";
	$lnum++;
	}
$mail->{'size'} = $realsize if ($realsize);
return $mail;
}

# find_body(&mail, mode)
# Returns the plain text body, html body and the one to use
sub find_body
{
local ($a, $body, $textbody, $htmlbody);
foreach $a (@{$_[0]->{'attach'}}) {
	next if ($a->{'header'}->{'content-disposition'} =~ /^attachment/i);
	if ($a->{'type'} =~ /^text\/plain/i || $a->{'type'} eq 'text') {
		$textbody = $a if (!$textbody && $a->{'data'} =~ /\S/);
		}
	elsif ($a->{'type'} =~ /^text\/html/i) {
		$htmlbody = $a if (!$htmlbody && $a->{'data'} =~ /\S/);
		}
	}
if ($_[1] == 0) {
	$body = $textbody;
	}
elsif ($_[1] == 1) {
	$body = $textbody || $htmlbody;
	}
elsif ($_[1] == 2) {
	$body = $htmlbody || $textbody;
	}
elsif ($_[1] == 3) {
	# Convert HTML to text if needed
	if ($textbody) {
		$body = $textbody;
		}
	elsif ($htmlbody) {
		local $text = &html_to_text($htmlbody->{'data'});
		$body = $textbody =
			{ 'data' => $text };
		}
	}
return ($textbody, $htmlbody, $body);
}

# safe_html(html)
# Converts HTML to a form safe for inclusion in a page
sub safe_html
{
local $html = $_[0];
local $bodystuff;
if ($html =~ s/^[\000-\377]*?<BODY([^>]*)>//i) {
	$bodystuff = $1;
	}
$html =~ s/<\/BODY>[\000-\377]*$//i;
$html =~ s/<base[^>]*>//i;
$html = &filter_javascript($html);
$html = &safe_urls($html);
$bodystuff = &safe_html($bodystuff) if ($bodystuff);
return wantarray ? ($html, $bodystuff) : $html;
}

# head_html(html)
# Returns HTML in the <head> section of a document
sub head_html
{
local $html = $_[0];
return undef if ($html !~ /<HEAD[^>]*>/i || $html !~ /<\/HEAD[^>]*>/i);
$html =~ s/^[\000-\377]*<HEAD[^>]*>//gi || &error("Failed to filter <pre>".&html_escape($html)."</pre>");
$html =~ s/<\/HEAD[^>]*>[\000-\377]*//gi || &error("Failed to filter <pre>".&html_escape($html)."</pre>");
$html =~ s/<base[^>]*>//i;
return &filter_javascript($html);
}

# safe_urls(html)
# Replaces dangerous-looking URLs in HTML
sub safe_urls
{
local $html = $_[0];
$html =~ s/((src|href|background)\s*=\s*)([^ '">]+)()/&safe_url($1, $3, $4)/gei;
$html =~ s/((src|href|background)\s*=\s*')([^']+)(')/&safe_url($1, $3, $4)/gei;
$html =~ s/((src|href|background)\s*=\s*")([^"]+)(")/&safe_url($1, $3, $4)/gei;
return $html;
}

# safe_url(before, url, after)
sub safe_url
{
local ($before, $url, $after) = @_;
if ($url =~ /^#/) {
	# Relative link - harmless
	return $before.$url.$after;
	}
elsif ($url =~ /^cid:/i) {
	# Definitely safe (CIDs are harmless)
	return $before.$url.$after;
	}
elsif ($url =~ /^(http:|https:)/) {
	# Possibly safe, unless refers to local
	local ($host, $port, $page, $ssl) = &parse_http_url($url);
	local ($hhost, $hport) = split(/:/, $ENV{'HTTP_HOST'});
	$hport ||= $ENV{'SERVER_PORT'};
	if ($host ne $hhost ||
	    $port != $hport ||
	    $ssl != (uc($ENV{'HTTPS'}) eq 'ON' ? 1 : 0)) {
		return $before.$url.$after;
		}
	else {
		return $before."_unsafe_link_".$after;
		}
	}
elsif ($url =~ /^mailto:([a-z0-9\.\-\_\@\%]+)/i) {
	# A mailto link which is URL-escaped
	return $before."reply_mail.cgi?new=1&to=".
	       &urlize(&un_urlize($1)).$after;
	}
elsif ($url =~ /^mailto:([a-z0-9\.\-\_\@]+)/i) {
	# A mailto link, which we can convert
	return $before."reply_mail.cgi?new=1&to=".&urlize($1).$after;
	}
elsif ($url =~ /\.cgi/) {
	# Relative URL like foo.cgi or /foo.cgi or ../foo.cgi - unsafe!
	return $before."_unsafe_link_".$after;
	}
else {
	# Non-CGI URL .. assume safe
	return $before.$url.$after;
	}
}

# safe_uidl(string)
sub safe_uidl
{
local $rv = $_[0];
$rv =~ s/\/|\./_/g;
return $rv;
}

# html_to_text(html)
# Attempts to convert some HTML to text form
sub html_to_text
{
local ($h2, $lynx);
if (($h2 = &has_command("html2text")) || ($lynx = &has_command("lynx"))) {
	# Can use a commonly available external program
	local $temp = &transname().".html";
	open(TEMP, ">", $temp);
	print TEMP $_[0];
	close(TEMP);
	open(OUT, ($lynx ? "$lynx -dump $temp" : "$h2 $temp")." 2>/dev/null |");
	while(<OUT>) {
		if ($lynx && $_ =~ /^\s*References\s*$/) {
			# Start of Lynx references output
			$gotrefs++;
			}
		elsif ($lynx && $gotrefs &&
		       $_ =~ /^\s*(\d+)\.\s+(http|https|ftp|mailto)/) {
			# Skip this URL reference line
			}
		else {
			$text .= $_;
			}
		}
	close(OUT);
	unlink($temp);
	return $text;
	}
else {
	# Do conversion manually :(
	local $html = $_[0];
	$html =~ s/\s+/ /g;
	$html =~ s/<p>/\n\n/gi;
	$html =~ s/<br>/\n/gi;
	$html =~ s/<[^>]+>//g;
	$html = &entities_to_ascii($html);
	return $html;
	}
}

# folder_select(&folders, selected-folder, name, [extra-options], [by-id],
#		[auto-submit])
# Returns HTML for selecting a folder
sub folder_select
{
local ($folders, $folder, $name, $extra, $byid, $auto) = @_;
local @opts;
push(@opts, @$extra) if ($extra);
foreach my $f (@$folders) {
	next if ($f->{'hide'} && $f ne $_[1]);
	local $umsg;
	if (&should_show_unread($f)) {
		local ($c, $u) = &mailbox_folder_unread($f);
		if ($u) {
			$umsg = " ($u)";
			}
		}
	push(@opts, [ $byid ? &folder_name($f) : $f->{'index'},
		      $f->{'name'}.$umsg ]);
	}
return &ui_select($name, $byid ? &folder_name($folder) : $folder->{'index'},
		  \@opts, 1, 0, 0, 0, $auto ? "onChange='form.submit()'" : "");
}

# folder_size(&folder, ...)
# Sets the 'size' field of one or more folders, and returns the total
sub folder_size
{
local ($f, $total);
foreach $f (@_) {
	if ($f->{'type'} == 0 || $f->{'type'} == 7) {
		# Single mail file - size is easy
		local @st = stat($f->{'file'});
		$f->{'size'} = $st[7];
		}
	elsif ($f->{'type'} == 1) {
		# Maildir folder size is that of all files in it, except
		# sub-folders.
		$f->{'size'} = 0;
		foreach my $sd ("cur", "new", "tmp") {
			$f->{'size'} += &recursive_disk_usage(
					$f->{'file'}."/".$sd, '^\\.');
			}
		}
	elsif ($f->{'type'} == 3) {
		# MH folder size is that of all mail files
		local $mf;
		$f->{'size'} = 0;
		opendir(MHDIR, $f->{'file'});
		while($mf = readdir(MHDIR)) {
			next if ($mf eq "." || $mf eq "..");
			local @st = stat("$f->{'file'}/$mf");
			$f->{'size'} += $st[7];
			}
		closedir(MHDIR);
		}
	elsif ($f->{'type'} == 4) {
		# Get size of IMAP folder
		local ($ok, $h, $count, $uidnext) = &imap_login($f);
		if ($ok) {
			$f->{'size'} = 0;
			$f->{'lastchange'} = $uidnext;
			local @rv = &imap_command($h,
				"FETCH 1:$count (RFC822.SIZE)");
			foreach my $r (@{$rv[1]}) {
				if ($r =~ /RFC822.SIZE\s+(\d+)/) {
					$f->{'size'} += $1;
					}
				}
			}
		}
	elsif ($f->{'type'} == 5) {
		# Size of a combined folder is the size of all sub-folders
		return &folder_size(@{$f->{'subfolders'}});
		}
	else {
		# Cannot get size of a POP3 folder
		$f->{'size'} = undef;
		}
	$total += $f->{'size'};
	}
return $total;
}

# parse_boolean(string)
# Separates a string into a series of and/or separated values. Returns a
# mode number (0=or, 1=and, 2=both) and a list of words
sub parse_boolean
{
local @rv;
local $str = $_[0];
local $mode = -1;
local $lastandor = 0;
while($str =~ /^\s*"([^"]*)"(.*)$/ ||
      $str =~ /^\s*"([^"]*)"(.*)$/ ||
      $str =~ /^\s*(\S+)(.*)$/) {
	local $word = $1;
	$str = $2;
	if (lc($word) eq "and") {
		if ($mode < 0) { $mode = 1; }
		elsif ($mode != 1) { $mode = 2; }
		$lastandor = 1;
		}
	elsif (lc($word) eq "or") {
		if ($mode < 0) { $mode = 0; }
		elsif ($mode != 0) { $mode = 2; }
		$lastandor = 1;
		}
	else {
		if (!$lastandor && @rv) {
			$rv[$#rv] .= " ".$word;
			}
		else {
			push(@rv, $word);
			}
		$lastandor = 0;
		}
	}
$mode = 0 if ($mode < 0);
return ($mode, \@rv);
}

# recursive_files(dir, treat-dirs-as-folders)
sub recursive_files
{
local ($f, @rv);
opendir(DIR, $_[0]);
local @files = readdir(DIR);
closedir(DIR);
foreach $f (@files) {
	next if ($f eq "." || $f eq ".." || $f =~ /\.lock$/i ||
		 $f eq "cur" || $f eq "tmp" || $f eq "new" ||
		 $f =~ /^\.imap/i || $f eq ".customflags" ||
		 $f eq "dovecot-uidlist" || $f =~ /^courierimap/ ||
		 $f eq "maildirfolder" || $f eq "maildirsize" ||
		 $f eq "maildircache" || $f eq ".subscriptions" ||
                 $f eq ".usermin-maildircache" || $f =~ /^dovecot\.index/ ||
		 $f =~ /^dovecot-uidvalidity/ || $f eq "subscriptions" ||
		 $f =~ /\.webmintmp\.\d+$/ || $f eq "dovecot-keywords" ||
		 $f =~ /^dovecot\.mailbox/);
	local $p = "$_[0]/$f";
	local $added = 0;
	if ($_[1] || !-d $p || -d "$p/cur") {
		push(@rv, $p);
		$added = 1;
		}
	# If this directory wasn't a folder (or it it in Maildir format),
	# search it too.
	if (-d "$p/cur" || !$added) {
		push(@rv, &recursive_files($p));
		}
	}
return @rv;
}

# editable_mail(&mail)
# Returns 0 if some mail message should not be editable (ie. internal folder)
sub editable_mail
{
return $_[0]->{'header'}->{'subject'} !~ /DON'T DELETE THIS MESSAGE.*FOLDER INTERNAL DATA/;
}

# fix_cids(html, &attachments, url-prefix)
# Replaces HTML like img src=cid:XXX with img src=detach.cgi?whatever
sub fix_cids
{
local $rv = $_[0];

# Fix images referring to CIDs
$rv =~ s/(src="|href="|background=")cid:([^"]+)(")/$1.&fix_cid($2,$_[1],$_[2]).$3/gei;
$rv =~ s/(src='|href='|background=')cid:([^']+)(')/$1.&fix_cid($2,$_[1],$_[2]).$3/gei;
$rv =~ s/(src=|href=|background=)cid:([^\s>]+)()/$1.&fix_cid($2,$_[1],$_[2]).$3/gei;

# Fix images whose URL is actually in an attachment
$rv =~ s/(src="|href="|background=")([^"]+)(")/$1.&fix_contentlocation($2,$_[1],$_[2]).$3/gei;
$rv =~ s/(src='|href='|background=')([^']+)(')/$1.&fix_contentlocation($2,$_[1],$_[2]).$3/gei;
$rv =~ s/(src=|href=|background=)([^\s>]+)()/$1.&fix_contentlocation($2,$_[1],$_[2]).$3/gei;
return $rv;
}

# fix_cid(cid, &attachments, url-prefix)
sub fix_cid
{
local ($cont) = grep { $_->{'header'}->{'content-id'} eq $_[0] ||
		       $_->{'header'}->{'content-id'} eq "<$_[0]>" } @{$_[1]};
if ($cont) {
	return "$_[2]&attach=$cont->{'idx'}";
	}
else {
	return "cid:$_[0]";
	}
}

# fix_contentlocation(url, &attachments, url-prefix)
sub fix_contentlocation
{
local ($cont) = grep { $_->{'header'}->{'content-location'} eq $_[0] ||
	       $_->{'header'}->{'content-location'} eq "<$_[0]>" } @{$_[1]};
if ($cont) {
	return "$_[2]&attach=$cont->{'idx'}";
	}
else {
	return $_[0];
	}
}

# create_cids(html, &results-map)
# Replaces all image references in the body like <img src=detach.cgi?...> with
# cid: tags, stores in the results map pointers from the index to the CID.
sub create_cids
{
local ($html, $cidmap) = @_;
$html =~ s/(src="|href="|background=")detach.cgi\?([^"]+)(")/$1.&create_cid($2,$cidmap).$3/gei;
$html =~ s/(src='|href='|background=')detach.cgi\?([^']+)(')/$1.&create_cid($2,$cidmap).$3/gei;
$html =~ s/(src=|href=|background=)detach.cgi\?([^\s>]+)()/$1.&create_cid($2,$cidmap).$3/gei;
return $html;
}

sub create_cid
{
local ($args, $cidmap) = @_;
if ($args =~ /attach=(\d+)/) {
	$create_cid_count++;
	$cidmap->{$1} = time().$$.$create_cid_count;
	return "cid:".$cidmap->{$1};
	}
else {
	# No attachment ID!
	return "";
	}
}

# disable_html_images(html, disable?, &urls)
# Turn off some or all images in HTML email. Mode 0=Do nothing, 1=Offsite only,
# 2=All images. Returns the URL of images found in &urls
sub disable_html_images
{
local ($html, $dis, $urls) = @_;
local $newhtml;
while($html =~ /^([\000-\377]*?)(<\s*img[^>]*src=('[^']*'|"[^"]*"|\S+)[^>]*>)([\000-\377]*)/i) {
	local ($before, $allimg, $img, $after) = ($1, $2, $3, $4);
	$img =~ s/^'(.*)'$/$1/ || $img =~ s/^"(.*)"$/$1/;
	push(@$urls, $img) if ($urls);
	if ($dis == 0) {
		# Don't harm image
		$newhtml .= $before.$allimg;
		}
	elsif ($dis == 1) {
		# Don't touch unless offsite
		if ($img =~ /^(http|https|ftp):/) {
			$newhtml .= $before;
			}
		else {
			$newhtml .= $before.$allimg;
			}
		}
	elsif ($dis == 2) {
		# Always remove image
		$newhtml .= $before;
		}
	$html = $after;
	}
$newhtml .= $html;
return $newhtml;
}

# remove_body_attachments(&mail, &attach)
# Returns attachments except for those that make up the message body, and those
# that have sub-attachments.
sub remove_body_attachments
{
local ($mail, $attach) = @_;
local ($textbody, $htmlbody) = &find_body($mail);
return grep { $_ ne $htmlbody && $_ ne $textbody && !$_->{'attach'} &&
	      $_->{'type'} ne 'message/delivery-status' } @$attach;
}

# remove_cid_attachments(&mail, &attach)
# Returns attachments except for those that are used for inline images in the
# HTML body.
sub remove_cid_attachments
{
local ($mail, $attach) = @_;
local ($textbody, $htmlbody) = &find_body($mail);
local @rv;
foreach my $a (@$attach) {
	my $cid = $a->{'header'}->{'content-id'};
	$cid =~ s/^<(.*)>$/$1/g;
	my $cl = $a->{'header'}->{'content-location'};
	$cl =~ s/^<(.*)>$/$1/g;
	local $inline;
	if ($cid && $htmlbody->{'data'} =~ /cid:\Q$cid\E|cid:"\Q$cid\E"|cid:'\Q$cid\E'/) {
		# CID-based attachment
		$inline = 1;
		}
	elsif ($cl && $htmlbody->{'data'} =~ /\Q$cl\E/) {
		# Content-location based attachment
		$inline = 1;
		}
	if (!$inline) {
		push(@rv, $a);
		}
	}
return @rv;
}

# quoted_message(&mail, quote-mode, sig, 0=any,1=text,2=html, sig-at-top?)
# Returns the quoted text, html-flag and body attachment
sub quoted_message
{
local ($mail, $qu, $sig, $bodymode, $sigtop) = @_;
local $mode = $bodymode == 1 ? 1 :
	      $bodymode == 2 ? 2 :
	      %userconfig ? $userconfig{'view_html'} :
			    $config{'view_html'};
local ($plainbody, $htmlbody) = &find_body($mail, $mode);
local ($quote, $html_edit, $body);
local $cfg = %userconfig ? \%userconfig : \%config;
local @writers = &split_addresses($mail->{'header'}->{'from'});
local $writer;
if ($writers[0]->[1]) {
	$writer = &decode_mimewords($writers[0]->[1])." <".
		  &decode_mimewords($writers[0]->[0])."> wrote ..";
	}
else {
	$writer = &decode_mimewords($writers[0]->[0])." wrote ..";
	}
local $tm;
if ($cfg->{'reply_date'} &&
    ($tm = &parse_mail_date($_[0]->{'header'}->{'date'}))) {
	local $tmstr = &make_date($tm);
	$writer = "On $tmstr $writer";
	}
local $qm = %userconfig ? $userconfig{'html_quote'} : $config{'html_quote'};
if (($cfg->{'html_edit'} == 2 ||
     $cfg->{'html_edit'} == 1 && $htmlbody) &&
     $bodymode != 1) {
	# Create quoted body HTML
	if ($htmlbody) {
		$body = $htmlbody;
		$sig =~ s/\n/<br>\n/g;
		if ($qu && $qm == 0) {
			# Quoted HTML as cite
			$quote = &html_escape($writer)."\n".
				 "<blockquote type=cite>\n".
				 &safe_html($htmlbody->{'data'}).
				 "</blockquote>";
			if ($sigtop) {
				$quote = $sig."<br>\n".$quote;
				}
			else {
				$quote = $quote.$sig."<br>\n";
				}
			}
		elsif ($qu && $qm == 1) {
			# Quoted HTML below line
			$quote = "<br>$sig<hr>".
			         &html_escape($writer)."<br>\n".
				 &safe_html($htmlbody->{'data'});
			}
		else {
			# Un-quoted HTML
			$quote = &safe_html($htmlbody->{'data'});
			if ($sigtop) {
				$quote = $sig."<br>\n".$quote;
				}
			else {
				$quote = $quote.$sig."<br>\n";
				}
			}
		}
	elsif ($plainbody) {
		$body = $plainbody;
		local $pd = $plainbody->{'data'};
		$pd =~ s/^\s+//g;
		$pd =~ s/\s+$//g;
		if ($qu && $qm == 0) {
			# Quoted plain text as HTML as cite
			$quote = &html_escape($writer)."\n".
				 "<blockquote type=cite>\n".
				 "<pre>$pd</pre>".
				 "</blockquote>";
			if ($sigtop) {
				$quote = $sig."<br>\n".$quote;
				}
			else {
				$quote = $quote.$sig."<br>\n";
				}
			}
		elsif ($qu && $qm == 1) {
			# Quoted plain text as HTML below line
			$quote = "<br>$sig<hr>".
				 &html_escape($writer)."<br>\n".
				 "<pre>$pd</pre><br>\n";
			}
		else {
			# Un-quoted plain text as HTML
			$quote = "<pre>$pd</pre>";
			if ($sigtop) {
				$quote = $sig."<br>\n".$quote;
				}
			else {
				$quote = $quote.$sig."<br>\n";
				}
			}
		}
	$html_edit = 1;
	}
else {
	# Create quoted body text
	if ($plainbody) {
		$body = $plainbody;
		$quote = $plainbody->{'data'};
		}
	elsif ($htmlbody) {
		$body = $htmlbody;
		$quote = &html_to_text($htmlbody->{'data'});
		}
	if ($quote && $qu) {
		$quote = join("", map { "> $_\n" }
			&wrap_lines($quote, 78));
		}
	$quote = $writer."\n".$quote if ($quote && $qu);
	if ($sig && $sigtop) {
		$quote = $sig."\n".$quote;
		}
	elsif ($sig && !$sigtop) {
		$quote = $quote.$sig."\n";
		}
	}
return ($quote, $html_edit, $body);
}

# modification_time(&folder)
# Returns the unix time on which this folder was last modified, or 0 if unknown
sub modification_time
{
if ($_[0]->{'type'} == 0) {
	# Modification time of file
	local @st = stat($_[0]->{'file'});
	return $st[9];
	}
elsif ($_[0]->{'type'} == 1) {
	# Greatest modification time of cur/new directory
	local @stcur = stat("$_[0]->{'file'}/cur");
	local @stnew = stat("$_[0]->{'file'}/new");
	return $stcur[9] > $stnew[9] ? $stcur[9] : $stnew[9];
	}
elsif ($_[0]->{'type'} == 2 || $_[0]->{'type'} == 4) {
	# Cannot know for POP3 or IMAP folders
	return 0;
	}
elsif ($_[0]->{'type'} == 3) {
	# Modification time of MH folder
	local @st = stat($_[0]->{'file'});
	return $st[9];
	}
else {
	# Huh?
	return 0;
	}
}

# requires_delivery_notification(&mail)
sub requires_delivery_notification
{
return $_[0]->{'header'}->{'disposition-notification-to'} ||
       $_[0]->{'header'}->{'read-reciept-to'};
}

# send_delivery_notification(&mail, [from-addr], manual)
# Send an email containing delivery status information
sub send_delivery_notification
{
local ($mail, $from) = @_;
$from ||= $mail->{'header'}->{'to'};
local $host = &get_display_hostname();
local $to = &requires_delivery_notification($mail);
local $product = &get_product_name();
$product = ucfirst($product);
local $version = &get_webmin_version();
local ($taddr) = &split_addresses($mail->{'header'}->{'to'});
local $disp = $manual ? "manual-action/MDN-sent-manually"
		      : "automatic-action/MDN-sent-automatically";
local $dsn = <<EOF;
Reporting-UA: $host; $product $version
Original-Recipient: rfc822;$taddr->[0]
Final-Recipient: rfc822;$taddr->[0]
Original-Message-ID: $mail->{'header'}->{'message-id'}
Disposition: $disp; displayed
EOF
local $dmail = {
	'headers' =>
	   [ [ 'From' => $from ],
	     [ 'To' => $to ],
	     [ 'Subject' => 'Delivery notification' ],
	     [ 'Content-type' => 'multipart/report; report-type=disposition-notification' ],
	     [ 'Content-Transfer-Encoding' => '7bit' ] ],
	'attach' => [
	   { 'headers' => [ [ 'Content-type' => 'text/plain' ] ],
	     'data' => "This is a delivery status notification for the email sent to:\n$mail->{'header'}->{'to'}\non the date:\n$mail->{'header'}->{'date'}\nwith the subject:\n$mail->{'header'}->{'subject'}\n" },
	   { 'headers' => [ [ 'Content-type' =>
				'message/disposition-notification' ],
			    [ 'Content-Transfer-Encoding' => '7bit' ] ],
	     'data' => $dsn }
		] };
eval { local $main::errors_must_die = 1; &send_mail($dmail); };
return $to;
}

# find_subfolder(&folder, name)
# Returns the sub-folder with some name
sub find_subfolder
{
local ($folder, $sfn) = @_;
if ($folder->{'type'} == 5) {
	# Composite
	foreach my $sf (@{$folder->{'subfolders'}}) {
		return $sf if (&folder_name($sf) eq $sfn);
		}
	}
elsif ($folder->{'type'} == 6) {
	# Virtual
	foreach my $m (@{$folder->{'members'}}) {
		return $m->[0] if (&folder_name($m->[0]) eq $sfn);
		}
	}
return undef;
}

# find_named_folder(name, &folders, [&cache])
# Finds a folder by ID, filename, server name or displayed name
sub find_named_folder
{
local ($name, $folders, $cache) = @_;
local $rv;
if ($cache && exists($cache->{$name})) {
	# In cache
	$rv = $cache->{$name};
	}
else {
	# Need to lookup
	($rv) = grep { &folder_name($_) eq $name } @$folders if (!$rv);
	($rv) = grep { my $escfile = $_->{'file'};
		       $escfile =~ s/\s/_/g;
		       $escfile eq $name ||
		       $_->{'file'} eq $name ||
		       $_->{'server'} eq $name } @$folders if (!$rv);
	($rv) = grep { my $escname = $_->{'name'};
		       $escname =~ s/\s/_/g;
		       $escname eq $name ||
		       $_->{'name'} eq $name } @$folders if (!$rv);
	$cache->{$name} = $rv if ($cache);
	}
return $rv;
}

# folder_name(&folder)
# Returns a unique identifier for a folder, based on it's filename or ID
sub folder_name
{
my $rv = $_[0]->{'id'} ||
         $_[0]->{'file'} ||
         $_[0]->{'server'} ||
         $_[0]->{'name'};
$rv =~ s/\s/_/g;
return $rv;
}

# set_folder_lastmodified(&folders)
# Sets the last-modified time and sortable flag on all given folders
sub set_folder_lastmodified
{
local ($folders) = @_;
foreach my $folder (@$folders) {
	if ($folder->{'type'} == 0 || $folder->{'type'} == 3) {
		# For an mbox or MH folder, the last modified date is just that
		# of the file or directory itself
		local @st = stat($folder->{'file'});
		$folder->{'lastchange'} = $st[9];
		$folder->{'sortable'} = 1;
		}
	elsif ($folder->{'type'} == 1) {
		# For a Maildir folder, the date is that of the newest
		# sub-directory (cur, tmp or new)
		$folder->{'lastchange'} = 0;
		foreach my $sf ("cur", "tmp", "new") {
			local @st = stat("$folder->{'file'}/$sf");
			$folder->{'lastchange'} = $st[9]
				if ($st[9] > $folder->{'lastchange'});
			}
		$folder->{'sortable'} = 1;
		}
	elsif ($folder->{'type'} == 5) {
		# For a composite folder, the date is that of the newest
		# sub-folder, OR the folder file itself
		local @st = stat($folder->{'folderfile'});
		$folder->{'lastchange'} = $st[9];
		&set_folder_lastmodified($folder->{'subfolders'});
		foreach my $sf (@{$folder->{'subfolders'}}) {
			$folder->{'lastchange'} = $sf->{'lastchange'}
				if ($sf->{'lastchange'} >
				    $folder->{'lastchange'});
			}
		$folder->{'sortable'} = 1;
		}
	elsif ($folder->{'type'} == 6) {
		# For a virtual folder, the date is that of the newest
		# sub-folder, OR the folder file itself
		local @st = stat($folder->{'folderfile'});
		$folder->{'lastchange'} = $st[9];
		my %done;
		foreach my $m (@{$folder->{'members'}}) {
			if (!$done{$m->[0]}++) {
				&set_folder_lastmodified([ $m->[0] ]);
				$folder->{'lastchange'} =
					$m->[0]->{'lastchange'}
					if ($m->[0]->{'lastchange'} >
					    $folder->{'lastchange'});
				}
			}
		$folder->{'sortable'} = 1;
		}
	else {
		# For POP3 and IMAP folders, we don't know the last change
		$folder->{'lastchange'} = undef;
		$folder->{'sortable'} = 1;
		}
	}
}

# mail_preview(&mail, [characters])
# Returns a short text preview of a message body
sub mail_preview
{
local ($mail, $chars) = @_;
$chars ||= 100;
local ($textbody, $htmlbody, $body) = &find_body($mail, 0);
local $data = $body->{'data'};
$data =~ s/\r?\n/ /g;
$data = substr($data, 0, $chars);
if ($data =~ /\S/) {
	return $data;
	}
return undef;
}

# open_dbm_db(&hash, file, mode)
# Attempts to open a DBM, first using SDBM_File, and then NDBM_File
sub open_dbm_db
{
local ($hash, $file, $mode) = @_;
eval "use SDBM_File";
dbmopen(%$hash, $file, $mode);
eval { $hash->{'1111111111'} = 'foo bar' };
if ($@) {
	dbmclose(%$hash);
	eval "use NDBM_File";
	dbmopen(%$hash, $file, $mode);
	}
}

# generate_message_id(from-address)
# Returns a unique ID for a new message
sub generate_message_id
{
local ($fromaddr) = @_;
local ($finfo) = &split_addresses($fromaddr);
local $dom;
if ($finfo && $finfo->[0] =~ /\@(\S+)$/) {
	$dom = $1;
	}
else {
	$dom = &get_system_hostname();
	}
return "<".time().".".$$."\@".$dom.">";
}

# type_to_extension(type)
# Returns a good extension for a MIME type
sub type_to_extension
{
local ($type) = @_;
$type =~ s/;.*$//;
local ($mt) = grep { lc($_->{'type'}) eq lc($type) } &list_mime_types();
if ($mt && $m->{'exts'}->[0]) {
	return $m->{'exts'}->[0];
	}
elsif ($type =~ /^text\//) {
	return ".txt";
	}
else {
	my @p = split(/\//, $type);
	return $p[1];
	}
}

# should_show_unread(&folder)
# Returns 1 if we should show unread counts for some folder
sub should_show_unread
{
local ($folder) = @_;
local $su = $userconfig{'show_unread'} || $config{'show_unread'};

# Work out if all sub-folders are IMAP
local $allimap;
if ($su == 2) {
	# Doesn't matter
	}
elsif ($su == 1 && $config{'mail_system'} == 4) {
	# Totally IMAP mode
	$allimap = 1;
	}
elsif ($su == 1) {
	if ($folder->{'type'} == 5) {
		$allimap = 1;
		foreach my $sf (@{$folder->{'subfolders'}}) {
			$allimap = 0 if (!&should_show_unread($sf));
			}
		}
	elsif ($folder->{'type'} == 6) {
		$allimap = 1;
		foreach my $mem (@{$folder->{'members'}}) {
			$allimap = 0 if (!&should_show_unread($mem->[0]));
			}
		}
	}

return $su == 2 ||				# All folders
       ($folder->{'type'} == 4 ||		# Only IMAP and derived
	$folder->{'type'} == 5 && $allimap ||
	$folder->{'type'} == 6 && $allimap) && $su == 1;
}

# mail_has_attachments(&mail|&mails, &folder)
# Returns an array of flags, each being 1 if the message has attachments, 0
# if not. Uses a cache DBM by message ID and fetches the whole mail if needed.
sub mail_has_attachments
{
local ($mails, $folder) = @_;
if (ref($mails) ne 'ARRAY') {
	# Just one
	$mails = [ $mails ];
	}

# Open cache DBM
if (!%hasattach) {
	local $hasattach_file;
	if ($module_info{'usermin'}) {
		$hasattach_file = "$user_module_config_directory/attach";
		}
	else {
		$hasattach_file = "$module_config_directory/attach";
		if (!glob($hasattach_file."*")) {
			$hasattach_file = "$module_var_directory/attach";
			}
		}
	&open_dbm_db(\%hasattach, $hasattach_file, 0600);
	}

# See which mail we already know about
local @rv = map { undef } @$mails;
local @needbody;
for(my $i=0; $i<scalar(@rv); $i++) {
	local $mail = $mails->[$i];
	local $mid = $mail->{'header'}->{'message-id'} ||
		     $mail->{'id'};
	if ($mid && defined($hasattach{$mid})) {
		# Already cached .. use it
		$rv[$i] = $hasattach{$mid};
		}
	elsif (!$mail->{'body'} && $mail->{'size'} > 1024*1024) {
		# Message is big .. just assume it has attachments
		$rv[$i] = 1;
		}
	elsif (!$mail->{'body'}) {
		# Need to get body
		push(@needbody, $i);
		}
	}

# We need to actually fetch some message bodies to check for attachments
if (@needbody) {
	local (@needmail, %oldread);
	foreach my $i (@needbody) {
		push(@needmail, $mails->[$i]);
		}
	@needmail = &mailbox_select_mails($folder,
		[ map { $_->{'id'} } @needmail ], 0);
	foreach my $i (@needbody) {
		$mails->[$i] = shift(@needmail);
		}
	}

# Now we have bodies, check for attachments
for(my $i=0; $i<scalar(@rv); $i++) {
	next if (defined($rv[$i]));
	local $mail = $mails->[$i];
	if (!$mail) {
		# Couldn't read from server
		$rv[$i] = 0;
		next;
		}
	if (!@{$mail->{'attach'}}) {
		# Parse out attachments
		&parse_mail($mail, undef, 0);
		}

	# Check for non-text attachments
	$rv[$i] = 0;
	foreach my $a (@{$mail->{'attach'}}) {
		if ($a->{'type'} =~ /^text\/(plain|html)/i ||
		    $a->{'type'} eq 'text') {
			# Text part .. may be an attachment
			if ($a->{'header'}->{'content-disposition'} =~
			    /^attachment/i) {
				$rv[$i] = 1;
				}
			}
		elsif ($a->{'type'} !~ /^multipart\/(mixed|alternative)/) {
			# Non-text .. assume this means we have an attachment
			$rv[$i] = 1;
			}
		}
	}

# Update the cache
for(my $i=0; $i<scalar(@rv); $i++) {
	local $mail = $mails->[$i];
	local $mid = $mail->{'header'}->{'message-id'} ||
		     $mail->{'id'};
	if ($mid && !defined($hasattach{$mid})) {
		$hasattach{$mid} = $rv[$i]
		}
	}

return wantarray ? @rv : $rv[0];
}

# show_delivery_status(&dstatus)
# Show the delivery status HTML for some email
sub show_delivery_status
{
local ($dstatus) = @_;
local $ds = &parse_delivery_status($dstatus->{'data'});
$dtxt = $ds->{'status'} =~ /^2\./ ? $text{'view_dstatusok'}
				  : $text{'view_dstatus'};
print &ui_table_start($dtxt, "width=100%", 2, [ "width=10% nowrap" ]);
foreach $dsh ('final-recipient', 'diagnostic-code',
	      'remote-mta', 'reporting-mta') {
	if ($ds->{$dsh}) {
		$ds->{$dsh} =~ s/^\S+;//;
		print &ui_table_row($text{'view_'.$dsh},
				    &html_escape($ds->{$dsh}));
		}
	}
print &ui_table_end();
}

# attachments_table(&attach, folder, view-url, detach-url,
#                   [viewmail-url, viewmail-field], [show-checkboxes])
# Prints an HTML table of attachments. Returns a list of those that can be
# server-side detached.
sub attachments_table
{
local ($attach, $folder, $viewurl, $detachurl, $mailurl, $idfield, $cbs) = @_;
local %typemap = map { $_->{'type'}, $_->{'desc'} } &list_mime_types();
local $qid = &urlize($id);
local $rv;
local (@files, @actions, @detach, @sizes, @titles, @links);
foreach my $a (@$attach) {
	local $fn;
	local $size = &nice_size(length($a->{'data'}));
	local $cb;
	if (!$a->{'type'}) {
		# An actual email
		push(@files, &text('view_sub2', $a->{'header'}->{'from'}));
		$fn = "mail.txt";
		$size = &nice_size($a->{'size'});
		}
	elsif ($a->{'type'} eq 'message/rfc822') {
		# Attached email
		local $amail = &extract_mail($a->{'data'});
		if ($amail && $amail->{'header'}->{'from'}) {
			push(@files, &text('view_sub2',
					$amail->{'header'}->{'from'}));
			}
		else {
			push(@files, &text('view_sub'));
			}
		$fn = "mail.txt";
		}
	elsif ($a->{'filename'}) {
		# Known filename
		$fn = &decode_mimewords($a->{'filename'});
		push(@files, $fn);
		push(@detach, [ $a->{'idx'}, $fn ]);
		}
	else {
		# No filename
		push(@files, $text{'view_anofile'});
		$fn = "file.".&type_to_extension($a->{'type'});
		push(@detach, [ $a->{'idx'}, $fn ]);
		}
	push(@sizes, $size);
	push(@titles, $files[$#files]."<br>".$size);
	if ($a->{'error'}) {
		$titles[$#titles] .= "<br><font size=-1>($a->{'error'})</font>";
		}
	$fn =~ s/ /_/g;
	$fn =~ s/\#/_/g;
	$fn = &html_escape($fn);
	local @a;
	local $detachfile = $detachurl;
	$detachfile =~ s/\?/\/$fn\?/;
	if (!$a->{'type'}) {
		# Complete email for viewing
		local $qmid = &urlize($a->{$idfield});
		push(@links, "$mailurl&$idfield=$qmid&folder=$folder->{'index'}");
		}
	elsif ($a->{'type'} eq 'message/rfc822') {
		# Attached sub-email
		push(@links, $viewurl."&sub=$a->{'idx'}");
		}
	else {
		# Regular attachment
		push(@links, $detachfile."&attach=$a->{'idx'}");
		}
	push(@a, "<a href='$links[$#links]'>$text{'view_aview'}</a>");
	push(@a, "<a href='$links[$#links]' target=_blank>$text{'view_aopen'}</a>");
	if ($a->{'type'}) {
		push(@a, "<a href='$detachfile&attach=$a->{'idx'}&save=1'>$text{'view_asave'}</a>");
		}
	if ($a->{'type'} eq 'message/rfc822') {
		push(@a, "<a href='$detachfile&attach=$a->{'idx'}&type=text/plain$subs'>$text{'view_aplain'}</a>");
		}
	push(@actions, \@a);
	}
local @tds = ( "width=50%", "width=25%", "width=10%", "width=15% nowrap" );
if ($cbs) {
	unshift(@tds, "width=5");
	}
print &ui_columns_start([
	$cbs ? ( "" ) : ( ),
	$text{'view_afile'},
	$text{'view_atype'},
	$text{'view_asize'},
	$text{'view_aactions'},
	], 100, 0, \@tds);
for(my $i=0; $i<@files; $i++) {
	local $type = $attach[$i]->{'type'} || "message/rfc822";
	local $typedesc = $typemap{lc($type)} || $type;
	local @cols = (
		"<a href='$links[$i]'>".&html_escape($files[$i])."</a>",
		$typedesc,
		$sizes[$i],
		&ui_links_row($actions[$i]),
		);
	if ($cbs) {
		print &ui_checked_columns_row(\@cols, \@tds,
					      $cbs, $attach->[$i]->{'idx'}, 1);
		}
	else {
		print &ui_columns_row(\@cols, \@tds);
		}
	}
print &ui_columns_end();
return @detach;
}

# message_icons(&mail, showto, &folder)
# Returns a list of icon images for some mail
sub message_icons
{
local ($mail, $showto, $folder) = @_;
local @rv;
if (&mail_has_attachments($mail, $folder)) {
	push(@rv, "<img src=images/attach.gif alt='A'>");
	}
local $p = int($mail->{'header'}->{'x-priority'});
if ($p == 1) {
	push(@rv, "<img src=images/p1.gif alt='P1'>");
	}
elsif ($p == 2) {
	push(@rv, "<img src=images/p2.gif alt='P2'>");
	}

# Show icons if special or replied to
local $read = &get_mail_read($folder, $mail);
if ($read&2) {
	push(@rv, "<img src=images/special.gif alt='*'>");
	}
if ($read&4) {
	push(@rv, "<img src=images/replied.gif alt='R'>");
	}

if ($showto && defined(&open_dsn_hash)) {
	# Show icons if DSNs received
	&open_dsn_hash();
	local $mid = $mail->{'header'}->{'message-id'};
	if ($dsnreplies{$mid}) {
		push(@rv, "<img src=images/dsn.gif alt='R'>");
		}
	if ($delreplies{$mid}) {
		local ($bounce) = grep { /^\!/ }
			split(/\s+/, $delreplies{$mid});
		local $img = $bounce ? "red.gif" : "box.gif";
		push(@rv, "<img src=images/$img alt='D'>");
		}
	}
return @rv;
}

# show_mail_printable(&mail, body, textbody, htmlbody)
# Output HTML for printing a message
sub show_mail_printable
{
local ($mail, $body, $textbody, $htmlbody) = @_;

# Display the headers
print &ui_table_start($text{'view_headers'}, "width=100%", 2);
print &ui_table_row($text{'mail_from'},
	&convert_header_for_display($mail->{'header'}->{'from'}));
print &ui_table_row($text{'mail_to'},
	&convert_header_for_display($mail->{'header'}->{'to'}));
if ($mail->{'header'}->{'cc'}) {
	print &ui_table_row($text{'mail_cc'},
		&convert_header_for_display($mail->{'header'}->{'cc'}));
	}
print &ui_table_row($text{'mail_date'},
	&convert_header_for_display($mail->{'header'}->{'date'}));
print &ui_table_row($text{'mail_subject'},
	&convert_header_for_display(
		$mail->{'header'}->{'subject'}));
print &ui_table_end(),"<br>\n";

# Just display the mail body for printing
print &ui_table_start(undef, "width=100%", 2);
if ($body eq $textbody) {
	my $plain;
	foreach my $l (&wrap_lines($body->{'data'},
				   $config{'wrap_width'} ||
				    $userconfig{'wrap_width'})) {
		$plain .= &eucconv_and_escape($l)."\n";
		}
	print &ui_table_row(undef, "<pre>$plain</pre>", 2);
	}
elsif ($body eq $htmlbody) {
	print &ui_table_row(undef,
		&safe_html($body->{'data'}), 2);
	}
print &ui_table_end();
}

# show_attachments_fields(count, server-side)
# Outputs HTML for new attachment fields
sub show_attachments_fields
{
local ($count, $server_attach) = @_;

# Work out if any attachments are supported
my $any_attach = $server_attach || !$main::no_browser_uploads;

if ($any_attach && &supports_javascript()) {
	# Javascript to increase attachments fields
	print <<EOF;
<script>
function add_attachment()
{
var block = document.getElementById("attachblock");
if (block) {
	var count = 0;
	var first_input = document.forms[0]["attach0"];
	while(document.forms[0]["attach"+count]) { count++; }
	var new_input = document.createElement('input');
	new_input.setAttribute('name', "attach"+count);
	new_input.setAttribute('type', 'file');
	if (first_input) {
		new_input.setAttribute('size',
			first_input.getAttribute('size'));
		new_input.setAttribute('class',
			first_input.getAttribute('class'));
		}
	block.appendChild(new_input);
	var new_br = document.createElement('br');
	block.appendChild(new_br);
	}
return false;
}
function add_ss_attachment()
{
var block = document.getElementById("ssattachblock");
if (block) {
	var count = 0;
	var first_input = document.forms[0]["file0"];
	while(document.forms[0]["file"+count]) { count++; }
	var new_input = document.createElement('input');
	new_input.setAttribute('name', "file"+count);
	if (first_input) {
		new_input.setAttribute('size',
			first_input.getAttribute('size'));
		new_input.setAttribute('class',
			first_input.getAttribute('class'));
		}
	block.appendChild(new_input);
	var new_br = document.createElement('br');
	block.appendChild(new_br);
	}
return false;
}
</script>
EOF
	}

if ($any_attach) {
	# Show form for attachments (both uploaded and server-side)
	print &ui_table_start($server_attach ? $text{'reply_attach2'}
					     : $text{'reply_attach3'},
			      "width=100%", 2);
	}

# Uploaded attachments
if (!$main::no_browser_uploads) {
	my $atable = "<div>\n";
	for(my $i=0; $i<$count; $i++) {
		$atable .= &ui_upload("attach$i", 80, 0,
				      "style='width:100%'", 1)."<br>";
		}
	$atable .= "</div> <div id=attachblock></div>\n";
	print &ui_hidden("attachcount", int($i)),"\n";
	print &ui_table_row(undef, $atable, 2);
	}
if ($server_attach) {
	my $atable = "<div>\n";
	for(my $i=0; $i<$count; $i++) {
		$atable .= &ui_textbox("file$i", undef, 60, 0, undef,
				       "style='width:95%'").
			   &file_chooser_button("file$i"),"<br>\n";
		}
	$atable .= "</div> <div id=sattachblock></div>\n";
	print &ui_table_row(undef, $atable, 2);
	print &ui_hidden("ssattachcount", int($i)),"\n";
	}

# Links to add more fields
my @addlinks;
if (!$main::no_browser_uploads && &supports_javascript()) {
	push(@addlinks, "<a href='' onClick='return add_attachment()'>".
		        "$text{'reply_addattach'}</a>" );
	}
if ($server_attach && &supports_javascript()) {
	push(@addlinks, "<a href='' onClick='return add_ss_attachment()'>".
			"$text{'reply_addssattach'}</a>" );
	}
if ($any_attach) {
	print &ui_table_row(undef, &ui_links_row(\@addlinks), 2);
	print &ui_table_end();
	}
}

# inputs_to_hiddens([&in])
# Converts a hash as created by ReadParse into a list of names and values
sub inputs_to_hiddens
{
my $in = $_[0] || \%in;
my @hids;
foreach $i (keys %$in) {
	push(@hids, map { [ $i, $_ ] } split(/\0/, $in->{$i}));
	}
return @hids;
}

# ui_address_field(name, value, from-mode?, multi-line?)
# Returns HTML for a field for selecting an email address
sub ui_address_field
{
return &theme_ui_address_field(@_) if (defined(&theme_ui_address_field));
local ($name, $value, $from, $multi) = @_;
local @faddrs;
if (defined(&list_addresses)) {
	@faddrs = grep { $_->[3] } &list_addresses();
	}
local $f = $multi ? &ui_textarea($name, $value, 3, 40, undef, 0,
				 "style='width:95%'")
		  : &ui_textbox($name, $value, 40, 0, undef,
				"style='width:95%'");
if ((!$from || @faddrs) && defined(&address_button)) {
	$f .= " ".&address_button($name, 0, $from);
	}
return $f;
}

# Returns 1 if spell checking is supported on this system
sub can_spell_check_text
{
return &has_command("ispell");
}

# spell_check_text(text)
# Checks for spelling errors in some text, and returns a list of those found
# as HTML strings
sub spell_check_text
{
local ($plainbody) = @_;
local @errs;
pipe(INr, INw);
pipe(OUTr, OUTw);
select(INw); $| = 1; select(OUTr); $| = 1; select(STDOUT);
if (!fork()) {
	close(INw);
	close(OUTr);
	untie(*STDIN);
	untie(*STDOUT);
	untie(*STDERR);
	open(STDOUT, ">&OUTw");
	open(STDERR, ">/dev/null");
	open(STDIN, "<&INr");
	exec("ispell -a");
	exit;
	}
close(INr);
close(OUTw);
local $indent = "&nbsp;" x 4;
local @errs;
foreach $line (split(/\n+/, $plainbody)) {
	next if ($line !~ /\S/);
	print INw $line,"\n";
	local @lerrs;
	while(1) {
		($spell = <OUTr>) =~ s/\r|\n//g;
		last if (!$spell);
		if ($spell =~ /^#\s+(\S+)/) {
			# Totally unknown word
			push(@lerrs, $indent.&text('send_eword',
					"<i>".&html_escape($1)."</i>"));
			}
		elsif ($spell =~ /^&\s+(\S+)\s+(\d+)\s+(\d+):\s+(.*)/) {
			# Maybe possible word, with options
			push(@lerrs, $indent.&text('send_eword2',
					"<i>".&html_escape($1)."</i>",
					"<i>".&html_escape($4)."</i>"));
			}
		elsif ($spell =~ /^\?\s+(\S+)/) {
			# Maybe possible word
			push(@lerrs, $indent.&text('send_eword',
					"<i>".&html_escape($1)."</i>"));
			}
		}
	if (@lerrs) {
		push(@errs, &text('send_eline',
				"<tt>".&html_escape($line)."</tt>")."<br>".
				join("<br>", @lerrs));
		}
	}
close(INw);
close(OUTr);
return @errs;
}

# get_mail_charset(&mail, &body)
# Returns the character set to use for the HTML page for some email
sub get_mail_charset
{
my ($mail, $body) = @_;
my $ctype;
if ($body) {
	$ctype = $body->{'header'}->{'content-type'};
	}
$ctype ||= $mail->{'header'}->{'content-type'};
if ($ctype =~ /charset="([a-z0-9\-]+)"/i ||
    $ctype =~ /charset='([a-z0-9\-]+)'/i ||
    $ctype =~ /charset=([a-z0-9\-]+)/i) {
	$charset = $1;
	}
## Special handling of HTML header charset ($force_charset):
## For japanese text(ISO-2022-JP/EUC=JP/SJIS), the HTML output and
## text contents ($bodycontents) are already converted to EUC,
## so overriding HTML charset to that in the mail header ($charset)
## is generally wrong. (cf. mailbox/boxes-lib.pl:eucconv())
if ( &get_charset() =~ /^EUC/i ) {	# EUC-JP,EUC-KR
	return undef;
	}
else {
	return $charset;
	}
}

# switch_to_folder_user(&folder)
# If a folder has a user, switch the UID and GID used for writes to it
sub switch_to_folder_user
{
my ($folder) = @_;
if ($folder->{'user'} && $switch_to_folder_count == 0) {
	&set_mail_open_user($folder->{'user'});
	}
$switch_to_folder_count++;
}

# switch_from_folder_user(&folder)
# Undoes the change made by switch_to_folder_user
sub switch_from_folder_user
{
my ($folder) = @_;
if ($switch_to_folder_count) {
	$switch_to_folder_count--;
	if ($switch_to_folder_count == 0) {
		&clear_mail_open_user();
		}
	}
else {
	print STDERR "switch_from_folder_user called more often ",
		     "than switch_to_folder_user!\n";
	}
}

1;

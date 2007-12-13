# folders-lib.pl
# Functions for dealing with mail folders in various formats

$pop3_port = 110;
$imap_port = 143;
$cache_directory = $user_module_config_directory || $module_config_directory;

@index_fields = ( "subject", "from", "to", "date", "size",
		  "x-spam-status", "message-id" );

# mailbox_list_mails(start, end, &folder, [headersonly], [&error])
# Returns an array whose size is that of the entire folder, with messages
# in the specified range filled in.
sub mailbox_list_mails
{
if ($_[2]->{'type'} == 0) {
	# List a single mbox formatted file
	return &list_mails($_[2]->{'file'}, $_[0], $_[1]);
	}
elsif ($_[2]->{'type'} == 1) {
	# List a qmail maildir
	local $md = $_[2]->{'file'};
	return &list_maildir($md, $_[0], $_[1]);
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
	local @rv = map { undef } @uidl;

	# For each message in the range, get the headers or body
	local ($i, $f, %cached, %sizeneed);
	local $cd = "$cache_directory/$_[2]->{'id'}.cache";
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
			open(CACHE, ">$cd/$u.body");
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
			open(CACHE, ">$cd/$u.headers");
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
		$rv[$i] = $mail;
		}

	# Get sizes for mails if needed
	if (%sizeneed) {
		&pop3_command($h, "list");
		while(<$h>) {
			s/\r//g;
			last if ($_ eq ".\n");
			if (/^(\d+)\s+(\d+)/ && $sizeneed{$1-1}) {
				# Add size to the mail cache
				$rv[$1-1]->{'size'} = $2;
				local $u = &safe_uidl($uidl[$1-1]);
				open(CACHE, ">>$cd/$u.headers");
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

	return @rv;
	}
elsif ($_[2]->{'type'} == 3) {
	# List an MH directory
	local $md = $_[2]->{'file'};
	return &list_mhdir($md, $_[0], $_[1]);
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
	local @mail = map { undef } (0 .. $count-1);

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
			sprintf "FETCH %d:%d (UID FLAGS RFC822)", $start+1, $end+1);
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

	return @mail;
	}
elsif ($_[2]->{'type'} == 5) {
	# A composite folder, which combined two or more others.
	local @mail;

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

	return @mail;
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
	local @mail = map { undef } (0 .. @$mems-1);
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
				}
			}
		}
	if ($changed) {
		# Need to save virtual folder
		$folder->{'members'} = $mems;
		&save_folder($folder, $folder);
		}
	return @mail;
	}
}

# mailbox_select_mails(&folder, &ids, headersonly)
# Returns only messages from a folder with unique IDs in the given array
sub mailbox_select_mails
{
local ($folder, $ids, $headersonly) = @_;
if ($folder->{'type'} == 0) {
	# mbox folder
	return &select_mails($folder->{'file'}, $ids, $headersonly);
	}
elsif ($folder->{'type'} == 1) {
	# Maildir folder
	return &select_maildir($folder->{'file'}, $ids, $headersonly);
	}
elsif ($folder->{'type'} == 3) {
	# MH folder
	return &select_mhdir($folder->{'file'}, $ids, $headersonly);
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
	local @rv;
	local $cd = "$cache_directory/$_[2]->{'id'}.cache";
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
			open(CACHE, ">$cd/$u.body");
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
			open(CACHE, ">$cd/$u.headers");
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
		push(@rv, $mail);
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
				open(CACHE, ">>$cd/$u.headers");
				print CACHE $2,"\n";
				close(CACHE);
				}
			}
		}

	return @rv;
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
	local @rv = map { undef } @$ids;
	local $wanted = $headersonly ? "(RFC822.SIZE UID FLAGS RFC822.HEADER)"
				     : "(UID FLAGS RFC822)";
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
					$rv[$wantpos{$mail->{'id'}}] = $mail;
					}
				}
			}
		}
	print DEBUG "imap rv = ",scalar(@rv),"\n";

	return @rv;
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
	local @mail = map { undef } @$ids;
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
	return @mail;
	}
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
if ($folder->{'type'} == 0) {
	# mbox, for which IDs are mail positions
	print DEBUG "starting to get IDs from $folder->{'file'}\n";
	local @idlist = &idlist_mails($folder->{'file'});
	print DEBUG "got ",scalar(@idlist)," ids\n";
	return @idlist;
	}
elsif ($folder->{'type'} == 1) {
	# maildir, for which IDs are filenames
	return &idlist_maildir($folder->{'file'});
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
	local @uidl = &pop3_uidl($h);
	return @uidl;
	}
elsif ($folder->{'type'} == 3) {
	# MH directory, for which IDs are file numbers
	return &idlist_mhdir($folder->{'file'});
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
	local @uids;
	foreach my $uid (@{$rv[1]}) {
		if ($uid =~ /UID\s+(\d+)/) {
			push(@uids, $1);
			}
		}
	return @uids;
	}
elsif ($folder->{'type'} == 5) {
	# Composite, IDs come from sub-folders
	local @rv;
	foreach my $sf (@{$folder->{'subfolders'}}) {
		local $sfn = &folder_name($sf);
		push(@rv, map { $sfn."\t".$_ } &mailbox_idlist($sf));
		}
	return @rv;
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
	local @rv;
	foreach my $sfn (keys %wantmap) {
		local %wantids = map { $_, 1 } @{$wantmap{$sfn}};
		local $sf = $namemap{$sfn};
		foreach my $sfid (&mailbox_idlist($sf)) {
			if ($wantids{$sfid}) {
				push(@rv, $sfn."\t".$sfid);
				}
			}
		}
	return @rv;
	}
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
	print DEBUG "deleted $dc mesages from index\n";

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
			if (!$neg && $v =~ /\Q$if->[1]\E/i ||
			    $neg && $v !~ /\Q$if->[1]\E/i) {
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
		local $field = $f->[0];
		local $neg = ($field =~ s/^\!//);
		local $what = $f->[1];
		$what = "\"$what\"" if ($field ne "size");
		$field = "LARGER" if ($field eq "size");
		local $search = uc($field)." ".$what."";
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
if ($userconfig{'delete_mode'} == 1 && !$f->{'trash'} && !$f->{'spam'}) {
	# Copy to trash folder first
	local ($trash) = grep { $_->{'trash'} } &list_folders();
	local $m;
	foreach $m (@_) {
		local $mcopy = { %$m };		# Because writing changes id
		&write_mail_folder($mcopy, $trash);
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
	local $cd = "$cache_directory/$f->{'id'}.cache";
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
	# Just clear the virtual index
	$f->{'members'} = [ ];
	&save_folder($f);
	}

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
	&open_readfile(SOURCE, $src->{'file'});
	&open_tempfile(DEST, ">>$dest->{'file'}");
	while(read(SOURCE, $buf, 1024) > 0) {
		&print_tempfile(DEST, $buf);
		}
	&close_tempfile(DEST);
	close(SOURCE);
	}
elsif ($src->{'type'} == 1 && $dest->{'type'} == 1) {
	# maildir to maildir .. just copy the files
	local @files = &get_maildir_files($src->{'file'});
	foreach my $f (@files) {
		local $fn = $f;
		$fn =~ s/^.*\///;
		&copy_source_dest($f, "$dest->{'file'}/$fn");
		}
	}
elsif ($src->{'type'} == 1 && $dest->{'type'} == 0) {
	# maildir to mbox .. append all the files
	local @files = &get_maildir_files($src->{'file'});
	&open_tempfile(DEST, ">>$dest->{'file'}");
	foreach my $f (@files) {
		&open_readfile(SOURCE, $f);
		while(read(SOURCE, $buf, 1024) > 0) {
			&print_tempfile(DEST, $buf);
			}
		close(SOURCE);
		}
	&close_tempfile(DEST);
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
&create_folder_maildir($dst);
local $fix_index;
if (($src->{'type'} == 1 || $src->{'type'} == 3) && $dst->{'type'} == 1) {
	# Can just move mail files
	local $dd = $dst->{'file'};
	&create_folder_maildir($dst);
	foreach $m (@_) {
		rename($m->{'file'}, "$dd/cur/$now.$$.$hn");
		$now++;
		}
	$fix_index = 1;
	}
elsif (($src->{'type'} == 1 || $src->{'type'} == 3) && $dst->{'type'} == 3) {
	# Can move and rename to MH numbering
	local $dd = $dst->{'file'};
	local $num = &max_mhdir($dst->{'file'}) + 1;
	foreach $m (@_) {
		rename($m->{'file'}, "$dd/$num");
		$num++;
		}
	$fix_index = 1;
	}
else {
	# Append to new folder file, or create in folder directory
	local $m;
	local @mdel;
	foreach $m (@_) {
		local $mcopy = { %$m };
		&write_mail_folder($m, $dst);
		push(@mdel, $mcopy);
		}
	&mailbox_delete_mail($src, @mdel);
	}
}

# mailbox_move_folder(&source, &dest)
# Moves all mail from one folder to another, possibly converting the type
sub mailbox_move_folder
{
return undef if (&is_readonly_mode());
local ($src, $dst) = @_;
if ($src->{'type'} == $dst->{'type'} && !$src->{'remote'}) {
	# Can just move the file or dir
	local @st = stat($dst->{'file'});
	system("rm -rf ".quotemeta($dst->{'file'}));
	system("mv ".quotemeta($src->{'file'})." ".quotemeta($dst->{'file'}));
	if ($< == 0 && @st) {
		if ($src->{'type'} == 0) {
			# Fix mbox perms
			&set_ownership_permissions($st[4], $st[5], $st[2],
						   $dst->{'file'});
			}
		else {
			# Fix maildir/MH perms
			system("chown -R $st[4]:$st[5] ".
			       quotemeta($dst->{'file'}));
			}
		}
	}
else {
	# Need to copy one by one :(
	local @mails = &mailbox_list_mails(undef, undef, $src);
	&mailbox_move_mail($src, $dst, @mails);
	}

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
&create_folder_maildir($dst);
local $m;
if ($src->{'type'} == 6 && $dst->{'type'} == 6) {
	# Copying from one virtual folder to another, so just copy the
	# reference
	foreach $m (@_) {
		push(@{$dst->{'members'}}, [ $m->{'subfolder'}, $m->{'subid'},
					     $m->{'header'}->{'message-id'} ]);
		}
	}
elsif ($dst->{'type'} == 6) {
	# Add this mail to the index of the virtual folder
	foreach $m (@_) {
		push(@{$dst->{'members'}}, [ $src, $m->{'idx'},
					     $m->{'header'}->{'message-id'} ]);
		}
	&save_folder($dst);
	}
else {
	# Just write to destination folder
	foreach $m (@_) {
		&write_mail_folder($m, $dst);
		}
	}
}

# folder_type(file_or_dir)
sub folder_type
{
return -d "$_[0]/cur" ? 1 : -d $_[0] ? 3 : 0;
}

# create_folder_maildir(&folder)
# Ensure that a maildir folder has the needed new, cur and tmp directories
sub create_folder_maildir
{
mkdir($folders_dir, 0700);
if ($_[0]->{'type'} == 1) {
	local $id = $_[0]->{'file'};
	mkdir("$id/cur", 0700);
	mkdir("$id/new", 0700);
	mkdir("$id/tmp", 0700);
	}
}

# write_mail_folder(&mail, &folder, textonly)
# Writes some mail message to a folder
sub write_mail_folder
{
return undef if (&is_readonly_mode());
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
	&send_mail($_[0], $temp, $_[2], 1);
	local $text = &read_file_contents($temp);
	unlink($temp);
	@rv = &imap_command($h, sprintf "APPEND %s {%d}\r\n%s",
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
	&error("Cannot add mail to virtual folders");
	}
if ($needid) {
	local @idlist = &mailbox_idlist($_[1]);
	$_[0]->{'id'} = $idlist[$#idlist];
	}
}

# mailbox_modify_mail(&oldmail, &newmail, &folder, textonly)
# Replaces some mail message with a new one
sub mailbox_modify_mail
{
local ($oldmail, $mail, $folder, $textonly) = @_;

return undef if (&is_readonly_mode());
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
if ($_[0]->{'type'} == 0) {
	# A mbox formatted file
	return &count_mail($_[0]->{'file'});
	}
elsif ($_[0]->{'type'} == 1) {
	# A qmail maildir
	return &count_maildir($_[0]->{'file'});
	}
elsif ($_[0]->{'type'} == 2) {
	# A POP3 server
	local @rv = &pop3_login($_[0]);
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
elsif ($_[0]->{'type'} == 3) {
	# An MH directory
	return &count_mhdir($_[0]->{'file'});
	}
elsif ($_[0]->{'type'} == 4) {
	# An IMAP server
	local @rv = &imap_login($_[0]);
	if ($rv[0] != 1) {
		if ($rv[0] == 0) { &error($rv[1]); }
		elsif ($rv[0] == 3) { &error(&text('save_emailbox', $rv[1])); }
		elsif ($rv[0] == 2) { &error(&text('save_elogin2', $rv[1])); }
		}
        $_[0]->{'lastchange'} = $rv[3];
	return $rv[2];
	}
elsif ($_[0]->{'type'} == 5) {
	# A composite folder - the size is just that of the sub-folders
	my $rv = 0;
	foreach my $sf (@{$_[0]->{'subfolders'}}) {
		$rv += &mailbox_folder_size($sf);
		}
	return $rv;
	}
elsif ($_[0]->{'type'} == 6 && !$_[1]) {
	# A virtual folder .. we need to exclude messages that no longer
	# exist in the parent folders
	my $rv = 0;
	foreach my $msg (@{$_[0]->{'members'}}) {
		if (&mailbox_get_mail($msg->[0], $msg->[1])) {
			$rv++;
			}
		}
	return $rv;
	}
elsif ($_[0]->{'type'} == 6 && $_[1]) {
	# A virtual folder .. but we can just use the last member count
	return scalar(@{$_[0]->{'members'}});
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
		next if (!defined($f->[0]));
		local $pm = $f->[0] ? "+" : "-";
		@rv = &imap_command($h, "UID STORE ".$mail->{'id'}.
					" ".$pm."FLAGS (".$f->[1].")");
		&error(&text('save_eflag', $rv[3])) if (!$rv[0]); 
		}
	
	# Update the mail object too
	$mail->{'read'} = $read if (defined($read));
	$mail->{'special'} = $special if (defined($special));
	$mail->{'replied'} = $replied if (defined($replied));
	}
else {
	&error("Read flags cannot be set on folders of type $folder->{'type'}");
	}
}

# pop3_login(&folder)
# Logs into a POP3 server and returns a status (1=ok, 0=connect failed,
# 2=login failed) and handle or error message
sub pop3_login
{
local $h = $pop3_login_handle{$_[0]->{'id'}};
return (1, $h) if ($h);
$h = time().++$pop3_login_count;
local $error;
&open_socket($_[0]->{'server'}, $_[0]->{'port'} || 110, $h, \$error);
return (0, $error) if ($error);
local $os = select($h); $| = 1; select($os);
local @rv = &pop3_command($h);
return (0, $rv[1]) if (!$rv[0]);
@rv = &pop3_command($h, "user $_[0]->{'user'}");
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
# message, the number of messages in the mailbox, and the next UID
sub imap_login
{
local $h = $imap_login_handle{$_[0]->{'id'}};
local @rv;
if (!$h) {
	# Need to open socket
	$h = time().++$imap_login_count;
	local $error;
	&open_socket($_[0]->{'server'}, $_[0]->{'port'} ||
		$imap_port, $h, \$error);
	return (0, $error) if ($error);
	local $os = select($h); $| = 1; select($os);

	# Login normally
	@rv = &imap_command($h);
	return (0, $rv[3]) if (!$rv[0]);
	@rv = &imap_command($h,"login \"$_[0]->{'user'}\" \"$_[0]->{'pass'}\"");
	return (2, $rv[3]) if (!$rv[0]);

	$imap_login_handle{$_[0]->{'id'}} = $h;
	}

# Select the right folder (if one was given)
@rv = &imap_command($h, "select ".($_[0]->{'mailbox'} || "INBOX"));
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
local @rv;

# Send the command, and read lines until a non-* one is found
local $id = $$."-".$imap_command_count++;
if ($c) {
	print $h "$id $c\r\n";
	print DEBUG "imap command $id $c\n";
	}
while(1) {
	local $l = <$h>;
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
				return (0, [ $err ], $err, $err) if ($r < 0);
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
local $lline = $rv[$#rv];
if ($lline =~ /^(\S+)\s+OK\s*(.*)/) {
	# Looks like the command worked
	return (1, \@rv, $j, $2);
	}
else {
	# Command failed!
	return (0, \@rv, $j, $lline =~ /^(\S+)\s+(\S+)\s*(.*)/ ? $3 : undef);
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
	else {
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
if ($html =~ s/^[\000-\377]*<BODY([^>]*)>//i) {
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
	# Definately safe (CIDs are harmless)
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
	open(TEMP, ">$temp");
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
	push(@opts, [ $byid ? &folder_name($f) : $f->{'index'}, $f->{'name'} ]);
	}
return &ui_select($name, $byid ? &folder_name($folder) : $folder->{'index'},
		  \@opts, 1, 0, 0, 0, $auto ? "onChange='form.submit()'" : "");
return $sel;
}

# folder_size(&folder, ...)
# Sets the 'size' field of one or more folders, and returns the total
sub folder_size
{
local ($f, $total);
foreach $f (@_) {
	if ($f->{'type'} == 0) {
		# Single mail file - size is easy
		local @st = stat($f->{'file'});
		$f->{'size'} = $st[7];
		}
	elsif ($f->{'type'} == 1) {
		# Maildir folder size is that of all files in it
		$f->{'size'} = &recursive_disk_usage($f->{'file'});
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
		 $f =~ /\.webmintmp(\.\d+)$/);
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
	$cidmap->{$1} = time().$$;
	return "cid:".$cidmap->{$1};
	}
else {
	# No attachment ID!
	return "";
	}
}

# disable_html_images(html, disable?, &urls)
# Turn off some or all images in HTML email. Mode 0=Do nothing, 1=Offsite only,
# 2=All images. Returns the number of images found.
sub disable_html_images
{
local ($html, $dis, $urls) = @_;
local $newhtml;
while($html =~ /^([\000-\377]*)(<\s*img[^>]*src=('[^']*'|"[^"]*"|\S+)[^>]*>)([\000-\377]*)/) {
	local ($before, $allimg, $img, $after) = ($1, $2, $3);
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

# quoted_message(&mail, quote-mode, sig, 0=any,1=text,2=html)
# Returns the quoted text, html-flag and body attachment
sub quoted_message
{
local ($mail, $qu, $sig, $bodymode) = @_;
local $mode = $bodymode == 1 ? 1 :
	      $bodymode == 2 ? 2 :
	      defined(%userconfig) ? $userconfig{'view_html'} :
				     $config{'view_html'};
local ($plainbody, $htmlbody) = &find_body($mail, $mode);
local ($quote, $html_edit, $body);
local $cfg = defined(%userconfig) ? \%userconfig : \%config;
local @writers = &split_addresses($mail->{'header'}->{'from'});
local $writer = &decode_mimewords($writers[0]->[1] || $writers[0]->[0]).
		" wrote ..";
local $tm;
if ($cfg->{'reply_date'} &&
    ($tm = &parse_mail_date($_[0]->{'header'}->{'date'}))) {
	local $tmstr = &make_date($tm);
	$writer = "On $tmstr $writer";
	}
local $qm = defined(%userconfig) ? $userconfig{'html_quote'}
				 : $config{'html_quote'};
if (($cfg->{'html_edit'} == 2 ||
     $cfg->{'html_edit'} == 1 && $htmlbody) &&
     $bodymode != 1) {
	# Create quoted body HTML
	if ($htmlbody) {
		$body = $htmlbody;
		$sig =~ s/\n/<br>\n/g;
		if ($qu && $qm == 0) {
			# Quoted HTML as cite
			$quote = "$writer\n".
				 "<blockquote type=cite>\n".
				 &safe_html($htmlbody->{'data'}).
				 "</blockquote>".$sig."<br>\n";
			}
		elsif ($qu && $qm == 1) {
			# Quoted HTML below line
			$quote = "<br>$sig<hr>".
			         "$writer<br>\n".
				 &safe_html($htmlbody->{'data'});
			}
		else {
			# Un-quoted HTML
			$quote = &safe_html($htmlbody->{'data'}).
				 $sig."<br>\n";
			}
		}
	elsif ($plainbody) {
		$body = $plainbody;
		local $pd = $plainbody->{'data'};
		$pd =~ s/^\s+//g;
		$pd =~ s/\s+$//g;
		if ($qu && $qm == 0) {
			# Quoted plain text as HTML as cite
			$quote = "$writer\n".
				 "<blockquote type=cite>\n".
				 "<pre>$pd</pre>".
				 "</blockquote>".$sig."<br>\n";
			}
		elsif ($qu && $qm == 1) {
			# Quoted plain text as HTML below line
			$quote = "<br>$sig<hr>".
				 "$writer<br>\n".
				 "<pre>$pd</pre><br>\n";
			}
		else {
			# Un-quoted plain text as HTML
			$quote = "<pre>$pd</pre>".
				 $sig."<br>\n";
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
	$quote .= "$sig\n" if ($sig);
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
local $rv;
if ($_[2] && exists($_[2]->{$_[0]})) {
	# In cache
	$rv = $_[2]->{$_[0]};
	}
else {
	# Need to lookup
	($rv) = grep { $_->{'id'} eq $_[0] } @{$_[1]} if (!$rv);
	($rv) = grep { my $escfile = $_->{'file'};
		       $escfile =~ s/\s/_/g;
		       $escfile eq $_[0] ||
		       $_->{'file'} eq $_[0] ||
		       $_->{'server'} eq $_[0] } @{$_[1]} if (!$rv);
	($rv) = grep { my $escname = $_->{'name'};
		       $escname =~ s/\s/_/g;
		       $escname eq $_[0] ||
		       $_->{'name'} eq $_[0] } @{$_[1]} if (!$rv);
	$_[2]->{$_[0]} = $rv if ($_[2]);
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

# mail_preview(&mail)
# Returns a short text preview of a message body
sub mail_preview
{
local ($textbody, $htmlbody, $body) = &find_body($_[0], 0);
local $data = $body->{'data'};
$data =~ s/\r?\n/ /g;
$data = substr($data, 0, 100);
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

1;


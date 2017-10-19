# boxes-lib.pl
# Functions to parsing user mail files

use POSIX;
use Fcntl;
if ($userconfig{'date_tz'} || $config{'date_tz'}) {
        # Set the timezone for all date calculations, and force a conversion
        # now as in some cases the first one fails!
        $ENV{'TZ'} = $userconfig{'date_tz'} ||
                     $config{'date_tz'};
        strftime('%H:%M', localtime(time()));
        }
use Time::Local;

$dbm_index_min = 1000000;
$dbm_index_version = 3;

# list_mails(user|file, [start], [end])
# Returns a subset of mail from a mbox format file
sub list_mails
{
local (@rv, $h, $done);
my %index;
my $umf = &user_mail_file($_[0]);
&open_as_mail_user(MAIL, $umf) || &error("Failed to open $umf : $!");
&build_dbm_index($_[0], \%index);
local ($start, $end);
local $isize = $index{'mailcount'};
if (@_ == 1 || !defined($_[1]) && !defined($_[2])) {
	$start = 0; $end = $isize-1;
	}
elsif ($_[2] < 0) {
	$start = $isize+$_[2]-1; $end = $isize+$_[1]-1;
	$start = $start<0 ? 0 : $start;
	}
else {
	$start = $_[1]; $end = $_[2];
	$end = $isize-1 if ($end >= $isize);
	}
$rv[$isize-1] = undef if ($isize);	# force array to right size
local $dash = &dash_mode($_[0]);
$start = 0 if ($start < 0);
for($i=$start; $i<=$end; $i++) {
	# Seek to mail position
	local @idx = split(/\0/, $index{$i});
	local $pos = $idx[0];
	local $startline = $idx[1];
	seek(MAIL, $pos, 0);

	# Read the mail
	local $mail = &read_mail_fh(MAIL, $dash ? 2 : 1, 0);
	$mail->{'line'} = $startline;
	$mail->{'eline'} = $startline + $mail->{'lines'} - 1;
	$mail->{'idx'} = $i;
	# ID is position in file and message ID
	$mail->{'id'} = $pos." ".$i." ".$startline." ".
		substr($mail->{'header'}->{'message-id'}, 0, 255);
	$rv[$i] = $mail;
	}
return @rv;
}

# select_mails(user|file, &ids, headersonly)
# Returns a list of messages from an mbox with the given IDs. The ID contains
# the file offset, message number, line and message ID, and the former is used
# if valid.
sub select_mails
{
local ($file, $ids, $headersonly) = @_;
local @rv;

local (@rv);
my %index;
local $gotindex;

local $umf = &user_mail_file($file);
local $dash = &dash_mode($umf);
&open_as_mail_user(MAIL, $umf) || &error("Failed to open $umf : $!");
foreach my $i (@$ids) {
	local ($pos, $idx, $startline, $wantmid) = split(/ /, $i);

	# Go to where the mail is supposed to be, and check if any starts there
	seek(MAIL, $pos, 0);
	local $ll = <MAIL>;
	local $fromok = $ll !~ /^From\s+(\S+).*\d+\r?\n/ ||
			($1 eq '-' && !$dash) ? 0 : 1;
	print DEBUG "seeking to $pos in $umf, got $ll";
	if (!$fromok) {
		# Oh noes! Need to find it
		if (!$gotindex++) {
			&build_dbm_index($file, \%index);
			}
		$pos = undef;
		while(my ($k, $v) = each %index) {
			if (int($k) eq $k) {
				my ($p, $line, $subject, $from, $mid)=
					split(/\0/, $v);
				if ($mid eq $wantmid) {
					# Found it!
					$pos = $p;
					$idx = $k;
					$startline = $line;
					last;
					}
				}
			}
		}

	if (defined($pos)) {
		# Now we can read
		seek(MAIL, $pos, 0);
		local $mail = &read_mail_fh(MAIL, $dash ? 2 : 1, $headersonly);
		$mail->{'line'} = $startline;
		$mail->{'eline'} = $startline + $mail->{'lines'} - 1;
		$mail->{'idx'} = $idx;
		$mail->{'id'} = "$pos $idx $startline $wantmid";
		push(@rv, $mail);
		}
	else {
		push(@rv, undef);	# Mail is gone?
		}
	}
close(MAIL);
return @rv;
}

# idlist_mails(user|file)
# Returns a list of IDs in some mbox
sub idlist_mails
{
my %index;
local $idlist = &build_dbm_index($_[0], \%index);
return @$idlist;
}

# search_mail(user, field, match)
# Returns an array of messages matching some search
sub search_mail
{
return &advanced_search_mail($_[0], [ [ $_[1], $_[2] ] ], 1);
}

# advanced_search_mail(user|file, &fields, andmode, [&limits], [headersonly])
# Returns an array of messages matching some search
sub advanced_search_mail
{
local (%index, @rv, $i);
local $dash = &dash_mode($_[0]);
local @possible;		# index positions of possible mails
local $possible_certain = 0;	# is possible list authoratative?
local ($min, $max);
local $umf = &user_mail_file($_[0]);
&open_as_mail_user(MAIL, $umf) || &error("Failed to open $umf : $!");

# We have a DBM index .. if the search includes the from and subject
# fields, scan it first to cut down on the total time
&build_dbm_index($_[0], \%index);

# Check which fields are used in search
local @dbmfields = grep { $_->[0] eq 'from' ||
			  $_->[0] eq 'subject' } @{$_[1]};
local $alldbm = (scalar(@dbmfields) == scalar(@{$_[1]}));

$min = 0;
$max = $index{'mailcount'}-1;
if ($_[3] && $_[3]->{'latest'}) {
	$min = $max - $_[3]->{'latest'};
	}

# Only check DBM if it contains some fields, and if it contains all
# fields when in 'or' mode.
if (@dbmfields && ($alldbm || $_[2])) {
	# Scan the DBM to build up a list of 'possibles'
	for($i=$min; $i<=$max; $i++) {
		local @idx = split(/\0/, $index{$i});
		local $fake = { 'header' => { 'from', $idx[2],
					      'subject', $idx[3] } };
		local $m = &mail_matches(\@dbmfields, $_[2], $fake);
		push(@possible, $i) if ($m);
		}
	$possible_certain = $alldbm;
	}
else {
	# None of the DBM fields are in the search .. have to scan all
	@possible = ($min .. $max);
	}

# Need to scan through possible messages to find those that match
local $headersonly = !&matches_needs_body($_[1]);
foreach $i (@possible) {
	# Seek to mail position
	local @idx = split(/\0/, $index{$i});
	local $pos = $idx[0];
	local $startline = $idx[1];
	seek(MAIL, $pos, 0);

	# Read the mail
	local $mail = &read_mail_fh(MAIL, $dash ? 2 : 1, $headersonly);
	$mail->{'line'} = $startline;
	$mail->{'eline'} = $startline + $mail->{'lines'} - 1;
	$mail->{'idx'} = $i;
	$mail->{'id'} = $pos." ".$i." ".$startline." ".
			substr($mail->{'header'}->{'message-id'}, 0, 255);
	push(@rv, $mail) if ($possible_certain ||
			     &mail_matches($_[1], $_[2], $mail));
	}
return @rv;
}

# build_dbm_index(user|file, &index)
# Updates a reference to a DBM hash that indexes the given mail file.
# Hash contains keys 0, 1, 2 .. each of which has a value containing the
# position of the mail in the file, line number, subject, sender and message ID.
# Special key lastchange = time index was last updated
#	      mailcount = number of messages in index
#	      version = index format version
# Returns a list of all IDs
sub build_dbm_index
{
local ($user, $index, $noperm) = @_;
local $ifile = &user_index_file($user);
local $umf = &user_mail_file($user);
local @st = stat($umf);
if (!defined($noperm)) {
	# Use global override setting
	$noperm = $no_permanent_index;
	}
if ($noperm && &has_dbm_index($user)) {
	# Index already exists, so use it
	$noperm = 0;
	}
if (!$noperm) {
	dbmopen(%$index, $ifile, 0600);
	}

# Read file of IDs
local $idsfile = $ifile.".ids";
local @ids;
local $idschanged;
if (!$noperm && open(IDSFILE, "<", $idsfile)) {
	@ids = <IDSFILE>;
	chop(@ids);
	close(IDSFILE);
	}

if (scalar(@ids) != $index->{'mailcount'}) {
	# Build for first time
	print DEBUG "need meta-index rebuild for $user ",scalar(@ids)," != ",$index->{'mailcount'},"\n";
	@ids = ( );
	while(my ($k, $v) = each %$index) {
		if ($k eq int($k) && $k < $index->{'mailcount'}) {
			local ($pos, $line, $subject, $sender, $mid) =
				split(/\0/, $v);
			$ids[$k] = $pos." ".$k." ".$line." ".$mid;
			}
		elsif ($k >= $index->{'mailcount'}) {
			# Old crap that is off the end
			delete($index->{$k});
			}
		}
	$index->{'mailcount'} = scalar(@ids);	# Now known for sure
	$idschanged = 1;
	}

if (!@st ||
    $index->{'lastchange'} < $st[9] ||
    $index->{'lastsize'} != $st[7] ||
    $st[7] < $dbm_index_min ||
    $index->{'version'} != $dbm_index_version) {
	# The mail file is newer than the index, or we are always re-indexing
	local $fromok = 1;
	local ($ll, @idx);
	local $dash = &dash_mode($umf);
	if ($st[7] < $dbm_index_min ||
	    $index->{'version'} != $dbm_index_version) {
		$fromok = 0;	# Always re-index
		&open_as_mail_user(IMAIL, $umf);
		}
	else {
		if (&open_as_mail_user(IMAIL, $umf)) {
			# Check the last 100 messages (at most), to see if
			# the mail file has been truncated, had mails deleted,
			# or re-written.
			local $il = $index->{'mailcount'}-1;
			local $i;
			for($i=($il>100 ? 100 : $il); $i>=0; $i--) {
				@idx = split(/\0/, $index->{$il-$i});
				seek(IMAIL, $idx[0], 0);
				$ll = <IMAIL>;
				$fromok = 0 if ($ll !~ /^From\s+(\S+).*\d+\r?\n/ ||
						($1 eq '-' && !$dash));
				}
			}
		else {
			$fromok = 0;	# No mail file yet
			}
		}
	local ($pos, $lnum, $istart);
	if ($index->{'mailcount'} && $fromok && $st[7] > $idx[0]) {
		# Mail file seems to have gotten bigger, most likely
		# because new mail has arrived ... only reindex the new mails
		print DEBUG "re-indexing from $idx[0]\n";
		$pos = $idx[0] + length($ll);
		$lnum = $idx[1] + 1;
		$istart = $index->{'mailcount'};
		}
	else {
		# Mail file has changed in some other way ... do a rebuild
		# of the whole index
		print DEBUG "totally re-indexing\n";
		$istart = 0;
		$pos = 0;
		$lnum = 0;
		seek(IMAIL, 0, 0);
		@ids = ( );
		$idschanged = 1;
		%$index = ( );
		}
	local ($doingheaders, @nidx);
	while(<IMAIL>) {
		if (/^From\s+(\S+).*\d+\r?\n/ && ($1 ne '-' || $dash)) {
			@nidx = ( $pos, $lnum );
			$idschanged = 1;
			push(@ids, $pos." ".$istart." ".$lnum);
			$index->{$istart++} = join("\0", @nidx);
			$doingheaders = 1;
			}
		elsif ($_ eq "\n" || $_ eq "\r\n") {
			$doingheaders = 0;
			}
		elsif ($doingheaders && /^From:\s*(.{0,255})/i) {
			$nidx[2] = $1;
			$index->{$istart-1} = join("\0", @nidx);
			}
		elsif ($doingheaders && /^Subject:\s*(.{0,255})/i) {
			$nidx[3] = $1;
			$index->{$istart-1} = join("\0", @nidx);
			}
		elsif ($doingheaders && /^Message-ID:\s*(.{0,255})/i) {
			$nidx[4] = $1;
			$index->{$istart-1} = join("\0", @nidx);
			$ids[$#ids] .= " ".$1;
			}
		$pos += length($_);
		$lnum++;
		}
	close(IMAIL);
	$index->{'lastchange'} = time();
	$index->{'lastsize'} = $st[7];
	$index->{'mailcount'} = $istart;
	$index->{'version'} = $dbm_index_version;
	}

# Write out IDs file, if needed
if ($idschanged && !$noperm) {
	open(IDSFILE, ">", $idsfile);
	foreach my $id (@ids) {
		print IDSFILE $id,"\n";
		}
	close(IDSFILE);
	}

return \@ids;
}

# has_dbm_index(user|file)
# Returns 1 if a DBM index exists for some user or file
sub has_dbm_index
{
local $ifile = &user_index_file($_[0]);
foreach my $ext (".dir", ".pag", ".db") {
	return 1 if (-r $ifile.$ext);
	}
return 0;
}

# delete_dbm_index(user|file)
# Deletes all DBM indexes for a user or file
sub delete_dbm_index
{
local $ifile = &user_index_file($_[0]);
foreach my $ext (".dir", ".pag", ".db") {
	&unlink_file($ifile.$ext);
	}
}

# empty_mail(user|file)
# Truncate a mail file to nothing
sub empty_mail
{
local ($user) = @_;
local $umf = &user_mail_file($user);
local $ifile = &user_index_file($user);
&open_as_mail_user(TRUNC, ">$umf") || &error("Failed to open $umf : $!");
close(TRUNC);

# Set index size to 0 (if there is one)
if (&has_dbm_index($user)) {
	local %index;
	dbmopen(%index, $ifile, 0600);
	$index{'mailcount'} = 0;
	$index{'lastchange'} = time();
	dbmclose(%index);
	}
}

# count_mail(user|file)
# Returns the number of messages in some mail file
sub count_mail
{
my %index;
&build_dbm_index($_[0], \%index);
return $index{'mailcount'};
}

# parse_mail(&mail, [&parent], [savebody], [keep-cr])
# Extracts the attachments from the mail body
sub parse_mail
{
return if ($_[0]->{'parsed'}++);
local $ct = $_[0]->{'header'}->{'content-type'};
local (@attach, $h, $a);
if ($ct =~ /multipart\/(\S+)/i && ($ct =~ /boundary="([^"]+)"/i ||
				   $ct =~ /boundary=([^;\s]+)/i)) {
	# Multipart MIME message
	local $bound = "--".$1;
	local @lines = $_[3] ? split(/\n/, $_[0]->{'body'})
			     : split(/\r?\n/, $_[0]->{'body'});
	local $l;
	local $max = @lines;
	while($l < $max && $lines[$l++] ne $bound) {
		# skip to first boundary
		}
	while(1) {
		# read attachment headers
		local (@headers, $attach);
		while($lines[$l]) {
			$attach->{'raw'} .= $lines[$l]."\n";
			$attach->{'rawheaders'} .= $lines[$l]."\n";
			if ($lines[$l] =~ /^(\S+):\s*(.*)/) {
				push(@headers, [ $1, $2 ]);
				}
			elsif ($lines[$l] =~ /^\s+(.*)/) {
				$headers[$#headers]->[1] .= " ".$1
					unless($#headers < 0);
				}
			$l++;
			}
		$attach->{'raw'} .= $lines[$l]."\n";
		$l++;
		$attach->{'headers'} = \@headers;
		foreach $h (@headers) {
			$attach->{'header'}->{lc($h->[0])} = $h->[1];
			}
		if ($attach->{'header'}->{'content-type'} =~ /^([^;\s]+)/) {
			$attach->{'type'} = lc($1);
			}
		else {
			$attach->{'type'} = 'text/plain';
			}
		if ($attach->{'header'}->{'content-disposition'} =~
		    /filename\s*=\s*"([^"]+)"/i) {
			$attach->{'filename'} = $1;
			}
		elsif ($attach->{'header'}->{'content-disposition'} =~
		       /filename\s*=\s*([^;\s]+)/i) {
			$attach->{'filename'} = $1;
			}
		elsif ($attach->{'header'}->{'content-type'} =~
		       /name\s*=\s*"([^"]+)"/i) {
			$attach->{'filename'} = $1;
			}
		elsif ($attach->{'header'}->{'content-type'} =~
		       /name\s*=\s*([^;\s]+)/i) {
			$attach->{'filename'} = $1;
			}

		# read the attachment body
		while($l < $max && $lines[$l] ne $bound && $lines[$l] ne "$bound--") {
			$attach->{'data'} .= $lines[$l]."\n";
			$attach->{'raw'} .= $lines[$l]."\n";
			$l++;
			}
		$attach->{'data'} =~ s/\n\n$/\n/;	# Lose trailing blank line
		$attach->{'raw'} =~ s/\n\n$/\n/;

		# decode if necessary
		if (lc($attach->{'header'}->{'content-transfer-encoding'}) eq
		    'base64') {
			# Standard base64 encoded attachment
			$attach->{'data'} = &decode_base64($attach->{'data'});
			}
		elsif (lc($attach->{'header'}->{'content-transfer-encoding'}) eq
		       'x-uue') {
			# UUencoded attachment
			$attach->{'data'} = &uudecode($attach->{'data'});
			}
		elsif (lc($attach->{'header'}->{'content-transfer-encoding'}) eq
		       'quoted-printable') {
			# Quoted-printable text attachment
			$attach->{'data'} = &quoted_decode($attach->{'data'});
			}
		elsif (lc($attach->{'type'}) eq 'application/mac-binhex40' && &has_command("hexbin")) {
			# Macintosh binhex encoded attachment
			local $temp = &transname();
			mkdir($temp, 0700);
			open(HEXBIN, "| (cd $temp ; hexbin -n attach -d 2>/dev/null)");
			print HEXBIN $attach->{'data'};
			close(HEXBIN);
			if (!$?) {
				open(HEXBIN, "$temp/attach.data");
				local $/ = undef;
				$attach->{'data'} = <HEXBIN>;
				close(HEXBIN);
				local $ct = &guess_mime_type($attach->{'filename'});
				$attach->{'type'} = $ct;
				$attach->{'header'} = { 'content-type' => $ct };
				$attach->{'headers'} = [ [ 'Content-Type', $ct ] ];
				}
			unlink("$temp/attach.data");
			rmdir($temp);
			}

		$attach->{'idx'} = scalar(@attach);
		$attach->{'parent'} = $_[1] ? $_[1] : $_[0];
		push(@attach, $attach) if (@headers || $attach->{'data'});
		if ($attach->{'type'} =~ /multipart\/(\S+)/i) {
			# This attachment contains more attachments ..
			# expand them.
			local $amail = { 'header' => $attach->{'header'},
					 'body' => $attach->{'data'} };
			&parse_mail($amail, $attach, 0, $_[3]);
			$attach->{'attach'} = [ @{$amail->{'attach'}} ];
			map { $_->{'idx'} += scalar(@attach) }
			    @{$amail->{'attach'}};
			push(@attach, @{$amail->{'attach'}});
			}
		elsif (lc($attach->{'type'}) eq 'application/ms-tnef') {
			# This attachment is a winmail.dat file, which may
			# contain multiple other attachments!
			local ($opentnef, $tnef);
			if (!($opentnef = &has_command("opentnef")) &&
			    !($tnef = &has_command("tnef"))) {
				$attach->{'error'} = "tnef command not installed";
				}
			else {
				# Can actually decode
				local $tempfile = &transname();
				open(TEMPFILE, ">$tempfile");
				print TEMPFILE $attach->{'data'};
				close(TEMPFILE);
				local $tempdir = &transname();
				mkdir($tempdir, 0700);
				if ($opentnef) {
					system("$opentnef -d $tempdir -i $tempfile >/dev/null 2>&1");
					}
				else {
					system("$tnef -C $tempdir -f $tempfile >/dev/null 2>&1");
					}
				pop(@attach);	# lose winmail.dat
				opendir(DIR, $tempdir);
				while($f = readdir(DIR)) {
					next if ($f eq '.' || $f eq '..');
					local $data;
					open(FILE, "$tempdir/$f");
					while(<FILE>) {
						$data .= $_;
						}
					close(FILE);
					local $ct = &guess_mime_type($f);
					push(@attach,
					  { 'type' => $ct,
					    'idx' => scalar(@attach),
					    'header' =>
						{ 'content-type' => $ct },
					    'headers' =>
						[ [ 'Content-Type', $ct ] ],
					    'filename' => $f,
					    'data' => $data });
					}
				closedir(DIR);
				unlink(glob("$tempdir/*"), $tempfile);
				rmdir($tempdir);
				}
			}
		last if ($l >= $max || $lines[$l] eq "$bound--");
		$l++;
		}
	$_[0]->{'attach'} = \@attach;
	}
elsif ($_[0]->{'body'} =~ /begin\s+([0-7]+)\s+(.*)/i) {
	# Message contains uuencoded file(s)
	local @lines = split(/\n/, $_[0]->{'body'});
	local ($attach, $rest);
	foreach $l (@lines) {
		if ($l =~ /^begin\s+([0-7]+)\s+(.*)/i) {
			$attach = { 'type' => &guess_mime_type($2),
				    'idx' => scalar(@{$_[0]->{'attach'}}),
				    'parent' => $_[1],
				    'filename' => $2 };
			push(@{$_[0]->{'attach'}}, $attach);
			}
		elsif ($l =~ /^end/ && $attach) {
			$attach = undef;
			}
		elsif ($attach) {
			$attach->{'data'} .= unpack("u", $l);
			}
		else {
			$rest .= $l."\n";
			}
		}
	if ($rest =~ /\S/) {
		# Some leftover text
		push(@{$_[0]->{'attach'}},
			{ 'type' => "text/plain",
			  'idx' => scalar(@{$_[0]->{'attach'}}),
			  'parent' => $_[1],
			  'data' => $rest });
		}
	}
elsif (lc($_[0]->{'header'}->{'content-transfer-encoding'}) eq 'base64') {
	# Signed body section
	$ct =~ s/;.*$//;
	$_[0]->{'attach'} = [ { 'type' => lc($ct),
				'idx' => 0,
				'parent' => $_[1],
				'data' => &decode_base64($_[0]->{'body'}) } ];
	}
elsif (lc($_[0]->{'header'}->{'content-type'}) eq 'x-sun-attachment') {
	# Sun attachment format, which can contain several sections
	local $sun;
	foreach $sun (split(/----------/, $_[0]->{'body'})) {
		local ($headers, $rest) = split(/\r?\n\r?\n/, $sun, 2);
		local $attach = { 'idx' => scalar(@{$_[0]->{'attach'}}),
				  'parent' => $_[1],
				  'data' => $rest };
		if ($headers =~ /X-Sun-Data-Name:\s*(\S+)/) {
			$attach->{'filename'} = $1;
			}
		if ($headers =~ /X-Sun-Data-Type:\s*(\S+)/) {
			local $st = $1;
			$attach->{'type'} = $st eq "text" ? "text/plain" :
					    $st eq "html" ? "text/html" :
					    $st =~ /\// ? $st : "application/octet-stream";
			}
		elsif ($attach->{'filename'}) {
			$attach->{'type'} =
				&guess_mime_type($attach->{'filename'});
			}
		else {
			$attach->{'type'} = "text/plain";	# fallback
			}
		push(@{$_[0]->{'attach'}}, $attach);
		}
	}
else {
	# One big attachment (probably text)
	local ($type, $body);
	($type = $ct) =~ s/;.*$//;
	$type = 'text/plain' if (!$type);
	if (lc($_[0]->{'header'}->{'content-transfer-encoding'}) eq 'base64') {
		$body = &decode_base64($_[0]->{'body'});
		}
	elsif (lc($_[0]->{'header'}->{'content-transfer-encoding'}) eq 
	       'quoted-printable') {
		$body = &quoted_decode($_[0]->{'body'});
		}
	else {
		$body = $_[0]->{'body'};
		}
	if ($body =~ /\S/) {
		$_[0]->{'attach'} = [ { 'type' => lc($type),
					'idx' => 0,
					'parent' => $_[1],
					'data' => $body } ];
		}
	else {
		# Body is completely empty
		$_[0]->{'attach'} = [ ];
		}
	}
delete($_[0]->{'body'}) if (!$_[2]);
}

# delete_mail(user|file, &mail, ...)
# Delete mail messages from a user by copying the file and rebuilding the index
sub delete_mail
{
# Validate messages
local @m = sort { $a->{'line'} <=> $b->{'line'} } @_[1..@_-1];
foreach my $m (@m) {
	defined($m->{'line'}) && defined($m->{'eline'}) &&
	  $m->{'eline'} > $m->{'line'} ||
	    &error("Message to delete is invalid, perhaps to due to ".
		   "out-of-date index");
	}

local $i = 0;
local $f = &user_mail_file($_[0]);
local $ifile = &user_index_file($_[0]);
local $lnum = 0;
local (%dline, @fline);
local ($dpos = 0, $dlnum = 0);
local (@index, %index);
&build_dbm_index($_[0], \%index);

local $tmpf = $< == 0 ? "$f.del" :
	      $_[0] =~ /^\/.*\/([^\/]+)$/ ?
	   	"$user_module_config_directory/$1.del" :
	      "$user_module_config_directory/$_[0].del";
if (-l $f) {
	$f = &resolve_links($f);
	}
&open_as_mail_user(SOURCE, $f) || &error("Failed to open $f : $!");
&create_as_mail_user(DEST, ">$tmpf") ||
	&error("Failed to open temp file $tmpf : $!");
while(<SOURCE>) {
	if ($i >= @m || $lnum < $m[$i]->{'line'}) {
		# Within a range that we want to preserve
		$dpos += length($_);
		$dlnum++;
		local $w = (print DEST $_);
		if (!$w) {
			local $e = "$!";
			close(DEST);
			close(SOURCE);
			unlink($tmpf);
			&error("Write to $tmpf failed : $e");
			}
		}
	elsif (!$fline[$i]) {
		# Start line of a message to delete
		if (!/^From\s/) {
			# Not actually a message! Fail now
			close(DEST);
			close(SOURCE);
			unlink($tmpf);
			&error("Index on $f is corrupt - did not find expected message start at line $lnum");
			}
		$fline[$i] = 1;
		}
	elsif ($lnum == $m[$i]->{'eline'}) {
		# End line of the current message to delete
		$dline{$m[$i]->{'line'}}++;
		$i++;
		}
	$lnum++;
	}
close(SOURCE);
close(DEST) || &error("Write to $tmpf failed : $?");
local @st = stat($f);

# Force a total index re-build (XXX lazy!)
$index{'mailcount'} = $in{'lastchange'} = 0;
dbmclose(%index);

if ($< == 0) {
	# Replace the mail file with the copy
	unlink($f);
	rename($tmpf, $f);
	if (!&should_switch_to_mail_user()) {
		# Since write was done as root, set back permissions on the
		# mail file to match the original
		chown($st[4], $st[5], $f);
		chmod($st[2], $f);
		}
	else {
		&chmod_as_mail_user($st[2], $f);
		}
	}
else {
	system("cat ".quotemeta($tmpf)." > ".quotemeta($f).
	       " && rm -f ".quotemeta($tmpf));
	}
}

# modify_mail(user|file, old, new, textonly)
# Modify one email message in a mailbox by copying the file and rebuilding
# the index.
sub modify_mail
{
local $f = &user_mail_file($_[0]);
local $ifile = &user_index_file($_[0]);
local $lnum = 0;
local ($sizediff, $linesdiff);
local %index;
&build_dbm_index($_[0], \%index);

# Replace the email that gets modified
local $tmpf = $< == 0 ? "$f.del" :
	      $_[0] =~ /^\/.*\/([^\/]+)$/ ?
		"$user_module_config_directory/$1.del" :
	      "$user_module_config_directory/$_[0].del";
if (-l $f) {
	$f = &resolve_links($f);
	}
&open_as_mail_user(SOURCE, $f) || &error("Failed to open $f : $!");
&create_as_mail_user(DEST, ">$tmpf") ||
	&error("Failed to open temp file $tmpf : $!");
while(<SOURCE>) {
	if ($lnum < $_[1]->{'line'} || $lnum > $_[1]->{'eline'}) {
		# before or after the message to change
		local $w = (print DEST $_);
		if (!$w) {
			local $e = "$?";
			close(DEST);
			close(SOURCE);
			unlink($tmpf);
			&error("Write to $tmpf failed : $e");
			}
		}
	elsif ($lnum == $_[1]->{'line'}) {
		# found start of message to change .. put in the new one
		close(DEST);
		local @ost = stat($tmpf);
		local $nlines = &send_mail($_[2], $tmpf, $_[3], 1);
		local @nst = stat($tmpf);
		local $newsize = $nst[7] - $ost[7];
		$sizediff = $newsize - $_[1]->{'size'};
		$linesdiff = $nlines - ($_[1]->{'eline'} - $_[1]->{'line'} + 1);
		&open_as_mail_user(DEST, ">>$tmpf");
		}
	$lnum++;
	}
close(SOURCE);
close(DEST) || &error("Write failed : $!");

# Now update the index and delete the temp file
for($i=0; $i<$index{'mailcount'}; $i++) {
	local @idx = split(/\0/, $index{$i});
	if ($idx[1] > $_[1]->{'line'}) {
		$idx[0] += $sizediff;
		$idx[1] += $linesdiff;
		$index{$i} = join("\0", @idx);
		}
	}
$index{'lastchange'} = time();
local @st = stat($f);
if ($< == 0) {
	unlink($f);
	rename($tmpf, $f);
	if (!&should_switch_to_mail_user()) {
		# Since write was done as root, set back permissions on the
		# mail file to match the original
		chown($st[4], $st[5], $f);
		chmod($st[2], $f);
		}
	else {
		&chmod_as_mail_user($st[2], $f);
		}
	}
else {
	system("cat $tmpf >$f && rm -f $tmpf");
	}
chown($st[4], $st[5], $f);
chmod($st[2], $f);
}

# send_mail(&mail, [file], [textonly], [nocr], [smtp-server],
#	    [smtp-user], [smtp-pass], [smtp-auth-mode],
#	    [&notify-flags], [port], [use-ssl])
# Send out some email message or append it to a file.
# Returns the number of lines written.
sub send_mail
{
local ($mail, $file, $textonly, $nocr, $sm, $user, $pass, $auth,
       $flags, $port, $ssl) = @_;
return 0 if (&is_readonly_mode());
local $lnum = 0;
$sm ||= $config{'send_mode'};
local $eol = $nocr || !$sm ? "\n" : "\r\n";
$ssl = $config{'smtp_ssl'} if ($ssl eq '');
local $defport = $ssl ? 465 : 25;
$port ||= $config{'smtp_port'} || $defport;
my %header;
foreach my $head (@{$mail->{'headers'}}) {
	$header{lc($head->[0])} = $head->[1];
	}

# Add the date header, always in english
&clear_time_locale();
local @tm = localtime(time());
push(@{$mail->{'headers'}},
     [ 'Date', strftime("%a, %d %b %Y %H:%M:%S %z (%Z)", @tm) ])
	if (!$header{'date'});
&reset_time_locale();

# Build list of destination email addresses
my @dests;
foreach my $f ("to", "cc", "bcc") {
	if ($header{$f}) {
		push(@dests, &address_parts($header{$f}));
		}
	}
my $qdests = join(" ", map { quotemeta($_) } @dests);

local @from = &address_parts($header{'from'});
local $fromaddr;
if (@from && $from[0] =~ /\S/) {
	$fromaddr = $from[0];
	}
else {
	local @uinfo = getpwuid($<);
	$fromaddr = $uinfo[0] || "nobody";
	$fromaddr .= '@'.&get_system_hostname();
	}
local $qfromaddr = quotemeta($fromaddr);
local $esmtp = $flags ? 1 : 0;
my $h = { 'fh' => 'mailboxes::MAIL' };
if ($file) {
	# Just append the email to a file using mbox format
	&open_as_mail_user($h->{'fh'}, ">>$file") ||
		&error("Write failed : $!");
	$lnum++;
	&write_http_connection($h,
		$mail->{'fromline'} ? $mail->{'fromline'}.$eol :
				      &make_from_line($fromaddr).$eol);
	}
elsif ($sm) {
	# Connect to SMTP server
	&open_socket($sm, $port, $h->{'fh'});
	if ($ssl) {
		# Switch to SSL mode
		eval "use Net::SSLeay";
		$@ && &error($text{'link_essl'});
		eval "Net::SSLeay::SSLeay_add_ssl_algorithms()";
		eval "Net::SSLeay::load_error_strings()";
		$h->{'ssl_ctx'} = Net::SSLeay::CTX_new() ||
			&error("Failed to create SSL context");
		$h->{'ssl_con'} = Net::SSLeay::new($h->{'ssl_ctx'}) ||
			&error("Failed to create SSL connection");
		Net::SSLeay::set_fd($h->{'ssl_con'}, fileno($h->{'fh'}));
		Net::SSLeay::connect($h->{'ssl_con'}) ||
			&error("SSL connect() failed");
		}

	&smtp_command($h, undef, 0);
	my $helo = $config{'helo_name'} || &get_system_hostname();
	if ($esmtp) {
		&smtp_command($h, "ehlo $helo\r\n", 0);
		}
	else {
		&smtp_command($h, "helo $helo\r\n", 0);
		}

	# Get username and password from parameters, or from module config
	$user ||= $userconfig{'smtp_user'} || $config{'smtp_user'};
	$pass ||= $userconfig{'smtp_pass'} || $config{'smtp_pass'};
	$auth ||= $userconfig{'smtp_auth'} ||
		  $config{'smtp_auth'} || "Cram-MD5";
	if ($user) {
		# Send authentication commands
		eval "use Authen::SASL";
		if ($@) {
			&error("Perl module <tt>Authen::SASL</tt> is needed for SMTP authentication");
			}
		my $sasl = Authen::SASL->new('mechanism' => uc($auth),
					     'callback' => {
						'auth' => $user,
						'user' => $user,
						'pass' => $pass } );
		&error("Failed to create Authen::SASL object") if (!$sasl);
		local $conn = $sasl->client_new("smtp", &get_system_hostname());
		local $arv = &smtp_command($h, "auth $auth\r\n", 1);
		if ($arv =~ /^(334)\s+(.*)/) {
			# Server says to go ahead
			$extra = $2;
			local $initial = $conn->client_start();
			local $auth_ok;
			if ($initial) {
				local $enc = &encode_base64($initial);
				$enc =~ s/\r|\n//g;
				$arv = &smtp_command($h, "$enc\r\n", 1);
				if ($arv =~ /^(\d+)\s+(.*)/) {
					if ($1 == 235) {
						$auth_ok = 1;
						}
					else {
						&error("Unknown SMTP authentication response : $arv");
						}
					}
				$extra = $2;
				}
			while(!$auth_ok) {
				local $message = &decode_base64($extra);
				local $return = $conn->client_step($message);
				local $enc = &encode_base64($return);
				$enc =~ s/\r|\n//g;
				$arv = &smtp_command($h, "$enc\r\n", 1);
				if ($arv =~ /^(\d+)\s+(.*)/) {
					if ($1 == 235) {
						$auth_ok = 1;
						}
					elsif ($1 == 535) {
						&error("SMTP authentication failed : $arv");
						}
					$extra = $2;
					}
				else {
					&error("Unknown SMTP authentication response : $arv");
					}
				}
			}
		}

	&smtp_command($h, "mail from: <$fromaddr>\r\n", 0);
	local $notify = $flags ? " NOTIFY=".join(",", @$flags) : "";
	foreach my $u (@dests) {
		&smtp_command($h, "rcpt to: <$u>$notify\r\n", 0);
		}
	&smtp_command($h, "data\r\n", 0);
	}
elsif (defined(&send_mail_program)) {
	# Use specified mail injector
	local $cmd = &send_mail_program($fromaddr, \@dests);
	$cmd || &error("No mail program was found on your system!");
	open($h->{'fh'}, "| $cmd >/dev/null 2>&1");
	}
elsif ($config{'qmail_dir'}) {
	# Start qmail-inject
	open($h->{'fh'}, "| $config{'qmail_dir'}/bin/qmail-inject");
	}
elsif ($config{'postfix_control_command'}) {
	# Start postfix's sendmail wrapper
	local $cmd = -x "/usr/lib/sendmail" ? "/usr/lib/sendmail" :
			&has_command("sendmail");
	$cmd || &error($text{'send_ewrapper'});
	open($h->{'fh'}, "| $cmd -f$qfromaddr $qdests >/dev/null 2>&1");
	}
else {
	# Start sendmail
	&has_command($config{'sendmail_path'}) ||
	    &error(&text('send_epath', "<tt>$config{'sendmail_path'}</tt>"));
	open($h->{'fh'}, "| $config{'sendmail_path'} -f$qfromaddr $qdests >/dev/null 2>&1");
	}

local $ctype = "multipart/mixed";
local $msg_id;
foreach $head (@{$mail->{'headers'}}) {
	if (defined($mail->{'body'}) || $textonly) {
		&write_http_connection($h, $head->[0],": ",$head->[1],$eol);
		$lnum++;
		}
	else {
		if ($head->[0] !~ /^(MIME-Version|Content-Type)$/i) {
			&write_http_connection($h, $head->[0],": ",$head->[1],$eol);
			$lnum++;
			}
		elsif (lc($head->[0]) eq 'content-type') {
			$ctype = $head->[1];
			}
		}
	if (lc($head->[0]) eq 'message-id') {
		$msg_id++;
		}
	}
if (!$msg_id) {
	# Add a message-id header if missing
	$main::mailboxes_message_id_count++;
	&write_http_connection($h, "Message-Id: <",time().".".$$.".".
				   $main::mailboxes_message_id_count."\@".
				   &get_system_hostname(),">",$eol);
	}

# Work out first attachment content type
local ($ftype, $fenc);
if (@{$mail->{'attach'}} >= 1) {
	local $first = $mail->{'attach'}->[0];
	$ftype = "text/plain";
	foreach my $h (@{$first->{'headers'}}) {
		if (lc($h->[0]) eq "content-type") {
			$ftype = $h->[1];
			}
		if (lc($h->[0]) eq "content-transfer-encoding") {
			$fenc = $h->[1];
			}
		}
	}

if (defined($mail->{'body'})) {
	# Use original mail body
	&write_http_connection($h, $eol);
	$lnum++;
	$mail->{'body'} =~ s/\r//g;
	$mail->{'body'} =~ s/\n\.\n/\n\. \n/g;
	$mail->{'body'} =~ s/\n/$eol/g;
	$mail->{'body'} .= $eol if ($mail->{'body'} !~ /\n$/);
	&write_http_connection($h, $mail->{'body'}) || &error("Write failed : $!");
	$lnum += ($mail->{'body'} =~ tr/\n/\n/);
	}
elsif (!@{$mail->{'attach'}}) {
	# No content, so just send empty email
	&write_http_connection($h, "Content-Type: text/plain",$eol);
	&write_http_connection($h, $eol);
	$lnum += 2;
	}
elsif (!$textonly || $ftype !~ /text\/plain/i ||
       $fenc =~ /quoted-printable|base64/) {
	# Sending MIME-encoded email
	if ($ctype !~ /multipart\/report/i) {
		$ctype =~ s/;.*$//;
		}
	&write_http_connection($h, "MIME-Version: 1.0",$eol);
	local $bound = "bound".time();
	&write_http_connection($h, "Content-Type: $ctype; boundary=\"$bound\"",$eol);
	&write_http_connection($h, $eol);
	$lnum += 3;

	# Send attachments
	&write_http_connection($h, "This is a multi-part message in MIME format.",$eol);
	$lnum++;
	foreach $a (@{$mail->{'attach'}}) {
		&write_http_connection($h, $eol);
		&write_http_connection($h, "--",$bound,$eol);
		$lnum += 2;
		local $enc;
		foreach $head (@{$a->{'headers'}}) {
			&write_http_connection($h, $head->[0],": ",$head->[1],$eol);
			$enc = $head->[1]
				if (lc($head->[0]) eq 'content-transfer-encoding');
			$lnum++;
			}
		&write_http_connection($h, $eol);
		$lnum++;
		if (lc($enc) eq 'base64') {
			local $enc = &encode_base64($a->{'data'});
			$enc =~ s/\r//g;
			$enc =~ s/\n/$eol/g;
			&write_http_connection($h, $enc);
			$lnum += ($enc =~ tr/\n/\n/);
			}
		else {
			$a->{'data'} =~ s/\r//g;
			$a->{'data'} =~ s/\n\.\n/\n\. \n/g;
			$a->{'data'} =~ s/\n/$eol/g;
			&write_http_connection($h, $a->{'data'});
			$lnum += ($a->{'data'} =~ tr/\n/\n/);
			if ($a->{'data'} !~ /\n$/) {
				&write_http_connection($h, $eol);
				$lnum++;
				}
			}
		}
	&write_http_connection($h, $eol);
	&write_http_connection($h, "--",$bound,"--",$eol) ||
		&error("Write failed : $!");
	&write_http_connection($h, $eol);
	$lnum += 3;
	}
else {
	# Sending text-only mail from first attachment
	local $a = $mail->{'attach'}->[0];
	&write_http_connection($h, $eol);
	$lnum++;
	$a->{'data'} =~ s/\r//g;
	$a->{'data'} =~ s/\n/$eol/g;
	&write_http_connection($h, $a->{'data'}) || &error("Write failed : $!");
	$lnum += ($a->{'data'} =~ tr/\n/\n/);
	if ($a->{'data'} !~ /\n$/) {
		&write_http_connection($h, $eol);
		$lnum++;
		}
	}
if ($sm && !$file) {
	&smtp_command($h, ".$eol", 0);
	&smtp_command($h, "quit$eol", 0);
	}
if (!&close_http_connection($h)) {
	# Only bother to report an error on close if writing to a file
	if ($file) {
		&error("Write failed : $!");
		}
	}
return $lnum;
}

# unparse_mail(&attachments, eol, boundary)
# Convert an array of attachments into MIME format, and return them as an
# array of lines.
sub unparse_mail
{
local ($attach, $eol, $bound) = @_;
local @rv;
foreach my $a (@$attach) {
	push(@rv, $eol);
	push(@rv, "--".$bound.$eol);
	local $enc;
	foreach my $h (@{$a->{'headers'}}) {
		push(@rv, $h->[0].": ".$h->[1].$eol);
		$enc = $h->[1]
			if (lc($h->[0]) eq 'content-transfer-encoding');
		}
	push(@rv, $eol);
	if (lc($enc) eq 'base64') {
		local $enc = &encode_base64($a->{'data'});
		$enc =~ s/\r//g;
		foreach my $l (split(/\n/, $enc)) {
			push(@rv, $l.$eol);
			}
		}
	else {
		$a->{'data'} =~ s/\r//g;
		$a->{'data'} =~ s/\n\.\n/\n\. \n/g;
		foreach my $l (split(/\n/, $a->{'data'})) {
			push(@rv, $l.$eol);
			}
		}
	}
push(@rv, $eol);
push(@rv, "--".$bound."--".$eol);
push(@rv, $eol);
return @rv;
}

# mail_size(&mail, [textonly])
# Returns the size of an email message in bytes
sub mail_size
{
local ($mail, $textonly) = @_;
local $temp = &transname();
&send_mail($mail, $temp, $textonly);
local @st = stat($temp);
unlink($temp);
return $st[7];
}

# can_read_mail(user)
sub can_read_mail
{
return 1 if ($_[0] && $access{'sent'} eq $_[0]);
local @u = getpwnam($_[0]);
return 0 if (!@u);
return 0 if ($_[0] =~ /\.\./);
return 0 if ($access{'mmode'} == 0);
return 1 if ($access{'mmode'} == 1);
local $u;
if ($access{'mmode'} == 2) {
	foreach $u (split(/\s+/, $access{'musers'})) {
		return 1 if ($u eq $_[0]);
		}
	return 0;
	}
elsif ($access{'mmode'} == 4) {
	return 1 if ($_[0] eq $remote_user);
	}
elsif ($access{'mmode'} == 5) {
	return $u[3] eq $access{'musers'};
	}
elsif ($access{'mmode'} == 3) {
	foreach $u (split(/\s+/, $access{'musers'})) {
		return 0 if ($u eq $_[0]);
		}
	return 1;
	}
elsif ($access{'mmode'} == 6) {
	return ($_[0] =~ /^$access{'musers'}$/);
	}
elsif ($access{'mmode'} == 7) {
	return (!$access{'musers'} || $u[2] >= $access{'musers'}) &&
	       (!$access{'musers2'} || $u[2] <= $access{'musers2'});
	}
return 0;	# can't happen!
}

# from_hostname()
sub from_hostname
{
local ($d, $masq);
local $conf = &get_sendmailcf();
foreach $d (&find_type("D", $conf)) {
	if ($d->{'value'} =~ /^M\s*(\S*)/) { $masq = $1; }
	}
return $masq ? $masq : &get_system_hostname();
}

# mail_from_queue(qfile, [dfile|"auto"])
# Reads a message from the Sendmail mail queue
sub mail_from_queue
{
local $mail = { 'file' => $_[0] };
$mail->{'quar'} = $_[0] =~ /\/hf/;
$mail->{'lost'} = $_[0] =~ /\/Qf/;
if ($_[1] eq "auto") {
	$mail->{'dfile'} = $_[0];
	$mail->{'dfile'} =~ s/\/(qf|hf|Qf)/\/df/;
	}
elsif ($_[1]) {
	$mail->{'dfile'} = $_[1];
	}
$mail->{'lfile'} = $_[0];
$mail->{'lfile'} =~ s/\/(qf|hf|Qf)/\/xf/;
local $_;
local @headers;
open(QF, "<", $_[0]) || return undef;
while(<QF>) {
	s/\r|\n//g;
	if (/^M(.*)/) {
		$mail->{'status'} = $1;
		}
	elsif (/^H\?[^\?]*\?(\S+):\s+(.*)/ || /^H(\S+):\s+(.*)/) {
		push(@headers, [ $1, $2 ]);
		$mail->{'rawheaders'} .= "$1: $2\n";
		}
	elsif (/^\s+(.*)/) {
		$headers[$#headers]->[1] .= $1 unless($#headers < 0);
		$mail->{'rawheaders'} .= $_."\n";
		}
	}
close(QF);
$mail->{'headers'} = \@headers;
foreach $h (@headers) {
	$mail->{'header'}->{lc($h->[0])} = $h->[1];
	}

if ($mail->{'dfile'}) {
	# Read the mail body
	open(DF, "<", $mail->{'dfile'});
	while(<DF>) {
		$mail->{'body'} .= $_;
		}
	close(DF);
	}
local $datafile = $mail->{'dfile'};
if (!$datafile) {
	($datafile = $mail->{'file'}) =~ s/\/(qf|hf|Qf)/\/df/;
	}
local @st0 = stat($mail->{'file'});
local @st1 = stat($datafile);
$mail->{'size'} = $st0[7] + $st1[7];
return $mail;
}

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
local @rv;
local $w = $_[1];
foreach $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while($rest =~ /^(.{1,$w}\S*)\s*([\0-\377]*)$/) {
			push(@rv, $1);
			$rest = $2;
			}
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}

# smtp_command(&handle, command, no-error)
# Send a single SMTP command to some file handle, and read back the response
sub smtp_command
{
my ($h, $c, $noerr) = @_;
if ($c) {
	&write_http_connection($h, $c);
	}
my $r = &read_http_connection($h);
if ($r !~ /^[23]\d+/ && !$noerr) {
	&error(&text('send_esmtp', "<tt>".&html_escape($c)."</tt>",
				   "<tt>".&html_escape($r)."</tt>"));
	}
$r =~ s/\r|\n//g;
if ($r =~ /^(\d+)\-/) {
	# multi-line ESMTP response!
	while(1) {
		my $nr = &read_http_connection($h);
		$nr =~ s/\r|\n//g;
		if ($nr =~ /^(\d+)\-(.*)/) {
			$r .= "\n".$2;
			}
		elsif ($nr =~ /^(\d+)\s+(.*)/) {
			$r .= "\n".$2;
			last;
			}
		}
	}
return $r;
}

# address_parts(string)
# Returns the email addresses in a string
sub address_parts
{
local @rv = map { $_->[0] } &split_addresses($_[0]);
return wantarray ? @rv : $rv[0];
}

# link_urls(text, separate)
# Converts URLs into HTML links
sub link_urls
{
local $r = $_[0];
local $tar = $_[1] ? "target=_blank" : "";
$r =~ s/((http|ftp|https|mailto):[^><"'\s]+[^><"'\s\.\)])/<a href="$1" $tar>$1<\/a>/g;
return $r;
}

# link_urls_and_escape(text, separate)
# HTML escapes some text, as well as properly linking URLs in it
sub link_urls_and_escape
{
local $l = $_[0];
local $rv;
local $tar = $_[1] ? " target=_blank" : "";
while($l =~ /^(.*?)((http|ftp|https|mailto):[^><"'\s]+[^><"'\s\.\)])(.*)/) {
	local ($before, $url, $after) = ($1, $2, $4);
	$rv .= &eucconv_and_escape($before)."<a href='$url' $tar>".
	       &html_escape($url)."</a>";
	$l = $after;
	}
$rv .= &eucconv_and_escape($l);
return $rv;
}

# links_urls_new_target(html)
# Converts any links without targets to open in a new window
sub links_urls_new_target
{
local $l = $_[0];
local $rv;
while($l =~ s/^([\0-\377]*?)<\s*a\s+([^>]*href[^>]*)>//i) {
	local ($before, $a) = ($1, $2);
	if ($a !~ /target\s*=/i) {
		$a .= " target=_blank";
		}
	$rv .= $before."<a ".$a.">";
	}
$rv .= $l;
return $rv;
}

# uudecode(text)
sub uudecode
{
local @lines = split(/\n/, $_[0]);
local ($l, $data);
for($l=0; $lines[$l] !~ /begin\s+([0-7]+)\s/i; $l++) { }
while($lines[++$l]) {
	$data .= unpack("u", $lines[$l]);
	}
return $data;
}

# simplify_date(datestring, [format])
# Given a date from an email header, convert to the user's preferred format
sub simplify_date
{
local ($date, $fmt) = @_;
local $u = &parse_mail_date($date);
if ($u) {
	$fmt ||= $userconfig{'date_fmt'} || $config{'date_fmt'} || "dmy";
	local $strf = $fmt eq "dmy" ? "%d/%m/%Y" :
		      $fmt eq "mdy" ? "%m/%d/%Y" :
				      "%Y/%m/%d";
	return strftime("$strf %H:%M", localtime($u));
        }
elsif ($date =~ /^(\S+),\s+0*(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+)/) {
	return "$2/$3/$4 $5:$6";
	}
elsif ($date =~ /^0*(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+)/) {
	return "$1/$2/$3 $4:$5";
	}
return $date;
}

# simplify_from(from)
# Simplifies a From: address for display in the mail list. Only the first
# address is returned.
sub simplify_from
{
local $rv = &convert_header_for_display($_[0], 0, 1);
local @sp = &split_addresses($rv);
if (!@sp) {
	return $text{'mail_nonefrom'};
	}
else {
	local $first = &html_escape($sp[0]->[1] ? $sp[0]->[1] : $sp[0]->[2]);
	if (length($first) > 80) {
		return substr($first, 0, 80)." ..";
		}
	else {
		return $first.(@sp > 1 ? " , ..." : "");
		}
	}
}

# convert_header_for_display(string, [max-non-html-length], [no-escape])
# Given a string from an email header, perform all mime-decoding, charset
# changes and HTML escaping needed to render it in a browser
sub convert_header_for_display
{
local ($str, $max, $noescape) = @_;
local ($mw, $cs) = &decode_mimewords($str);
if (&get_charset() eq 'UTF-8' && &can_convert_to_utf8($mw, $cs)) {
	$mw = &convert_to_utf8($mw, $cs);
	}
local $rv = &eucconv($mw);
$rv = substr($rv, 0, $max)." .." if ($max && length($rv) > $max);
return $noescape ? $rv : &html_escape($rv);
}

# simplify_subject(subject)
# Simplifies and truncates a subject header for display in the mail list
sub simplify_subject
{
return &convert_header_for_display($_[0], 80);
}

# quoted_decode(text)
# Converts quoted-printable format to the original
sub quoted_decode
{
local $t = $_[0];
$t =~ s/[ \t]+?(\r?\n)/$1/g;
$t =~ s/=\r?\n//g;
$t =~ s/(^|[^\r])\n\Z/$1\r\n/;
$t =~ s/=([a-fA-F0-9]{2})/pack("c",hex($1))/ge;
return $t;
}

# quoted_encode(text)
# Encodes text to quoted-printable format
sub quoted_encode
{
local $t = $_[0];
$t =~ s/([=\177-\377])/sprintf("=%2.2X",ord($1))/ge;
return $t;
}

# decode_mimewords(string)
# Converts a string in MIME words format like
# =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= to actual 8-bit characters
sub decode_mimewords {
    my $encstr = shift;
    my %params = @_;
    my @tokens;
    $@ = '';           ### error-return

    ### Collapse boundaries between adjacent encoded words:
    $encstr =~ s{(\?\=)\r?\n[ \t](\=\?)}{$1$2}gs;
    pos($encstr) = 0;
    ### print STDOUT "ENC = [", $encstr, "]\n";

    ### Decode:
    my ($charset, $encoding, $enc, $dec);
    while (1) {
	last if (pos($encstr) >= length($encstr));
	my $pos = pos($encstr);               ### save it

	### Case 1: are we looking at "=?..?..?="?
	if ($encstr =~    m{\G             # from where we left off..
			    =\?([^?]*)     # "=?" + charset +
			     \?([bq])      #  "?" + encoding +
			     \?([^?]+)     #  "?" + data maybe with spcs +
			     \?=           #  "?="
			    }xgi) {
	    ($charset, $encoding, $enc) = ($1, lc($2), $3);
	    $dec = (($encoding eq 'q') ? _decode_Q($enc) : _decode_B($enc));
	    push @tokens, [$dec, $charset];
	    next;
	}

	### Case 2: are we looking at a bad "=?..." prefix? 
	### We need this to detect problems for case 3, which stops at "=?":
	pos($encstr) = $pos;               # reset the pointer.
	if ($encstr =~ m{\G=\?}xg) {
	    $@ .= qq|unterminated "=?..?..?=" in "$encstr" (pos $pos)\n|;
	    push @tokens, ['=?'];
	    next;
	}

	### Case 3: are we looking at ordinary text?
	pos($encstr) = $pos;               # reset the pointer.
	if ($encstr =~ m{\G                # from where we left off...
			 ([\x00-\xFF]*?    #   shortest possible string,
			  \n*)             #   followed by 0 or more NLs,
		         (?=(\Z|=\?))      # terminated by "=?" or EOS
			}xg) {
	    length($1) or die "MIME::Words: internal logic err: empty token\n";
	    push @tokens, [$1];
	    next;
	}

	### Case 4: bug!
	die "MIME::Words: unexpected case:\n($encstr) pos $pos\n\t".
	    "Please alert developer.\n";
    }
    if (wantarray) {
	return (join('',map {$_->[0]} @tokens), $charset);
    } else {
	return join('',map {$_->[0]} @tokens);
    }
}

# _decode_Q STRING
#     Private: used by _decode_header() to decode "Q" encoding, which is
#     almost, but not exactly, quoted-printable.  :-P
sub _decode_Q {
    my $str = shift;
    $str =~ s/_/\x20/g;                                # RFC-1522, Q rule 2
    $str =~ s/=([\da-fA-F]{2})/pack("C", hex($1))/ge;  # RFC-1522, Q rule 1
    $str;
}

# _decode_B STRING
#     Private: used by _decode_header() to decode "B" encoding.
sub _decode_B {
    my $str = shift;
    &decode_base64($str);
}

# encode_mimewords(string, %params)
# Converts a word with 8-bit characters to MIME words format
sub encode_mimewords
{
my ($rawstr, %params) = @_;
my $charset  = $params{Charset} || 'ISO-8859-1';
my $defenc = uc($charset) eq 'ISO-2022-JP' ? 'b' : 'q';
my $encoding = lc($params{Encoding} || $defenc);
my $NONPRINT = "\\x00-\\x1F\\x7F-\\xFF";

if ($rawstr =~ /^[\x20-\x7E]*$/) {
	# No encoding needed
	return $rawstr;
	}

### Encode any "words" with unsafe characters.
###    We limit such words to 18 characters, to guarantee that the
###    worst-case encoding give us no more than 54 + ~10 < 75 characters
my $word;
$rawstr =~ s{([ a-zA-Z0-9\x7F-\xFF]{1,18})}{     ### get next "word"
    $word = $1;
    $word =~ /(?:[$NONPRINT])|(?:^\s+$)/o ?
	encode_mimeword($word, $encoding, $charset) :	# unsafe chars
	$word						# OK word
}xeg;
$rawstr =~ s/\?==\?/?= =?/g;
return $rawstr;
}

# can_convert_to_utf8(string, string-charset)
# Check if the appropriate perl modules are available for UTF-8 conversion
sub can_convert_to_utf8
{
my ($str, $cs) = @_;
return 0 if ($cs eq "UTF-8");
return 0 if (!$cs);
eval "use Encode";
return 0 if ($@);
eval "use utf8";
return 0 if ($@);
return 1;
}

# convert_to_utf8(string, string-charset)
# If possible, convert a string to the UTF-8 charset
sub convert_to_utf8
{
my ($str, $cs) = @_;
&can_convert_to_utf8(@_);	# Load modules
eval {
	$str = Encode::decode($cs, $str);
	utf8::encode($str);
	};
return $str;
}

# encode_mimewords_address(string, %params)
# Given a string containing addresses into one with real names mime-words
# escaped
sub encode_mimewords_address
{
my ($rawstr, %params) = @_;
my $charset  = $params{Charset} || 'ISO-8859-1';
my $defenc = uc($charset) eq 'ISO-2022-JP' ? 'b' : 'q';
my $encoding = lc($params{Encoding} || $defenc);
if ($rawstr =~ /^[\x20-\x7E]*$/) {
	# No encoding needed
	return $rawstr;
	}
my @rv;
foreach my $addr (&split_addresses($rawstr)) {
	my ($email, $name, $orig) = @$addr;
	if ($name =~ /^[\x20-\x7E]*$/) {
		# No encoding needed
		push(@rv, $orig);
		}
	else {
		# Re-encode name
		my $ename = encode_mimeword($name, $encoding, $charset);
		push(@rv, $ename." <".$email.">");
		}
	}
return join(", ", @rv);
}

# encode_mimeword(string, [encoding], [charset])
# Converts a word with 8-bit characters to MIME words format
sub encode_mimeword
{
my $word = shift;
my $encoding = uc(shift || 'Q');
my $charset  = uc(shift || 'ISO-8859-1');
my $encfunc  = (($encoding eq 'Q') ? \&_encode_Q : \&_encode_B);
return "=?$charset?$encoding?" . &$encfunc($word) . "?=";
}

# _encode_Q STRING
#     Private: used by _encode_header() to decode "Q" encoding, which is
#     almost, but not exactly, quoted-printable.  :-P
sub _encode_Q {
    my $str = shift;
    my $NONPRINT = "\\x00-\\x1F\\x7F-\\xFF";
    $str =~ s{([ _\?\=$NONPRINT])}{sprintf("=%02X", ord($1))}eog;
    return $str;
}

# _encode_B STRING
#     Private: used by _decode_header() to decode "B" encoding.
sub _encode_B {
    my $str = shift;
    my $enc = &encode_base64($str);
    $enc =~ s/\n//;
    return $enc;
}

# user_mail_file(user|file, [other details])
sub user_mail_file
{
if ($_[0] =~ /^\//) {
	return $_[0];
	}
elsif ($config{'mail_dir'}) {
	return &mail_file_style($_[0], $config{'mail_dir'},
				$config{'mail_style'});
	}
elsif (@_ > 1) {
	return "$_[7]/$config{'mail_file'}";
	}
else {
	local @u = getpwnam($_[0]);
	return "$u[7]/$config{'mail_file'}";
	}
}

# mail_file_style(user, basedir, style)
# Given a directory and username, returns the path to that user's mail file
# under the directory based on the style (which may force use of parts of
# the username).
sub mail_file_style
{
if ($_[2] == 0) {
	return "$_[1]/$_[0]";
	}
elsif ($_[2] == 1) {
	return $_[1]."/".substr($_[0], 0, 1)."/".$_[0];
	}
elsif ($_[2] == 2) {
	return $_[1]."/".substr($_[0], 0, 1)."/".
		substr($_[0], 0, 2)."/".$_[0];
	}
else {
	return $_[1]."/".substr($_[0], 0, 1)."/".
		substr($_[0], 1, 1)."/".$_[0];
	}
}

# user_index_file(user|file)
sub user_index_file
{
local $us = $_[0];
$us =~ s/\//_/g;
local $f;
local $hn = &get_system_hostname();
if ($_[0] =~ /^\/.*\/([^\/]+)$/) {
	# A file .. the index file is in ~/.usermin/mailbox or
	# /etc/webmin/mailboxes
	if ($user_module_config_directory && $config{'shortindex'}) {
		# Use short name for index file
		$f = "$user_module_config_directory/$1.findex";
		}
	elsif ($user_module_config_directory) {
		# Under user's .usermin directory
		$f = "$user_module_config_directory/$us.findex";
		}
	else {
		# Under /var/webmin or /etc/webmin
		$f = "$module_config_directory/$us.findex";
		if (!glob($f."*")) {
			$f = "$module_var_directory/$us.findex";
			}
		}
	}
else {
	# A username .. the index file is in /var/webmin/modules/mailboxes or
	# /etc/webmin/mailboxes
	if ($user_module_config_directory) {
		$f = "$user_module_config_directory/$_[0].index";
		}
	else {
		$f = "$module_config_directory/$_[0].index";
		if (!glob($f."*")) {
			$f = "$module_var_directory/$_[0].index";
			}
		}
	}
# Append hostname if requested, unless an index file without the hostname
# already exists
return $config{'noindex_hostname'} ? $f :
       -r $f && !-r "$f.$hn" ? $f : "$f.$hn";
}

# extract_mail(data)
# Converts the text of a message into mail object.
sub extract_mail
{
local $text = $_[0];
$text =~ s/^\s+//;
local ($amail, @aheaders, $i);
local @alines = split(/\n/, $text);
while($i < @alines && $alines[$i]) {
	if ($alines[$i] =~ /^(\S+):\s*(.*)/) {
		push(@aheaders, [ $1, $2 ]);
		$amail->{'rawheaders'} .= $alines[$i]."\n";
		}
	elsif ($alines[$i] =~ /^\s+(.*)/) {
		$aheaders[$#aheaders]->[1] .= $1 unless($#aheaders < 0);
		$amail->{'rawheaders'} .= $alines[$i]."\n";
		}
	$i++;
	}
$amail->{'headers'} = \@aheaders;
foreach $h (@aheaders) {
	$amail->{'header'}->{lc($h->[0])} = $h->[1];
	}
splice(@alines, 0, $i);
$amail->{'body'} = join("\n", @alines)."\n";
return $amail;
}

# split_addresses(string)
# Splits a comma-separated list of addresses into [ email, real-name, original ]
# triplets
sub split_addresses
{
local (@rv, $str = $_[0]);
while(1) {
	$str =~ s/\\"/\0/g;
	if ($str =~ /^[\s,;]*(([^<>\(\)\s"]+)\s+\(([^\(\)]+)\))(.*)$/) {
		# An address like  foo@bar.com (Fooey Bar)
		push(@rv, [ $2, $3, $1 ]);
		$str = $4;
		}
	elsif ($str =~ /^[\s,;]*("([^"]+)"\s*<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,;]*(([^<>\@]+)\s+<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,;]*(([^<>\@]+)<([^\s<>,]+)>)(.*)$/ ||
	       $str =~ /^[\s,;]*(([^<>\[\]]+)\s+\[mailto:([^\s\[\]]+)\])(.*)$/||
	       $str =~ /^[\s,;]*(()<([^<>,]+)>)(.*)/ ||
	       $str =~ /^[\s,;]*(()([^\s<>,;]+))(.*)/) {
		# Addresses like  "Fooey Bar" <foo@bar.com>
		#                 Fooey Bar <foo@bar.com>
		#                 Fooey Bar<foo@bar.com>
		#		  Fooey Bar [mailto:foo@bar.com]
		#		  <foo@bar.com>
		#		  <group name>
		#		  foo@bar.com or foo
		my ($all, $name, $email, $rest) = ($1, $2, $3, $4);
		$all =~ s/\0/\\"/g;
		$name =~ s/\0/"/g;
		push(@rv, [ $email, $name eq "," ? "" : $name, $all ]);
		$str = $rest;
		}
	else {
		last;
		}
	}
return @rv;
}

$match_ascii = '\x1b\([BHJ]([\t\x20-\x7e]*)';
$match_jis = '\x1b\$[@B](([\x21-\x7e]{2})*)';

sub eucconv {
	local($_) = @_;
	if ($current_lang eq 'ja_JP.euc') {
		s/$match_jis/&j2e($1)/geo;
		s/$match_ascii/$1/go;
		}
	$_;
}

sub j2e {
	local($_) = @_;
	tr/\x21-\x7e/\xa1-\xfe/;
	$_;
}

# eucconv_and_escape(string)
# Convert a string for display
sub eucconv_and_escape {
	return &html_escape(&eucconv($_[0]));
}

# list_maildir(file, [start], [end], [headersonly])
# Returns a subset of mail from a maildir format directory
sub list_maildir
{
local (@rv, $i, $f);
&mark_read_maildir($_[0]);
local @files = &get_maildir_files($_[0]);

local ($start, $end);
if (!defined($_[1])) {
	$start = 0;
	$end = @files - 1;
	}
elsif ($_[2] < 0) {
	$start = @files + $_[2] - 1;
	$end = @files + $_[1] - 1;
	$start = 0 if ($start < 0);
	}
else {
	$start = $_[1];
	$end = $_[2];
	$end = @files-1 if ($end >= @files);
	}
foreach $f (@files) {
	if ($i < $start || $i > $end) {
		# Skip files outside requested index range
		push(@rv, undef);
		$i++;
		next;
		}
	local $mail = &read_mail_file($f, $_[3]);
	$mail->{'idx'} = $i++;
	$mail->{'id'} = $f;	# ID is relative path, like cur/4535534
	$mail->{'id'} = substr($mail->{'id'}, length($_[0])+1);
	push(@rv, $mail);
	}
return @rv;
}

# idlist_maildir(file)
# Returns a list of files in a maildir, which form the IDs
sub idlist_maildir
{
local ($file) = @_;
&mark_read_maildir($file);
return map { substr($_, length($file)+1) } &get_maildir_files($file);
}

# select_maildir(file, &ids, headersonly)
# Returns a list of messages with the given IDs, from a maildir directory
sub select_maildir
{
local ($file, $ids, $headersonly) = @_;
&mark_read_maildir($file);
local @files = &get_maildir_files($file);
local @rv;
foreach my $i (@$ids) {
	local $path = "$file/$i";
	local $mail = &read_mail_file($path, $headersonly);
	if (!$mail && $path =~ /^(.*)\/(cur|tmp|new)\/([^:]*)(:2,([A-Za-z]*))?$/) {
		# Flag may have changed - update path
		local $suffix = "$2/$3";
		local ($newfile) = grep
		  { substr($_, length($file)+1, length($suffix)) eq $suffix }
		  @files;
		if ($newfile) {
			$path = $newfile;
			$mail = &read_mail_file($path, $headersonly);
			}
		}
	if (!$mail && $path =~ /\/cur\//) {
		# May have moved - update path
		$path =~ s/\/cur\//\/new\//g;
		$mail = &read_mail_file($path, $headersonly);
		}
	if ($mail) {
		# Set ID from corrected path
		$mail->{'id'} = $path;
		$mail->{'id'} = substr($mail->{'id'}, length($file)+1);
		# Get index in directory
		$mail->{'idx'} = &indexof($path, @files);
		}
	push(@rv, $mail);
	}
return @rv;
}

# Get ordered list of message files (with in-memory and on-disk caching, as
# this can be slow)
# get_maildir_files(directory)
sub get_maildir_files
{
# Work out last modified time
local $newest;
foreach my $d ("$_[0]/cur", "$_[0]/new") {
	local @dst = stat($d);
	$newest = $dst[9] if ($dst[9] > $newest);
	}
local $skipt = $config{'maildir_deleted'} || $userconfig{'maildir_deleted'};

local @files;
if (defined($main::list_maildir_cache{$_[0]}) &&
    $main::list_maildir_cache_time{$_[0]} == $newest) {
	# Use the in-memory cache cache
	@files = @{$main::list_maildir_cache{$_[0]}};
	}
else {
	# Check the on-disk cache file
	local $cachefile = &get_maildir_cachefile($_[0]);
	local @cst = $cachefile ? stat($cachefile) : ( );
	if ($cst[9] >= $newest) {
		# Can read the cache
		open(CACHE, "<", $cachefile);
		while(<CACHE>) {
			chop;
			push(@files, $_[0]."/".$_);
			}
		close(CACHE);
		$main::list_maildir_cache_time{$_[0]} = $cst[9];
		}
	else {
		# Really read
		local @shorts;
		foreach my $d ("cur", "new") {
			&opendir_as_mail_user(DIR, "$_[0]/$d") || &error("Failed to open $_[0]/$d : $!");
			while(my $f = readdir(DIR)) {
				next if ($f eq "." || $f eq "..");
				if ($skipt && $f =~ /:2,([A-Za-z]*T[A-Za-z]*)$/) {
					# Flagged as deleted by IMAP .. skip
					next;
					}
				push(@shorts, "$d/$f")
				}
			closedir(DIR);
			}
		@shorts = sort { substr($a, 4) cmp substr($b, 4) } @shorts;
		@files = map { "$_[0]/$_" } @shorts;

		# Write out the on-disk cache
		if ($cachefile) {
			&open_tempfile(CACHE, ">$cachefile", 1);
			my $err;
			foreach my $f (@shorts) {
				my $ok = (print CACHE $f,"\n");
				$err++ if (!$ok);
				}
			&close_tempfile(CACHE) if (!$err);
			local @st = stat($_[0]);
			if ($< == 0) {
				# Cache should have some ownership as directory
				&set_ownership_permissions($st[4], $st[5],
							   undef, $cachefile);
				}
			}
		$main::list_maildir_cache_time{$_[0]} = $st[9];
		}
	$main::list_maildir_cache{$_[0]} = \@files;
	}
return @files;
}

# search_maildir(file, field, what)
# Search for messages in a maildir directory, and return the results
sub search_maildir
{
return &advanced_search_maildir($_[0], [ [ $_[1], $_[2] ] ], 1);
}

# advanced_search_maildir(user|file, &fields, andmode, [&limit], [headersonly])
# Search for messages in a maildir directory, and return the results
sub advanced_search_maildir
{
&mark_read_maildir($_[0]);
local @rv;
local ($min, $max);
if ($_[3] && $_[3]->{'latest'}) {
	$min = -1;
	$max = -$_[3]->{'latest'};
	}
local $headersonly = $_[4] && !&matches_needs_body($_[1]);
foreach $mail (&list_maildir($_[0], $min, $max, $headersonly)) {
	push(@rv, $mail) if ($mail &&
			     &mail_matches($_[1], $_[2], $mail));
	}
return @rv;
}

# mark_read_maildir(dir)
# Move any messages in the 'new' directory of this maildir to 'cur'
sub mark_read_maildir
{
local ($dir) = @_;
local @files = &get_maildir_files($dir);
local $i = 0;
foreach my $nf (@files) {
	if (substr($nf, length($dir)+1, 3) eq "new") {
		local $cf = $nf;
		$cf =~ s/\/new\//\/cur\//g;
		if (&rename_as_mail_user($nf, $cf)) {
			$files[$i] = $cf;
			$changed = 1;
			}
		}
	$i++;
	}
if ($changed) {
	# Update the cache
	$main::list_maildir_cache{$dir} = \@files;
	local $cachefile = &get_maildir_cachefile($dir);
	if ($cachefile) {
		&open_tempfile(CACHE, ">$cachefile", 1);
		foreach my $f (@files) {
			local $short = substr($f, length($dir)+1);
			&print_tempfile(CACHE, $short,"\n");
			}
		&close_tempfile(CACHE);
		local @st = stat($_[0]);
		if ($< == 0) {
			&set_ownership_permissions($st[4], $st[5],
						   undef, $cachefile);
			}
		}
	}
}

# delete_maildir(&mail, ...)
# Delete messages from a maildir directory
sub delete_maildir
{
local $m;

# Find all maildirs being deleted from
local %dirs;
foreach $m (@_) {
	if ($m->{'file'} =~ /^(.*)\/(cur|new)\/([^\/]+)$/) {
		$dirs{$1}->{"$2/$3"} = 1;
		}
	}

# Delete from caches
foreach my $dir (keys %dirs) {
	local $cachefile = &get_maildir_cachefile($dir);
	next if (!$cachefile);
	local @cst = stat($cachefile);
	next if (!@cst);

	# Work out last modified time, and don't update cache if too new
	local $newest;
	foreach my $d ("$dir/cur", "$dir/new") {
		local @dst = stat($d);
		$newest = $dst[9] if ($dst[9] > $newest);
		}
	next if ($newest > $cst[9]);

	local $lref = &read_file_lines($cachefile);
	for(my $i=0; $i<@$lref; $i++) {
		if ($dirs{$dir}->{$lref->[$i]}) {
			# Found an entry to remove
			splice(@$lref, $i--, 1);
			}
		}
	&flush_file_lines($cachefile);
	}

# Actually delete the files
foreach $m (@_) {
	unlink($m->{'file'});
	}

}

# modify_maildir(&oldmail, &newmail, textonly)
# Replaces a message in a maildir directory
sub modify_maildir
{
unlink($_[0]->{'file'});
&send_mail($_[1], $_[0]->{'file'}, $_[2], 1);
}

# write_maildir(&mail, directory, textonly)
# Adds some message in maildir format to a directory
sub write_maildir
{
my ($mail, $dir, $textonly) = @_;

# Work out last modified time, and don't update cache if too new
local $cachefile = &get_maildir_cachefile($dir);
local $up2date = 0;
if ($cachefile) {
	local @cst = stat($cachefile);
	if (@cst) {
		local $newest;
		foreach my $d ("$dir/cur", "$dir/new") {
			local @dst = stat($d);
			$newest = $dst[9] if ($dst[9] > $newest);
			}
		$up2date = 1 if ($newest <= $cst[9]);
		}
	}

# Select a unique filename and write to it
local $now = time();
$mail->{'id'} = &unique_maildir_filename($dir);
$mf = "$dir/$mail->{'id'}";
&send_mail($mail, $mf, $textonly, 1);
$mail->{'file'} = $mf;

# Set ownership of the new message file to match the directory
local @st = stat($dir);
if ($< == 0) {
	&set_ownership_permissions($st[4], $st[5], undef, $mf);
	}

# Create tmp and new sub-dirs, if missing
foreach my $sd ("tmp", "new") {
	local $sdpath = "$dir/$sd";
	if (!-d $sdpath) {
		mkdir($sdpath, 0755);
		if ($< == 0) {
			&set_ownership_permissions($st[4], $st[5],
						   undef, $sdpath);
			}
		}
	}

if ($up2date && $cachefile) {
	# Bring cache up to date
	$now--;
	local $lref = &read_file_lines($cachefile);
	push(@$lref, $mail->{'id'});
	&flush_file_lines($cachefile);
	}
}

# unique_maildir_filename(dir)
# Returns a filename for a new message in a maildir, relative to the directory
sub unique_maildir_filename
{
local ($dir) = @_;
mkdir("$dir/cur", 0755);
local $now = time();
local $hn = &get_system_hostname();
++$main::write_maildir_count;
local $rv;
do {
	$rv = "cur/$now.$$.$main::write_maildir_count.$hn";
	$now++;
	} while(-r "$dir/$rv");
return $rv;
}

# empty_maildir(file)
# Delete all messages in an maildir directory
sub empty_maildir
{
local $d;
foreach $d ("$_[0]/cur", "$_[0]/new") {
	local $f;
	&opendir_as_mail_user(DIR, $d) || &error("Failed to open $d : $!");
	while($f = readdir(DIR)) {
		unlink("$d/$f") if ($f ne '.' && $f ne '..');
		}
	closedir(DIR);
	}
&flush_maildir_cachefile($_[0]);
}

# get_maildir_cachefile(dir)
# Returns the cache file for a maildir directory
sub get_maildir_cachefile
{
local ($dir) = @_;
local $cd;
if ($user_module_config_directory) {
	$cd = $user_module_config_directory;
	}
else {
	$cd = $module_config_directory;
	if (!-r "$cd/maildircache") {
		$cd = $module_var_directory;
		}
	}
local $sd = "$cd/maildircache";
if (!-d $sd) {
	&make_dir($sd, 0755) || return undef;
	}
$dir =~ s/\//_/g;
return "$sd/$dir";
}

# flush_maildir_cachefile(dir)
# Clear the on-disk and in-memory maildir caches
sub flush_maildir_cachefile
{
local ($dir) = @_;
local $cachefile = &get_maildir_cachefile($dir);
unlink($cachefile) if ($cachefile);
delete($main::list_maildir_cache{$dir});
delete($main::list_maildir_cache_time{$dir});
}

# count_maildir(dir)
# Returns the number of messages in a maildir directory
sub count_maildir
{
local @files = &get_maildir_files($_[0]);
return scalar(@files);
}

# list_mhdir(file, [start], [end], [headersonly])
# Returns a subset of mail from an MH format directory
sub list_mhdir
{
local ($start, $end, $f, $i, @rv);
&opendir_as_mail_user(DIR, $_[0]) || &error("Failed to open $_[0] : $!");
local @files = map { "$_[0]/$_" }
		sort { $a <=> $b }
		 grep { /^\d+$/ } readdir(DIR);
closedir(DIR);
if (!defined($_[1])) {
	$start = 0;
	$end = @files - 1;
	}
elsif ($_[2] < 0) {
	$start = @files + $_[2] - 1;
	$end = @files + $_[1] - 1;
	$start = 0 if ($start < 0);
	}
else {
	$start = $_[1];
	$end = $_[2];
	$end = @files-1 if ($end >= @files);
	}
foreach $f (@files) {
	if ($i < $start || $i > $end) {
		# Skip files outside requested index range
		push(@rv, undef);
		$i++;
		next;
		}
	local $mail = &read_mail_file($f, $_[3]);
	$mail->{'idx'} = $i++;
	$mail->{'id'} = $f;	# ID is message number
	$mail->{'id'} = substr($mail->{'id'}, length($_[0])+1);
	push(@rv, $mail);
	}
return @rv;
}

# idlist_mhdir(directory)
# Returns a list of files in an MH directory, which are the IDs
sub idlist_mhdir
{
local ($dir) = @_;
&opendir_as_mail_user(DIR, $dir) || &error("Failed to open $dir : $!");
local @files = grep { /^\d+$/ } readdir(DIR);
closedir(DIR);
return @files;
}

# get_mhdir_files(directory)
# Returns a list of full paths to files in an MH directory
sub get_mhdir_files
{
local ($dir) = @_;
return map { "$dir/$_" } &idlist_mhdir($dir);
}

# select_mhdir(file, &ids, headersonly)
# Returns a list of messages with the given indexes, from an mhdir directory
sub select_mhdir
{
local ($file, $ids, $headersonly) = @_;
local @rv;
&opendir_as_mail_user(DIR, $file) || &error("Failed to open $file : $!");
local @files = map { "$file/$_" }
		sort { $a <=> $b }
		 grep { /^\d+$/ } readdir(DIR);
closedir(DIR);
foreach my $i (@$ids) {
	local $mail = &read_mail_file("$file/$i", $headersonly);
	if ($mail) {
		$mail->{'idx'} = &indexof("$file/$i", @files);
		$mail->{'id'} = $i;
		}
	push(@rv, $mail);
	}
return @rv;
}

# search_mhdir(file|user, field, what)
# Search for messages in an MH directory, and return the results
sub search_mhdir
{
return &advanced_search_mhdir($_[0], [ [ $_[1], $_[2] ] ], 1);
}

# advanced_search_mhdir(file|user, &fields, andmode, &limit, [headersonly])
# Search for messages in an MH directory, and return the results
sub advanced_search_mhdir
{
local @rv;
local ($min, $max);
if ($_[3] && $_[3]->{'latest'}) {
	$min = -1;
	$max = -$_[3]->{'latest'};
	}
local $headersonly = $_[4] && !&matches_needs_body($_[1]);
foreach $mail (&list_mhdir($_[0], $min, $max, $headersonly)) {
	push(@rv, $mail) if ($mail && &mail_matches($_[1], $_[2], $mail));
	}
return @rv;
}

# delete_mhdir(&mail, ...)
# Delete messages from an MH directory
sub delete_mhdir
{
local $m;
foreach $m (@_) {
	unlink($m->{'file'});
	}
}

# modify_mhdir(&oldmail, &newmail, textonly)
# Replaces a message in a maildir directory
sub modify_mhdir
{
unlink($_[0]->{'file'});
&send_mail($_[1], $_[0]->{'file'}, $_[2], 1);
}

# max_mhdir(dir)
# Returns the maximum message ID in the directory
sub max_mhdir
{
local $max = 1;
&opendir_as_mail_user(DIR, $_[0]) || &error("Failed to open $_[0] : $!");
foreach my $f (readdir(DIR)) {
	$max = $f if ($f =~ /^\d+$/ && $f > $max);
	}
closedir(DIR);
return $max;
}

# empty_mhdir(file)
# Delete all messages in an MH format directory
sub empty_mhdir
{
&opendir_as_mail_user(DIR, $_[0]) || &error("Failed to open $_[0] : $!");
foreach my $f (readdir(DIR)) {
	unlink("$_[0]/$f") if ($f =~ /^\d+$/);
	}
closedir(DIR);
}

# count_mhdir(file)
# Returns the number of messages in an MH directory
sub count_mhdir
{
&opendir_as_mail_user(DIR, $_[0]) || &error("Failed to open $_[0] : $!");
local @files = grep { /^\d+$/ } readdir(DIR);
closedir(DIR);
return scalar(@files);
}

# list_mbxfile(file, start, end)
# Return messages from an MBX format file
sub list_mbxfile
{
local @rv;
&open_as_mail_user(MBX, $_[0]) || &error("Failed to open $_[0] : $!");
seek(MBX, 2048, 0);
while(my $line = <MBX>) {
	if ($line =~ m/( \d|\d\d)-(\w\w\w)-(\d\d\d\d) (\d\d):(\d\d):(\d\d) ([+-])(\d\d)(\d\d),(\d+);([[:xdigit:]]{8})([[:xdigit:]]{4})-([[:xdigit:]]{8})\r\n$/) {
		my $size = $10;
		my $mail = &read_mail_fh(MBX, $size, 0);
		push(@rv, $mail);
		}
	}
close(MBX);
return @rv;
}

# select_mbxfile(file, &ids, headersonly)
# Returns a list of messages with the given indexes, from a MBX file
sub select_mbxfile
{
local ($file, $ids, $headersonly) = @_;
local @all = &list_mbxfile($file);
local @rv;
foreach my $i (@$ids) {
	push(@rv, $all[$i]);
	}
return @rv;
}

# read_mail_file(file, [headersonly])
# Read a single message from a file
sub read_mail_file
{
local (@headers, $mail);

# Open and read the mail file
&open_as_mail_user(MAIL, $_[0]) || return undef;
$mail = &read_mail_fh(MAIL, 0, $_[1]);
$mail->{'file'} = $_[0];
close(MAIL);
local @st = stat($_[0]);
$mail->{'size'} = $st[7];
$mail->{'time'} = $st[9];

# Set read flags based on the name
if ($_[0] =~ /:2,([A-Za-z]*)$/) {
	local @flags = split(//, $1);
	$mail->{'read'} = &indexoflc("S", @flags) >= 0 ? 1 : 0;
	$mail->{'special'} = &indexoflc("F", @flags) >= 0 ? 1 : 0;
	$mail->{'replied'} = &indexoflc("R", @flags) >= 0 ? 1 : 0;
	$mail->{'flags'} = 1;
	}

return $mail;
}

# read_mail_fh(handle, [end-mode], [headersonly])
# Reads an email message from the given file handle, either up to end of
# the file, or a From line. End mode 0 = EOF, 1 = From without -,
#				     2 = From possibly with -,
#				     higher = number of bytes
sub read_mail_fh
{
local ($fh, $endmode, $headeronly) = @_;
local (@headers, $mail);

# Read the headers
local $lnum = 0;
while(1) {
	$lnum++;
	local $line = <$fh>;
	$mail->{'size'} += length($line);
	$line =~ s/\r|\n//g;
	last if ($line eq '');
	if ($line =~ /^(\S+):\s*(.*)/) {
		push(@headers, [ $1, $2 ]);
		$mail->{'rawheaders'} .= $line."\n";
		}
	elsif ($line =~ /^\s+(.*)/) {
		$headers[$#headers]->[1] .= " ".$1 unless($#headers < 0);
		$mail->{'rawheaders'} .= $line."\n";
		}
	elsif ($line =~ /^From\s+(\S+).*\d+/ &&
	       ($1 ne '-' || $endmode == 2)) {
		$mail->{'fromline'} = $line;
		}
	}
$mail->{'headers'} = \@headers;
foreach $h (@headers) {
	$mail->{'header'}->{lc($h->[0])} = $h->[1];
	}

if (!$headersonly) {
	# Read the mail body
	if ($endmode == 0) {
		# Till EOF
		while(read($fh, $buf, 1024) > 0) {
			$mail->{'size'} += length($buf);
			$mail->{'body'} .= $buf;
			$lc = ($buf =~ tr/\n/\n/);
			$lnum += $lc;
			}
		close(MAIL);
		}
	elsif ($endmode > 2) {
		# Till we have enough bytes
		while($mail->{'size'} < $endmode) {
			$line = <$fh>;
			$lnum++;
			$mail->{'size'} += length($line);
			$mail->{'body'} .= $line;
			}
		}
	else {
		# Till next From line
		while(1) {
			$line = <$fh>;
			last if (!$line || $line =~ /^From\s+(\S+).*\d+\r?\n/ &&
				 ($1 ne '-' || $endmode == 2));
			$lnum++;
			$mail->{'size'} += length($line);
			$mail->{'body'} .= $line;
			}
		}
	$mail->{'lines'} = $lnum;
	}
elsif ($endmode) {
	# Not reading the body, but we still need to search till the next
	# From: line in order to get the size 
	while(1) {
		$line = <$fh>;
		last if (!$line || $line =~ /^From\s+(\S+).*\d+\r?\n/ &&
			 ($1 ne '-' || $endmode == 2));
		$lnum++;
		$mail->{'size'} += length($line);
		}
	$mail->{'lines'} = $lnum;
	}
return $mail;
}

# dash_mode(user|file)
# Returns 1 if the messages in this folder are separated by lines like
# From - instead of the usual From foo@bar.com
sub dash_mode
{
&open_as_mail_user(DASH, &user_mail_file($_[0])) || return 0;	# assume no
local $line = <DASH>;
close(DASH);
return $line =~ /^From\s+(\S+).*\d/ && $1 eq '-';
}

# mail_matches(&fields, andmode, &mail)
# Returns 1 if some message matches a search
sub mail_matches
{
local $count = 0;
local $f;
foreach $f (@{$_[0]}) {
	local $field = $f->[0];
	local $what = $f->[1];
	local $neg = ($field =~ s/^\!//);
	local $re = $f->[2] ? $what : "\Q$what\E";
	if ($field eq 'body') {
		$count++
		    if (!$neg && $_[2]->{'body'} =~ /$re/i ||
		         $neg && $_[2]->{'body'} !~ /$re/i);
		}
	elsif ($field eq 'size') {
		$count++
		    if (!$neg && $_[2]->{'size'} > $what ||
		         $neg && $_[2]->{'size'} < $what);
		}
	elsif ($field eq 'headers') {
		local $headers = $_[2]->{'rawheaders'} ||
			join("", map { $_->[0].": ".$_->[1]."\n" }
				     @{$_[2]->{'headers'}});
		$count++
		    if (!$neg && $headers =~ /$re/i ||
			 $neg && $headers !~ /$re/i);
		}
	elsif ($field eq 'all') {
		local $headers = $_[2]->{'rawheaders'} ||
			join("", map { $_->[0].": ".$_->[1]."\n" }
				     @{$_[2]->{'headers'}});
		$count++
		    if (!$neg && ($_[2]->{'body'} =~ /$re/i ||
				  $headers =~ /$re/i) ||
		         $neg && ($_[2]->{'body'} !~ /$re/i &&
				  $headers !~ /$re/i));
		}
	elsif ($field eq 'status') {
		$count++
		    if (!$neg && $_[2]->{$field} =~ /$re/i||
		         $neg && $_[2]->{$field} !~ /$re/i);
		}
	else {
		$count++
		    if (!$neg && $_[2]->{'header'}->{$field} =~ /$re/i||
		         $neg && $_[2]->{'header'}->{$field} !~ /$re/i);
		}
	return 1 if ($count && !$_[1]);
	}
return $count == scalar(@{$_[0]});
}

# search_fields(&fields)
# Returns an array of headers/fields from a search
sub search_fields
{
local @rv;
foreach my $f (@{$_[0]}) {
	$f->[0] =~ /^\!?(.*)$/;
	push(@rv, $1);
	}
return &unique(@rv);
}

# matches_needs_body(&fields)
# Returns 1 if a search needs to check the mail body
sub matches_needs_body
{
foreach my $f (@{$_[0]}) {
	return 1 if ($f->[0] eq 'body' || $f->[0] eq 'all');
	}
return 0;
}

# parse_delivery_status(text)
# Returns the fields from a message/delivery-status attachment
sub parse_delivery_status
{
local @lines = split(/[\r\n]+/, $_[0]);
local (%rv, $l);
foreach $l (@lines) {
	if ($l =~ /^(\S+):\s*(.*)/) {
		$rv{lc($1)} = $2;
		}
	}
return \%rv;
}

# parse_mail_date(string)
# Converts a mail Date: header into a unix time
sub parse_mail_date
{
local ($str) = @_;
$str =~ s/^[, \t]+//;
$str =~ s/\s+$//;
open(OLDSTDERR, ">&STDERR");	# suppress STDERR from Time::Local
close(STDERR);
my $rv = eval {
	if ($str =~ /^(\S+),\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+):\s?(\d+):\s?(\d+)\s+(\S+)/) {
		# Format like Mon, 13 Dec 2004 14:40:41 +0100
		# or          Mon, 13 Dec 2004 14:18:16 GMT
		# or	      Tue, 14 Sep 04 02:45:09 GMT
		local $tm = timegm($7, $6, $5, $2, &month_to_number($3),
				   $4 < 50 ? $4+100 : $4 < 1000 ? $4 : $4-1900);
		local $tz = $8;
		if ($tz =~ /^(\-|\+)?\d+$/) {
			local $tz = int($tz);
			$tz = $tz/100 if ($tz >= 50 || $tz <= -50);
			$tm -= $tz*60*60;
			}
		return $tm;
		}
	elsif ($str =~ /^(\S+),\s+(\d+),?\s+(\S+)\s+(\d+)\s+(\d+):\s?(\d+):\s?(\d+)/) {
		# Format like Mon, 13 Dec 2004 14:40:41 or
		#	      Mon, 13, Dec 2004 14:40:41
		# No timezone, so assume local
		local $tm = timelocal($7, $6, $5, $2, &month_to_number($3),
				   $4 < 50 ? $4+100 : $4 < 1000 ? $4 : $4-1900);
		return $tm;
		}
	elsif ($str =~ /^(\S+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)/) {
		# Format like Tue Dec  7 12:58:52 2004
		local $tm = timelocal($6, $5, $4, $3, &month_to_number($2),
				      $7 < 50 ? $7+100 : $7 < 1000 ? $7 : $7-1900);
		return $tm;
		}
	elsif ($str =~ /^(\S+)\s+(\S+)\s+(\d{1,2})\s+(\d+):(\d+):(\d+)/ &&
	       &month_to_number($2)) {
		# Format like Tue Dec  7 12:58:52
		local @now = localtime(time());
		local $tm = timelocal($6, $5, $4, $3, &month_to_number($2),
				      $now[5]);
		return $tm;
		}
	elsif ($str =~ /^(\S+)\s+(\S+)\s+(\d{1,2})\s+(\d+):(\d+)$/ &&
	       defined(&month_to_number($2))) {
		# Format like Tue Dec  7 12:58
		local @now = localtime(time());
		local $tm = timelocal(0, $5, $4, $3, &month_to_number($2),
				      $now[5]);
		return $tm;
		}
	elsif ($str =~ /^(\S+)\s+(\d{1,2})\s+(\d+):(\d+)$/ &&
	       defined(&month_to_number($1))) {
		# Format like Dec  7 12:58
		local @now = localtime(time());
		local $tm = timelocal(0, $4, $3, $2, &month_to_number($1),
				      $now[5]);
		return $tm;
		}
	elsif ($str =~ /^(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)\s+(\S+)/) {
		# Format like Dec  7 12:58:52 2004 GMT
		local $tm = timegm($5, $4, $3, $2, &month_to_number($1),
			      $6 < 50 ? $6+100 : $6 < 1000 ? $6 : $6-1900);
		local $tz = $7;
		if ($tz =~ /^(\-|\+)?\d+$/) {
			$tz = int($tz);
			$tz = $tz/100 if ($tz >= 50 || $tz <= -50);
			$tm -= $tz*60*60;
			}
		return $tm;
		}
	elsif ($str =~ /^(\d{4})\-(\d+)\-(\d+)\s+(\d+):(\d+)/) {
		# Format like 2004-12-07 12:53
		local $tm = timelocal(0, $4, $4, $3, $2-1,
				      $1 < 50 ? $1+100 : $1 < 1000 ? $1 : $1-1900);
		return $tm;
		}
	elsif ($str =~ /^(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\S+)/) {
		# Format like 30 Jun 2005 21:01:01 -0000
		local $tm = timegm($6, $5, $4, $1, &month_to_number($2),
				   $3 < 50 ? $3+100 : $3 < 1000 ? $3 : $3-1900);
		local $tz = $7;
		if ($tz =~ /^(\-|\+)?\d+$/) {
			$tz = int($tz);
			$tz = $tz/100 if ($tz >= 50 || $tz <= -50);
			$tm -= $tz*60*60;
			}
		return $tm;
		}
	elsif ($str =~ /^(\d+)\/(\S+)\/(\d+)\s+(\d+):(\d+)/) {
		# Format like 21/Feb/2008 24:13
		local $tm = timelocal(0, $5, $4, $1, &month_to_number($2),
				      $3-1900);
		return $tm;
		}
	else {
		return undef;
		}
	};
open(STDERR, ">&OLDSTDERR");
close(OLDSTDERR);
if ($@) {
	#print STDERR "parsing of $str failed : $@\n";
	return undef;
	}
return $rv;
}

# send_text_mail(from, to, cc, subject, body, [smtp-server])
# A convenience function for sending a email with just a text body
sub send_text_mail
{
local ($from, $to, $cc, $subject, $body, $smtp) = @_;
local $cs = &get_charset();
local $attach = $body =~ /[\177-\377]/ ?
	{ 'headers' => [ [ 'Content-Type', 'text/plain; charset='.$cs ],
		         [ 'Content-Transfer-Encoding', 'quoted-printable' ] ],
          'data' => &quoted_encode($body) } :
	{ 'headers' => [ [ 'Content-type', 'text/plain' ] ],
	  'data' => &entities_to_ascii($body) };
local $mail = { 'headers' =>
		[ [ 'From', $from ],
		  [ 'To', $to ],
		  [ 'Cc', $cc ],
		  [ 'Subject', $subject ] ],
		'attach' => [ $attach ] };
return &send_mail($mail, undef, 1, 0, $smtp);
}

# make_from_line(address, [time])
# Returns a From line for mbox emails, based on the current time
sub make_from_line
{
local ($addr, $t) = @_;
$t ||= time();
&clear_time_locale();
local $rv = "From $addr ".strftime("%a %b %e %H:%M:%S %Y", localtime($t)); 
&reset_time_locale();
return $rv;
}

sub notes_decode
{
# Deprecated - does nothing
}

# add_mailer_ip_headers(&headers)
# Add X-Mailer and X-Originating-IP headers, if enabled
sub add_mailer_ip_headers
{
local ($headers) = @_;
if (!$config{'no_orig_ip'}) {
	push(@$headers, [ 'X-Originating-IP', $ENV{'REMOTE_ADDR'} ]);
	}
if (!$config{'no_mailer'}) {
	push(@$headers, [ 'X-Mailer', ucfirst(&get_product_name())." ".
				      &get_webmin_version() ]);
	}
}

# set_mail_open_user(user)
# Sets the Unix user that will be used for all mail file open ops, by functions
# like list_mail and select_maildir
sub set_mail_open_user
{
my ($user) = @_;
if ($user eq "root" || $user eq "0") {
	$main::mail_open_user = undef;
	}
elsif (!$<) {
	$main::mail_open_user = $user;
	}
}

# clear_mail_open_user()
# Resets the user to root
sub clear_mail_open_user
{
my ($user) = @_;
$main::mail_open_user = undef;
}

# open_as_mail_user(fh, file)
# Calls the open function, but as the user set by set_mail_open_user
sub open_as_mail_user
{
my ($fh, $file) = @_;
my $switched = &switch_to_mail_user();
my $mode = "<";
if ($file =~ s/^(<|>>|>|\|)//) {
	$mode = $1;
	}
my $rv = open($fh, $mode, $file);
if ($switched) {
	# Now that it is open, switch back to root
	$) = 0;
	$> = 0;
	}
return $rv;
}

# create_as_mail_user(fh, file)
# Creates a new file, but ensures that it does not yet exist first, and then
# sets the ownership to the mail user
sub create_as_mail_user
{
my ($fh, $file) = @_;
if (&should_switch_to_mail_user()) {
	# Open the file as root, but ensure that it doesn't exist yet. Then
	# make it owned by the user
	$file =~ s/^>+//;
	my $rv = sysopen($fh, $file, O_CREAT|O_WRONLY, 0700);
	return $rv if (!$rv);
	my @uinfo = &get_switch_user_info();
	&set_ownership_permissions($uinfo[2], $uinfo[3], undef, $file);
	return $rv;
	}
else {
	# Operating as root, so no special behaviour needed
	if ($file =~ /^(<|>)/) {
		return open($fh, $file);
		}
	else {
		return open($fh, "<", $file);
		}
	}
}

# opendir_as_mail_user(fh, dir)
# Calls the opendir function, but as the user set by set_mail_open_user
sub opendir_as_mail_user
{
my ($fh, $dir) = @_;
my $switched = &switch_to_mail_user();
my $rv = opendir($fh, $dir);
if ($switched) {
	$) = 0;
	$> = 0;
	}
return $rv;
}

# rename_as_mail_user(old, new)
# Like the rename function, but as the user set by set_mail_open_user
sub rename_as_mail_user
{
my ($oldfile, $newfile) = @_;
my $switched = &switch_to_mail_user();
my $rv = &rename_file($oldfile, $newfile);
if ($switched) {
	$) = 0;
	$> = 0;
	}
return $rv;
}

# mkdir_as_mail_user(path, perms)
# Like the mkdir function, but as the user set by set_mail_open_user
sub mkdir_as_mail_user
{
my ($path, $perms) = @_;
my $switched = &switch_to_mail_user();
my $rv = mkdir($path, $perms);
if ($switched) {
	$) = 0;
	$> = 0;
	}
return $rv;
}

# unlink_as_mail_user(path)
# Like the unlink function, but as the user set by set_mail_open_user
sub unlink_as_mail_user
{
my ($path) = @_;
my $switched = &switch_to_mail_user();
my $rv = unlink($path);
if ($switched) {
	$) = 0;
	$> = 0;
	}
return $rv;
}

# copy_source_dest_as_mail_user(source, dest)
# Copy a file, with perms of the user from set_mail_open_user
sub copy_source_dest_as_mail_user
{
my ($src, $dst) = @_;
if (&should_switch_to_mail_user()) {
	&open_as_mail_user(SRC, $src) || return 0;
	&open_as_mail_user(DST, ">$dst") || return 0;
	my $buf;
	while(read(SRC, $buf, 32768) > 0) {
		print DST $buf;
		}
	close(SRC);
	close(DST);
	return 1;
	}
else {
	return &copy_source_dest($src, $dst);
	}
}

# chmod_as_mail_user(perms, file, ...)
# Set file permissions, but with perms of the user from set_mail_open_user
sub chmod_as_mail_user
{
my ($perms, @files) = @_;
my $switched = &switch_to_mail_user();
my $rv = chmod($perms, @files);
if ($switched) {
	$) = 0;
	$> = 0;
	}
return $rv;
}

# should_switch_to_mail_user()
# Returns 1 if file IO will be done as a mail owner user
sub should_switch_to_mail_user
{
return defined($main::mail_open_user) && !$< && !$>;
}

# switch_to_mail_user()
# Sets the permissions used for reading files
sub switch_to_mail_user
{
if (&should_switch_to_mail_user()) {
	# Switch file permissions to the correct user
	my @uinfo = &get_switch_user_info();
	@uinfo || &error("Mail open user $main::mail_open_user ".
			 "does not exist");
	$) = $uinfo[3]." ".join(" ", $uinfo[3], &other_groups($uinfo[0]));
	$> = $uinfo[2];
	return 1;
	}
return 0;
}

# get_switch_user_info()
# Returns the getpw* function array for the user to switch to
sub get_switch_user_info
{
if ($main::mail_open_user =~ /^\d+$/) {
	# Could be by UID .. but fall back to by name if there is no such UID
	my @rv = getpwuid($main::mail_open_user);
	return @rv if (@rv > 0);
	}
return getpwnam($main::mail_open_user);
}

1;

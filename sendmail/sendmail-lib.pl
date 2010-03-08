# sendmail-lib.pl
# Functions for managing sendmail aliases, domains and mappings.
# Only sendmail versions 8.8 and above are supported

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();
$features_access = $access{'opts'} && $access{'ports'} && $access{'cws'} && $access{'masq'} && $access{'trusts'} && $access{'vmode'} && $access{'amode'} && $access{'omode'} && $access{'cgs'} && $access{'relay'} && $access{'mailers'} && $access{'access'} && $access{'domains'};
$config{'perpage'} ||= 20;	# a value of 0 can cause problems
@port_modifier_flags = ( 'a', 'b', 'c', 'f', 'h', 'C', 'E' );

# get_sendmailcf()
# Parses sendmail.cf and return a reference to an array of options.
# Each line is a single character directive, followed by a list of values?
sub get_sendmailcf
{
if (!@sendmailcf_cache) {
	local($lnum, $i);
	$lnum = 0; $i = 0;
	open(CF, $config{'sendmail_cf'});
	while(<CF>) {
		s/^#.*$//g;	# remove comments
		s/\r|\n//g;	# remove newlines
		if (/^(\S)(\s*(.*))$/) {
			local(%opt);
			$opt{'type'} = $1;
			$opt{'value'} = $3;
			$opt{'values'} = [ split(/\s+/, $2) ];
			$opt{'line'} = $lnum;
			$opt{'eline'} = $opt{'line'};
			$opt{'pos'} = $i++;
			push(@sendmailcf_cache, \%opt);
			}
		$lnum++;
		}
	close(CF);
	}
return \@sendmailcf_cache;
}

# check_sendmail_version(&config)
# Is the sendmail config file a usable version?
sub check_sendmail_version
{
local $ver = &find_type("V", $_[0]);
return $ver && $ver->{'value'} =~ /^(\d+)/ && $1 >= 7 ? $1 : undef;
}

# get_sendmail_version(&out)
# Returns the actual sendmail executable version, if it is available
sub get_sendmail_version
{
local $out = &backquote_with_timeout("$config{'sendmail_path'} -d0 -bv 2>&1",
				     2, undef, 1);
local $version;
if ($out =~ /version\s+(\S+)/i) {
	$version = $1;
	}
${$_[0]} = $out if ($_[0]);
return $version;
}

# save_directives(&config, &oldvalues, &newvalues)
# Given 2 arrays of directive structures, this function will replace the
# old ones with the new. If the old list is empty, new directives are added
# to the end of the config file. If the new list is empty, all old directives
# are removed. If both exist, new ones replace old..
sub save_directives
{
local(@old) = @{$_[1]};
local(@new) = @{$_[2]};
$lref = &read_file_lines($config{'sendmail_cf'});
for($i=0; $i<@old || $i<@new; $i++) {
	if ($i >= @old) {
		# A new directive has been added.. put it at the end of the file
		$new[$i]->{'line'} = scalar(@$lref);
		$new[$i]->{'eline'} = $new[$i]->{'line'}+1;
		push(@$lref, &directive_line($new[$i]));
		push(@{$_[0]}, $new[$i]);
		}
	elsif ($i >= @new) {
		# A directive was deleted
		$ol = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		splice(@$lref, $old[$i]->{'line'}, $ol);
		&renumber_list($_[0], $old[$i], -$ol);
		splice(@{$_[0]}, &indexof($old[$i], @{$_[0]}), 1);
		}
	else {
		# A directive was changed
		$ol = $old[$i]->{'eline'} - $old[$i]->{'line'} + 1;
		splice(@$lref, $old[$i]->{'line'}, $ol,
		       &directive_line($new[$i]));
		$new[$i]->{'line'} = $new[$i]->{'eline'} = $old[$i]->{'line'};
		&renumber_list($_[0], $old[$i], 1-$ol);
		$_[0]->[&indexof($old[$i], @{$_[0]})] = $new[$i];
		}
	}
}

# directive_line(&details)
sub directive_line
{
return $_[0]->{'type'}.join(' ', @{$_[0]->{'values'}});
}

# find_type(name, &config)
# Returns an array of config directives of some type
sub find_type
{
local($c, @rv);
foreach $c (@{$_[1]}) {
	if ($c->{'type'} eq $_[0]) {
		push(@rv, $c);
		}
	}
return @rv ? wantarray ? @rv : $rv[0]
           : wantarray ? () : undef;
}

# find_option(name, &config)
# Returns the structure and value of some option directive
sub find_option
{
local(@opts, $o);
@opts = &find_type("O", $_[1]);
foreach $o (@opts) {
	if ($o->{'value'} =~ /^\s*([^=]+)=(.*)$/ && $1 eq $_[0]) {
		# found it.. return
		return wantarray ? ($o, $2) : $2;
		}
	}
return undef;
}

# find_optionss(name, &config)
# Returns the structures and values of some option directive
sub find_options
{
local(@opts, $o);
@opts = &find_type("O", $_[1]);
foreach $o (@opts) {
	if ($o->{'value'} =~ /^\s*([^=]+)=(.*)$/ && $1 eq $_[0]) {
		push(@rv, [ $o, $2 ]);
		}
	}
return wantarray ? @rv : $rv[0];
}

# find_type2(type1, type2, &config)
# Returns the structure and value of some directive
sub find_type2
{
local @types = &find_type($_[0], $_[2]);
local $t;
foreach $t (@types) {
	if ($t->{'value'} =~ /^(\S)(.*)$/ && $1 eq $_[1]) {
		return ($t, $2);
		}
	}
return undef;
}

# restart_sendmail()
# Send a SIGHUP to sendmail
sub restart_sendmail
{
if ($config{'sendmail_restart_command'}) {
	# Use the restart command
	local $out = &backquote_logged("$config{'sendmail_restart_command'} 2>&1 </dev/null");
	return $? || $out =~ /failed|error/i ? "<pre>$out</pre>" : undef;
	}
else {
	# Just HUP the process
	local ($pid, $any);
	foreach my $pidfile (split(/\t+/, $config{'sendmail_pid'})) {
		if (open(PID, $pidfile)) {
			chop($pid = <PID>);
			close(PID);
			if ($pid) { &kill_logged('HUP', $pid); }
			$any++;
			}
		}
	if (!$any) {
		local @pids = &find_byname("sendmail");
		@pids || return $text{'restart_epids'};
		&kill_logged('HUP', @pids) ||
			return &text('restart_ekill', $!);
		}
	return undef;
	}
}

# run_makemap(textfile, dbmfile, type)
# Run makemap to rebuild some map. Calls error if it fails.
sub run_makemap
{
local($out);
$out = &backquote_logged(
	$config{'makemap_path'}." ".quotemeta($_[2])." ".quotemeta($_[1]).
	" <".quotemeta($_[0])." 2>&1");
if ($?) { &error("makemap failed : <pre>".
		 &html_escape($out)."</pre>"); }
}

# rebuild_map_cmd(textfile)
# If a map rebuild command is defined, run it and return 1, otherwise return 0.
# Calls error if it fails.
sub rebuild_map_cmd
{
local ($file) = @_;
if ($config{'rebuild_cmd'}) {
	local $cmd = &substitute_template($config{'rebuild_cmd'},
					  { 'map_file' => $file });
	local $out = &backquote_logged("($cmd) 2>&1");
	if ($?) { &error("Map rebuild failed : <pre>".
			 &html_escape($out)."</pre>"); }
	return 1;
	}
return 0;
}

# find_textfile(config, dbm)
sub find_textfile
{
local($conf, $dbm) = @_;
if ($conf) { return $conf; }
elsif (!$dbm) { return undef; }
elsif ($dbm =~ /^(.*)\.(db|dbm|pag|dir|hash)$/i && -r $1) {
	# Database is like /etc/virtusertable.db, text is /etc/virtusertable
	return $1;
	}
elsif ($dbm =~ /^(.*)\.(db|dbm|pag|dir|hash)$/i && -r "$1.txt") {
	# Database is like /etc/virtusertable.db, text is /etc/virtusertable.txt
	return "$1.txt";
	}
elsif (-r "$dbm.txt") {
	# Database is like /etc/virtusertable, text is /etc/virtusertable.txt
	return "$dbm.txt";
	}
elsif ($dbm =~ /^(.*)\.(db|dbm|pag|dir|hash)$/i) {
	# Database is like /etc/virtusertable.db, text is /etc/virtusertable,
	# but doesn't exist yet.
	return $1;
	}
else {
	# Text and database have same name
	return $dbm;
	}
}

# mailq_dir($conf)
sub mailq_dir
{
local ($opt, $mqueue) = &find_option("QueueDirectory", $_[0]);
local @rv;
if (!$mqueue) { @rv = ( "/var/spool/mqueue" ); }
elsif ($mqueue =~ /\*|\?/) {
	@rv = split(/\s+/, `echo $mqueue`);
	}
else {
	@rv = ( $mqueue );
	}
push(@rv, split(/\s+/, $config{'queue_dirs'}));
return @rv;
}

sub sort_by_domain
{
local ($a1, $a2, $b1, $b2);
if ($a->{'from'} =~ /^(.*)\@(.*)$/ && (($a1, $a2) = ($1, $2)) &&
    $b->{'from'} =~ /^(.*)\@(.*)$/ && (($b1, $b2) = ($1, $2))) {
	return $a2 cmp $b2 ? $a2 cmp $b2 : $a1 cmp $b1;
	}
else {
	return $a->{'from'} cmp $b->{'from'};
	}
}

# can_view_qfile(&mail)
# Returns 1 if some queued message can be viewed, 0 if not
sub can_view_qfile
{
return 1 if (!$access{'qdoms'});
local $re = $access{'qdoms'};
if ($access{'qdomsmode'} == 0) {
	return $_[0]->{'header'}->{'from'} =~ /$re/i;
	}
elsif ($access{'qdomsmode'} == 0) {
	return $_[0]->{'header'}->{'to'} =~ /$re/i;
	}
else {
	return $_[0]->{'header'}->{'from'} =~ /$re/i ||
	       $_[0]->{'header'}->{'to'} =~ /$re/i;
	}
}

# renumber_list(&list, &position-object, lines-offset)
sub renumber_list
{
return if (!$_[2]);
local $e;
foreach $e (@{$_[0]}) {
	if (!defined($e->{'file'}) || $e->{'file'} eq $_[1]->{'file'}) {
		$e->{'line'} += $_[2] if ($e->{'line'} > $_[1]->{'line'});
		$e->{'eline'} += $_[2] if (defined($e->{'eline'}) &&
					   $e->{'eline'} > $_[1]->{'eline'});
		}
	}
}

# get_file_or_config(&config, suffix, [additional-conf], [&cwfile])
# Returns all values for some config file entries, which may be in sendmail.cf
# (like Cw) or externally (like Fw)
sub get_file_or_config
{
local ($conf, $suffix, $addit, $cwref) = @_;
local ($cwfile, $f);
foreach $f (&find_type("F", $conf)) {
	if ($f->{'value'} =~ /^${suffix}[^\/]*(\/\S+)/ ||
	    $f->{'value'} =~ /^\{${suffix}\}[^\/]*(\/\S+)/) {
		$cwfile = $1;
		}
	}
local @rv;
if ($cwfile) {
	# get entries listed in a separate file
	$$cwref = $cwfile if ($cwref);
	open(CW, $cwfile);
	while(<CW>) {
		s/\r|\n//g;
		s/#.*$//g;
		if (/\S/) { push(@rv, $_); }
		}
	close(CW);
	}
else {
	$$cwref = undef if ($cwref);
	}
# Add entries from sendmail.cf
foreach $f (&find_type("C", $conf)) {
	if ($f->{'value'} =~ /^${suffix}\s*(.*)$/ ||
	    $f->{'value'} =~ /^\{${suffix}\}\s*(.*)$/) {
		push(@rv, split(/\s+/, $1));
		}
	}
if ($addit) {
	push(@rv, map { $_->{'value'} } &find_type($addit, $conf));
	}
return &unique(@rv);
}

# save_file_or_config(&conf, suffix, &values, [additional-conf])
# Updates the values in some external file or in sendmail.cf
sub save_file_or_config
{
local ($conf, $suffix, $values, $addit) = @_;
local ($cwfile, $f);
foreach $f (&find_type("F", $conf)) {
	if ($f->{'value'} =~ /^${suffix}[^\/]*(\/\S+)/ ||
	    $f->{'value'} =~ /^\{${suffix}\}[^\/]*(\/\S+)/) {
		$cwfile = $1;
		}
	}
local @old = grep { $_->{'value'} =~ /^${suffix}/ ||
		    $_->{'value'} =~ /^\{${suffix}\}/ } &find_type("C", $conf);
if ($addit) {
	push(@old, &find_type($addit, $conf));
	}
local @new;
local $d;
if ($cwfile) {
	# If there is a .cw file, write all entries to it and take any
	# out of sendmail.cf
	&open_tempfile(CW, ">$cwfile");
	foreach $d (@$values) {
		&print_tempfile(CW, $d,"\n");
		}
	&close_tempfile(CW);
	}
else {
	# Stick all entries in sendmail.cf
	foreach $d (@$values) {
		push(@new, { 'type' => 'C',
			     'values' => [ $suffix.$d ] });
		}
	}
&save_directives($conf, \@old, \@new);
}

# add_file_or_config(&config, suffix, value)
# Adds an entry to sendmail.cf or an external file
sub add_file_or_config
{
local ($conf, $suffix, $value) = @_;
local ($cwfile, $f);
foreach $f (&find_type("F", $conf)) {
	if ($f->{'value'} =~ /^${suffix}[^\/]*(\/\S+)/ ||
	    $f->{'value'} =~ /^\{${suffix}\}[^\/]*(\/\S+)/) {
		$cwfile = $1;
		}
	}
local @old = grep { $_->{'value'} =~ /^${suffix}/ ||
		    $_->{'value'} =~ /^\{${suffix}\}/ } &find_type("C", $conf);
if ($cwfile) {
	# Add to external file
	&open_tempfile(CW, ">>$cwfile");
	&print_tempfile(CW, $value,"\n");
	&close_tempfile(CW);
	}
else {
	# Add to sendmail.cf
	local @new = ( @old, { 'type' => 'C',
			       'values' => [ $suffix.$value ] });
	&save_directives($conf, \@old, \@new);
	}
}

# delete_file_or_config(&config, suffix, value)
# Removes an entry from sendmail.cf or an external file
sub delete_file_or_config
{
local ($conf, $suffix, $value) = @_;
local ($cwfile, $f);
foreach $f (&find_type("F", $conf)) {
	if ($f->{'value'} =~ /^${suffix}[^\/]*(\/\S+)/ ||
	    $f->{'value'} =~ /^\{${suffix}\}[^\/]*(\/\S+)/) {
		$cwfile = $1;
		}
	}
local @old = grep { $_->{'value'} =~ /^${suffix}/ ||
		    $_->{'value'} =~ /^\{${suffix}\}/ } &find_type("C", $conf);
if ($cwfile) {
	# Remove from external file
	local $lref = &read_file_lines($cwfile);
	@$lref = grep { $_ !~ /^\s*\Q$value\E\s*$/i } @$lref;
	&flush_file_lines($cwfile);
	}
else {
	# Remove from sendmail.cf
	local @new = grep { $_->{'values'}->[0] ne $suffix.$value } @old;
	&save_directives($conf, \@old, \@new);
	}
}

# list_mail_queue([&conf])
# Returns a list of all files in the mail queue
sub list_mail_queue
{
local ($mqueue, @qfiles);
local $conf = $_[0] || &get_sendmailcf();
foreach $mqueue (&mailq_dir($conf)) {
	opendir(QDIR, $mqueue);
	push(@qfiles, map { "$mqueue/$_" } grep { /^(qf|hf|Qf)/ } readdir(QDIR));
	closedir(QDIR);
	}
return @qfiles;
}

# list_dontblames()
# Returns an array of valid options for the DontBlameSendmail option
sub list_dontblames
{
local @rv;
open(BLAME, "$module_root_directory/dontblames");
while(<BLAME>) {
	s/\r|\n//g;
	s/^\s*#.*$//;
	if (/^(\S+)\s+(\S.*)$/) {
		push(@rv, [ $1, $2 ]);
		}
	}
close(BLAME);
return @rv;
}

# stop_sendmail()
# Stops the sendmail process, returning undef on success or an error message
# upon failure.
sub stop_sendmail
{
if ($config{'sendmail_stop_command'}) {
	local $out = &backquote_logged("$config{'sendmail_stop_command'} </dev/null 2>&1");
	if ($?) {
		return "<pre>$out</pre>";
		}
	}
else {
	foreach my $pidfile (split(/\t+/, $config{'sendmail_pid'})) {
		local $pid = &check_pid_file($pidfile);
		if ($pid && &kill_logged('KILL', $pid)) {
			unlink($pidfile);
			}
		else {
			return $text{'stop_epid'};
			}
		}
	}
return undef;
}

# start_sendmail()
# Starts the sendmail server, returning undef on success or an error message
# upon failure.
sub start_sendmail
{
if ($config{'sendmail_stop_command'}) {
	# Make sure any init script lock files are gone
	&backquote_logged("$config{'sendmail_stop_command'} </dev/null 2>&1");
	}
local $out = &backquote_logged("$config{'sendmail_command'} </dev/null 2>&1");
return $? ? "<pre>$out</pre>" : undef;
}

sub is_sendmail_running
{
if ($config{'sendmail_smf'}) {
	# Ask SMF, as on Solaris there is no PID file
	local $out = &backquote_command("svcs -H -o STATE ".
			quotemeta($config{'sendmail_smf'})." 2>&1");
	if ($?) {
		&error("Failed to get Sendmail status from SMF : $out");
		}
	return $out =~ /online/i ? 1 : 0;
	}
else {
	# Use PID files, or check for process
	local @pidfiles = split(/\t+/, $config{'sendmail_pid'});
	if (@pidfiles) {
		foreach my $p (@pidfiles) {
			local $c = &check_pid_file($p);
			return $c if ($c);
			}
		return undef;
		}
	else {
		return &find_byname("sendmail");
		}
	}
}

# mailq_table(&qfiles)
# Print a table showing queued emails. Returns the number quarantined.
sub mailq_table
{
local ($qfiles, $qmails) = @_;
local $quarcount;

# Show buttons to flush and delete
print "<form action=del_mailqs.cgi method=post>\n";
local @links = ( &select_all_link("file", 0),
	         &select_invert_link("file", 0) );
if ($config{'top_buttons'}) {
	if ($access{'mailq'} == 2) {
		print "<input type=submit value='$text{'mailq_delete'}'>\n";
		print "<input type=checkbox name=locked value=1> $text{'mailq_locked'}\n";
		print "&nbsp;&nbsp;\n";
		print "<input type=submit name=flush value='$text{'mailq_flushsel'}'>\n";
		print "<p>\n";
		print &ui_links_row(\@links);
		}
	}

# Generate table header
local (@hcols, @tds);
if ($access{'mailq'} == 2) {
	push(@hcols, "");
	push(@tds, "width=5");
	}
local %show;
foreach my $s (split(/,/, $config{'mailq_show'})) {
	$show{$s}++;
	}
push(@hcols, $text{'mailq_id'});
push(@hcols, $text{'mailq_sent'}) if ($show{'Date'});
push(@hcols, $text{'mailq_from'}) if ($show{'From'});
push(@hcols, $text{'mailq_to'}) if ($show{'To'});
push(@hcols, $text{'mailq_cc'}) if ($show{'Cc'});
push(@hcols, $text{'mailq_subject'}) if ($show{'Subject'});
push(@hcols, $text{'mailq_size'}) if ($show{'Size'});
push(@hcols, $text{'mailq_status'}) if ($show{'Status'});
push(@hcols, $text{'mailq_dir'}) if ($show{'Dir'});
print &ui_columns_start(\@hcols, 100, 0, \@tds);

# Show table rows for emails
foreach my $f (@$qfiles) {
	local $n;
	($n = $f) =~ s/^.*\///;
	local $mail = $qmails->{$f} || &mail_from_queue($f);
	next if (!$mail);
	local $dir = $f;
	$dir =~ s/\/[^\/]+$//;

	$mail->{'header'}->{'from'} ||= $text{'mailq_unknown'};
	$mail->{'header'}->{'to'} ||= $text{'mailq_unknown'};
	$mail->{'header'}->{'date'} ||= $text{'mailq_unknown'};
	$mail->{'header'}->{'subject'} ||= $text{'mailq_unknown'};
	$mail->{'header'}->{'cc'} ||= "&nbsp;";
	if ($mail->{'quar'}) {
		$mail->{'status'} = $text{'mailq_quar'};
		$quarcount++;
		}
	$mail->{'status'} ||= $text{'mailq_sending'};

	$mail->{'header'}->{'from'} =
		&html_escape($mail->{'header'}->{'from'});
	$mail->{'header'}->{'to'} =
		&html_escape($mail->{'header'}->{'to'});
	$mail->{'header'}->{'date'} =~ s/\+.*//g;

	local @cols;
	$size = &nice_size($mail->{'size'});
	if ($access{'mailq'} == 2) {
		push(@cols, "<a href=\"view_mailq.cgi?".
			    "file=$f\">$n</a>");
		}
	else {
		push(@cols, $n);
		}
	push(@cols, "<font size=1>".&simplify_date($mail->{'header'}->{'date'}, "ymd")."</font>") if ($show{'Date'});
	push(@cols, "<font size=1>$mail->{'header'}->{'from'}</font>") if ($show{'From'});
	push(@cols, "<font size=1>$mail->{'header'}->{'to'}</font>") if ($show{'To'});
	push(@cols, "<font size=1>$mail->{'header'}->{'cc'}</font>") if ($show{'Cc'});
	push(@cols, "<font size=1>$mail->{'header'}->{'subject'}</font>") if ($show{'Subject'});
	push(@cols, "<font size=1>$size</font>") if ($show{'Size'});
	push(@cols, "<font size=1>$mail->{'status'}</font>") if ($show{'Status'});
	push(@cols, "<font size=1>$dir</font>") if ($show{'Dir'});
	print "</tr>\n";
	if ($access{'mailq'} == 2) {
		print &ui_checked_columns_row(\@cols, \@tds, "file",$f);
		}
	else {
		print &ui_columns_row(\@cols, \@tds);
		}
	}
print &ui_columns_end();
if ($access{'mailq'} == 2) {
	print &ui_links_row(\@links);
	print "<input type=submit value='$text{'mailq_delete'}'>\n";
	print "<input type=checkbox name=locked value=1> $text{'mailq_locked'}\n";

	print "&nbsp;&nbsp;\n";
	print "<input type=submit name=flush value='$text{'mailq_flushsel'}'>\n";
	print "<p>\n";
	}
print "</form>\n";
return $quarcount;
}

# is_table_comment(line, [force-prefix])
# Returns the comment text if a line contains a comment, like # foo
sub is_table_comment
{
local ($line, $force) = @_;
if ($config{'prefix_cmts'} || $force) {
	return $line =~ /^\s*#+\s*Webmin:\s*(.*)/ ? $1 : undef;
	}
else {
	return $line =~ /^\s*#+\s*(.*)/ ? $1 : undef;
	}
}

# make_table_comment(comment, [force-tag])
# Returns an array of lines for a comment in a map file, like # foo
sub make_table_comment
{
local ($cmt, $force) = @_;
if (!$cmt) {
	return ( );
	}
elsif ($config{'prefix_cmts'} || $force) {
	return ( "# Webmin: $cmt" );
	}
else {
	return ( "# $cmt" );
	}
}

1;


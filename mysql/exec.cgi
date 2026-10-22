#!/usr/local/bin/perl
# exec.cgi
# Execute some SQL command and display output

require './mysql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
$access{'edonly'} && &error($text{'dbase_ecannot'});
&error_setup($text{'exec_err'});
$sql_charset = $in{'charset'};

# normalize_sql_for_history(command)
# Collapse textarea SQL into a single history line.
sub normalize_sql_for_history
{
my ($cmd) = @_;
$cmd =~ s/\r//g;
return join(" ", split(/\n+/, $cmd));
}

# count_sql_terminators(sql)
# Count semicolons in SQL text, skipping those inside single/double/backtick
# quotes, line comments (# and --), and block comments (/* ... */). Used to
# detect multi-statement input. Miscounts should not happen in practice but are
# safe either way: on undercount, multi-statement SQL goes through the
# single-statement path and fails visibly; on overcount, a single statement goes
# through the file executor which handles it fine.
sub count_sql_terminators
{
my ($sql) = @_;
my $count = 0;
my ($sq, $dq, $bq, $line_comment, $block_comment, $escaped);
for (my $i = 0; $i < length($sql); $i++) {
	my $c = substr($sql, $i, 1);
	my $n = $i+1 < length($sql) ? substr($sql, $i+1, 1) : '';
	if ($line_comment) {
		$line_comment = 0 if ($c eq "\n");
		next;
		}
	if ($block_comment) {
		if ($c eq '*' && $n eq '/') {
			$block_comment = 0;
			$i++;
			}
		next;
		}
	if ($sq) {
		if ($c eq "\\" && !$escaped) {
			$escaped = 1;
			next;
			}
		$sq = 0 if ($c eq "'" && !$escaped);
		$escaped = 0;
		next;
		}
	if ($dq) {
		if ($c eq "\\" && !$escaped) {
			$escaped = 1;
			next;
			}
		$dq = 0 if ($c eq '"' && !$escaped);
		$escaped = 0;
		next;
		}
	if ($bq) {
		$bq = 0 if ($c eq '`');
		next;
		}
	if ($c eq '#' ) {
		$line_comment = 1;
		next;
		}
	if ($c eq '-' && $n eq '-') {
		my $p = $i ? substr($sql, $i-1, 1) : '';
		my $a = $i+2 < length($sql) ? substr($sql, $i+2, 1) : '';
		if (($i == 0 || $p =~ /\s/) && ($a eq '' || $a =~ /\s/)) {
			$line_comment = 1;
			$i++;
			next;
			}
		}
	if ($c eq '/' && $n eq '*') {
		$block_comment = 1;
		$i++;
		next;
		}
	if ($c eq "'") {
		$sq = 1;
		$escaped = 0;
		next;
		}
	if ($c eq '"') {
		$dq = 1;
		$escaped = 0;
		next;
		}
	if ($c eq '`') {
		$bq = 1;
		next;
		}
	if ($c eq ';') {
		$count++;
		}
	}
return $count;
}

# looks_like_sql_script(command)
# Detect pasted SQL that should use the file-style script executor.
sub looks_like_sql_script
{
my ($cmd) = @_;
return 1 if ($cmd =~ /^\s*(?:delimiter|source|\\\.)\b/im);
return 1 if ($cmd =~ /^\s*(?:--(?:\s|$)|#)/m);
return &count_sql_terminators($cmd) > 1;
}

# execute_textarea_script(database, command)
# Run pasted SQL through the same path used for uploaded script files.
sub execute_textarea_script
{
my ($db, $cmd) = @_;
my $file = &transname();
&open_tempfile(TEMP, ">$file");
&print_tempfile(TEMP, $cmd);
&print_tempfile(TEMP, "\n") if ($cmd !~ /\n\z/);
&close_tempfile(TEMP);
my @rv = &execute_sql_file($db, $file, undef, undef, $access{'buser'});
&unlink_file($file);
return @rv;
}

# summarize_sql_script(sql)
# Count common DDL and DML actions for friendly success messages.
sub summarize_sql_script
{
my ($sql) = @_;
my %rv = ( 'create_count' => 0,
	   'insert_count' => 0 );
foreach my $line (split(/\n/, $sql)) {
	if ($line =~ /^\s*insert\s+into\s+`(\S+)`/i ||
	    $line =~ /^\s*insert\s+into\s+(\S+)/i) {
		$rv{'insert_count'}++;
		}
	if ($line =~ /^\s*create\s+table\s+`(\S+)`/i ||
	    $line =~ /^\s*create\s+table\s+(\S+)/i) {
		$rv{'create_count'}++;
		}
	}
return \%rv;
}

# extract_execute_error_text(error)
# Strip Webmin's wrapper text down to the database error itself.
sub extract_execute_error_text
{
my ($err) = @_;
$err =~ s/\s+at\s+\S+\s+line\s+\d+.*$//s;
if ($err =~ /failed\s*:\s*<tt>(.*?)<\/tt>\s*$/s) {
	$err = $1;
	}
elsif ($err =~ /failed\s*:\s*"([^"]+)"\s*$/s) {
	$err = $1;
	}
elsif ($err =~ /failed\s*:\s*(.*?)\s*$/s) {
	$err = $1;
	}
$err =~ s/<[^>]+>//g;
# Normalize to plain text: undo any HTML escaping from shared helpers
# so the caller can re-escape once at final display time.
$err = &html_unescape($err);
return $err;
}

# print_exec_status_lines(first, rest...)
# Print one or more status lines with predictable wrapper spans.
sub print_exec_status_lines
{
my ($first, @rest) = @_;
print &ui_tag('span', $first, { 'data-first-print' => undef });
if (@rest) {
	print &ui_tag('br');
	for (my $i = 0; $i < @rest; $i++) {
		print &ui_tag('span', $rest[$i],
			      { 'data-second-print' => undef });
		print &ui_tag('br') if ($i+1 < @rest);
		}
	}
}

# print_exec_error_block(first, second, detail)
# Print a wrapped error block with a preformatted message body.
sub print_exec_error_block
{
my ($first, $second, $detail) = @_;
$detail = defined($detail) && $detail =~ /\S/ ? $detail : $text{'exec_noout'};
&print_exec_status_lines($first, $second);
print &ui_tag('br');
print &ui_tag('pre', &html_escape($detail),
	      { 'style' => 'white-space: pre-wrap; margin-left: 10px;' });
}

if ($in{'clear'}) {
	# Delete the history file
	&unlink_file($commands_file.".".$in{'db'});
	&redirect("exec_form.cgi?db=".&urlize($in{'db'}));
	}
else {
	# Run some SQL
	$rawcmd = defined($in{'cmd'}) ? $in{'cmd'} : undef;
	defined($rawcmd) && $rawcmd =~ /\S/ || &error($text{'exec_ecmd'});
	$rawcmd =~ s/\r//g;
	$cmd = &normalize_sql_for_history($rawcmd);
	# Multi-statement input uses the same executor as uploaded SQL files.
	$script = &looks_like_sql_script($rawcmd);

	if ($script) {
		($ex, $out) = &execute_textarea_script($in{'db'}, $rawcmd);
		$summary = &summarize_sql_script($rawcmd);

		&ui_print_header(undef, $text{'exec_title'}, "");
		if ($ex) {
			&print_exec_error_block($text{'exec_scriptout'},
						$text{'exec_scriptfailed'},
						$out);
			}
		else {
			@lines = ( );
			if ($summary->{'create_count'}) {
				push(@lines, &text('exec_scriptcreated',
						   $summary->{'create_count'}));
				}
			if ($summary->{'insert_count'}) {
				push(@lines, &text('exec_scriptinserted',
						   $summary->{'insert_count'}));
				}
			if (!@lines) {
				push(@lines, $text{'exec_scriptok'});
				}
			&print_exec_status_lines($text{'exec_scriptout'},
						 @lines);
			print "<p>\n";
			}
		}
	else {
		eval {
			local $main::error_must_die = 1;
			# Capture DBI/mysql errors so we can render them consistently.
			$d = &execute_sql_logged($in{'db'}, $cmd);
			};
		if ($@) {
			$failed = 1;
			$err = &extract_execute_error_text($@);
			&ui_print_header(undef, $text{'exec_title'}, "");
			&print_exec_error_block($text{'exec_cmdout'},
						$text{'exec_cmdfailed'}, $err);
			}
		else {
			@data = @{$d->{'data'}};

			&ui_print_header(undef, $text{'exec_title'}, "");
			if (@data) {
				print &text('exec_out',
				    "<tt>".&html_escape($cmd)."</tt>"),"<p>\n";
				print &ui_columns_start([ map { &html_escape($_) } @{$d->{'titles'}} ]);
				foreach $r (@data) {
					print &ui_columns_row([
						map { &html_escape($_) } @$r ]);
					}
				print &ui_columns_end();
				}
			else {
				&print_exec_status_lines($text{'exec_cmdout'},
							 $text{'exec_cmdok'});
				print "<p>\n";
				}
			}
		}

	&open_readfile(OLD, "$commands_file.$in{'db'}");
	while(<OLD>) {
		s/\r|\n//g;
		$already++ if ($_ eq $cmd);
		}
	close(OLD);
	# Only store successful single commands in history. Script runs are
	# intentionally left out to avoid flattening multi-line SQL for re-use.
	if (!$script && !$failed && !$already && $cmd =~ /\S/) {
		&open_lock_tempfile(OLD, ">>$commands_file.$in{'db'}");
		&print_tempfile(OLD, "$cmd\n");
		&close_tempfile(OLD);
		chmod(0700, "$commands_file.$in{'db'}");
		}
	&webmin_log("exec", undef, $in{'db'}, \%in);

	&ui_print_footer("exec_form.cgi?db=".&urlize($in{'db'}), $text{'exec_return'},
		"edit_dbase.cgi?db=".&urlize($in{'db'}), $text{'dbase_return'},
		&get_databases_return_link($in{'db'}), $text{'index_return'});
	}


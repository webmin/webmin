#!/usr/local/bin/perl
# exec.cgi
# Execute some SQL command and display output

require './postgresql-lib.pl';
&ReadParseMime();
&can_edit_db($in{'db'}) || &error($text{'dbase_ecannot'});
&error_setup($text{'exec_err'});

if ($in{'clear'}) {
	# Delete the history file
	&unlink_file($commands_file.".".$in{'db'});
	&redirect("exec_form.cgi?db=$in{'db'}");
	}
else {
	# Run some SQL
	$in{'cmd'} = join(" ", split(/[\r\n]+/, $in{'cmd'}));
	$cmd = $in{'cmd'} ? $in{'cmd'} : $in{'old'};
	$d = &execute_sql_logged($in{'db'}, $cmd);

	&ui_print_header(undef, $text{'exec_title'}, "");
	print &text('exec_out', "<tt>".&html_escape($cmd)."</tt>"),"<p>\n";
	@data = @{$d->{'data'}};
	if (@data) {
		print &ui_columns_start($d->{'titles'});
		foreach $r (@data) {
			@prow = map { ref($_) eq 'ARRAY' ? join(", ", @$_)
							 : $_ } @$r;
			print &ui_columns_row([ map { &html_escape($_) } @prow ]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'exec_none'}</b> <p>\n";
		}

	# Add to the old commands file
	open(OLD, "$commands_file.$in{'db'}");
	while(<OLD>) {
		s/\r|\n//g;
		$already++ if ($_ eq $in{'cmd'});
		}
	close(OLD);
	if (!$already && $in{'cmd'} =~ /\S/) {
		&open_lock_tempfile(OLD, ">>$commands_file.$in{'db'}");
		&print_tempfile(OLD, "$in{'cmd'}\n");
		&close_tempfile(OLD);
		chmod(0700, "$commands_file.$in{'db'}");
		}

	&webmin_log("exec", undef, $in{'db'}, \%in);
	}

&ui_print_footer("exec_form.cgi?db=$in{'db'}", $text{'exec_return'},
		 "edit_dbase.cgi?db=$in{'db'}", $text{'dbase_return'},
		 "", $text{'index_return'});


#!/usr/bin/perl
# Actually do an import of time ranges

require './itsecur-lib.pl';
&can_edit_error("import");
&error_setup($text{'import_err'});
&ReadParseMime();

# Validate inputs
if (!$in{'src_def'}) {
	-r $in{'src'} || &error_cleanup($text{'restore_esrc'});
	$data = `cat $in{'src'}`;
	}
else {
	$in{'file'} || &error_cleanup($text{'restore_efile'});
	$data = $in{'file'};
	}

%times = map { $_->{'name'}, $_ } &list_times();
%daynum = ( "sun", 0, "mon", 1, "tue", 2, "wed", 3, "thu", 4, "fri", 5, "sat", 6 );

# Parse the CSV data
$data =~ s/\r//g;
$i = 0;
foreach $line (split(/\n/, $data)) {
	# Split into columns
	$oldline = $line;
	$i++;
	next if (!$line);
	local @row;
	while($line && $line =~ /^,?("([^"]*)"|([^,]*))(.*)$/) {
		push(@row, $2 || $3);
		$line = $4;
		}
	@row >= 1 || &error(&text('import_erow', $i, $oldline));

	# Create a service
	$row[0] =~ /\S/ || &error(text('import_etimename', $i));
	$times{$row[0]} && &error(text('import_etimeclash', $i, $row[0]));
	$time = { 'name' => $row[0] };
	if ($row[1]) {
		# Week days are given
		foreach $d (split(/[\s|,]+/, $row[1])) {
			local $dn = $daynum{lc($d)};
			defined($dn) || &error(text('import_etimeday', $i, $d));
			push(@days, $dn);
			}
		$time->{'days'} = join(",", @days);
		}
	else {
		$time->{'days'} = '*';
		}
	if ($row[2]) {
		# Time range is given
		$row[2] =~ /^(\d+):(\d+)\-(\d+):(\d+)$/ &&
			$1 >= 0 && $1 < 24 &&
			$2 >= 0 && $2 < 60 &&
			$3 >= 0 && $3 < 24 &&
			$4 >= 0 && $4 < 60 ||
			&error(&text('import_etimehour', $i, $row[2]));
		$time->{'hours'} = $row[2];
		}
	else {
		$time->{'hours'} = '*';
		}
	$time->{'days'} eq '*' && $time->{'hours'} eq '*' &&
		&error(text('import_etimenone', $i));
	push(@newtimes, $time);
	}

# Save the groups
&lock_itsecur_files();
@times = &list_times();
push(@times, @newtimes);
&automatic_backup();
&save_times(@times);
&unlock_itsecur_files();

# Tell the user
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>",&text('import_done4', scalar(@newtimes)),"<p>\n";

print "<hr>\n";
&footer("", $text{'index_return'});
&remote_webmin_log("import", "times", $in{'src_def'} ? undef : $in{'src'});


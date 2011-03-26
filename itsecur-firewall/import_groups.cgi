#!/usr/bin/perl
# Actually do an import of host groups

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

%groups = map { $_->{'name'}, $_ } &list_groups();

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
	$row[0] =~ /\S/ || &error(text('import_egroupname', $i));
	$groups{$row[0]} && &error(text('import_egroupclash', $i, $row[0]));
	$group = { 'name' => $row[0] };
	if (@row == 1) {
		# Group name is the host name
		&valid_host($row[0]) ||
			&error(text('import_ehost', $i, $row[0]));
		$group->{'members'} = [ $row[0] ];
		}
	else {
		# Hosts are listed
		for($i=1; $i<@row; $i++) {
			&valid_host($row[$i]) ||
				&error(text('import_ehost', $i, $row[$i]));
			push(@{$group->{'members'}}, $row[$i]);
			}
		}
	push(@newgroups, $group);
	}

# Save the groups
&lock_itsecur_files();
@groups = &list_groups();
push(@groups, @newgroups);
&automatic_backup();
&save_groups(@groups);
&unlock_itsecur_files();

# Tell the user
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>",&text('import_done3', scalar(@newgroups)),"<p>\n";

print "<hr>\n";
&footer("", $text{'index_return'});
&remote_webmin_log("import", "services", $in{'src_def'} ? undef : $in{'src'});


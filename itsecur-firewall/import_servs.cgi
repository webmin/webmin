#!/usr/bin/perl
# Actually do an import of services

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

%services = map { $_->{'name'}, $_ } &list_services();

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
	@row >= 3 || &error(&text('import_erow', $i, $oldline));

	# Create a service
	$row[0] =~ /\S/ || &error(text('import_eservname', $i));
	$services{$row[0]} && &error(text('import_eservclash', $i, $row[0]));
	$serv = { 'name' => $row[0] };
	for($i=1; $i<@row; $i+=2) {
		getprotobyname($row[$i]) ||
			&error(text('import_eproto', $i, $row[$i]));
		$row[$i+1] =~ /^\d+$/ ||
			&error(text('import_eservnum', $i, $row[$i]));
		push(@{$serv->{'protos'}}, $row[$i]);
		push(@{$serv->{'ports'}}, $row[$i+1]);
		}
	push(@newservs, $serv);
	}

# Save the services
&lock_itsecur_files();
@servs = &list_services();
push(@servs, @newservs);
&automatic_backup();
&save_services(@servs);
&unlock_itsecur_files();

# Tell the user
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>",&text('import_done2', scalar(@newservs)),"<p>\n";

print "<hr>\n";
&footer("", $text{'index_return'});
&remote_webmin_log("import", "services", $in{'src_def'} ? undef : $in{'src'});


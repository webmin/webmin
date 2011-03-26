#!/usr/bin/perl
# Actually do an import

require './itsecur-lib.pl';
&can_edit_error("import");
&error_setup($text{'import_err'});
&ReadParseMime();

if (&foreign_check("net")) {
	&foreign_require("net", "net-lib.pl");
	foreach $i (&net::active_interfaces(), &net::boot_interfaces()) {
		$iface{$i->{'fullname'}} = $i;
		}
	}
%services = map { $_->{'name'}, $_ } &list_services();
%times = map { $_->{'name'}, $_ } &list_times();

# Validate inputs
if (!$in{'src_def'}) {
	-r $in{'src'} || &error_cleanup($text{'restore_esrc'});
	$data = `cat $in{'src'}`;
	}
else {
	$in{'file'} || &error_cleanup($text{'restore_efile'});
	$data = $in{'file'};
	}

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
	@row >= 4 || &error(&text('import_erow', $i, $oldline));

	# Create a rule
	$rule = { 'enabled' => 1 };
	$rule->{'source'} = &parse_srcdest($row[0]);
	$rule->{'source'} || &error(text('import_esource', $i, $row[0]));
	$rule->{'dest'} = &parse_srcdest($row[1]);
	$rule->{'dest'} || &error(text('import_edest', $i, $row[1]));
	@servs = split(/\s+/, $row[2]);
	foreach $s (@servs) {
		$services{$s} || &error(text('import_eservice', $i, $s));
		}
	$rule->{'service'} = @servs ? join(",", @servs) : "*";
	if ($row[3] =~ s/\s+log$//i) {
		$rule->{'log'} = 1;
		}
	else {
		$rule->{'log'} = 0;
		}
	&indexof(lc($row[3]), @actions) >= 0 ||
		&error(text('import_eaction', $i, $row[3]));
	$rule->{'action'} = lc($row[3]);
	$rule->{'desc'} = $row[4] || "*";
	if ($row[5]) {
		$times{$row[5]} || &error(text('import_etime', $i, $row[5]));
		$rule->{'time'} = $row[5];
		}
	else {
		$rule->{'time'} = "*";
		}
	push(@newrules, $rule);
	}

# Ensure that new rules are sane

# Save the rules
&lock_itsecur_files();
@rules = &list_rules();
push(@rules, @newrules);
&automatic_backup();
&save_rules(@rules);
&unlock_itsecur_files();

# Tell the user
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>",&text('import_done1', scalar(@newrules)),"<p>\n";

print "<hr>\n";
&footer("", $text{'index_return'});
&remote_webmin_log("import", "rules", $in{'src_def'} ? undef : $in{'src'});

sub parse_srcdest
{
if ($_[0] eq "") {
	return "*";
	}
elsif (&valid_host($_[0])) {
	return $_[0];
	}
elsif ($iface{lc($_[0])}) {
	return "%".lc($_[0]);
	}
else {
	return undef;
	}
}

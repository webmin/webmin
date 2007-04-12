#!/usr/local/bin/perl
# import.cgi
# Add an imported connection to the config file

require './ipsec-lib.pl';
&ReadParseMime();
&error_setup($text{'import_err'});

# Get the file
if ($in{'mode'} == 0) {
	$in{'upload'} || &error($text{'import_eupload'});
	$in{'upload'} =~ s/\r//g;
	@data = split(/\n/, $in{'upload'});
	}
else {
	$in{'file'} || &error($text{'import_efile'});
	open(FILE, $in{'file'}) || &error($text{'import_eopen'});
	while(<FILE>) {
		s/\r|\n//g;
		push(@data, $_);
		}
	close(FILE);
	}

# Read and validate it
$temp = &transname();
open(TEMP, ">$temp");
print TEMP map { "$_\n" } @data;
close(TEMP);
@iconf = &get_config($temp);
unlink($temp);
if (@iconf != 1 || $iconf[0]->{'name'} ne 'conn') {
	&error($text{'import_eformat'});
	}
@conf = &get_config();
foreach $c (@conf) {
	if (lc($c->{'value'}) eq lc($iconf[0]->{'value'})) {
		$clash = $c;
		if (!$in{'over'}) {
			&error(&text('import_eclash',
				     "<tt>$iconf[0]->{'value'}</tt>"));
			}
		}
	}

# Add to the real config file
if ($clash) {
	&lock_file($clash->{'file'});
	$lref = &read_file_lines($clash->{'file'});
	splice(@$lref, $clash->{'line'},
	       $clash->{'eline'} - $clash->{'line'} + 1, @data);
	}
else {
	&lock_file($config{'file'});
	$lref = &read_file_lines($config{'file'});
	push(@$lref, @data);
	}
&flush_file_lines();
&unlock_all_files();

# Tell the user
&ui_print_header(undef, $text{'import_title'}, "");

print "<p>",&text($clash ? 'import_done2' : 'import_done1',
		  "<tt>$iconf[0]->{'value'}</tt>"),"<p>\n";

&ui_print_footer("", $text{'index_return'});

# All done
&webmin_log("import", "conn", $iconf[0]->{'value'}, $iconf[0]->{'values'});


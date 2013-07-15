# Functions for reading and writing autoreply files

# read_autoreply(file, &simple)
# Fills in the autoreply parts of a simple alias structure from a file
sub read_autoreply
{
local ($file, $simple) = @_;
local @lines;
open(FILE, $file);
while(<FILE>) {
	if (/^Reply-Tracking:\s*(.*)/) {
		$simple->{'replies'} = $1;
		}
	elsif (/^Reply-Period:\s*(.*)/) {
		$simple->{'period'} = $1;
		}
	elsif (/^No-Autoreply:\s*(.*)/) {
		$simple->{'no_autoreply'} = $1;
		}
	elsif (/^No-Autoreply-Regexp:\s*(.*)/) {
		push(@{$simple->{'no_autoreply_regexp'}}, $1);
		}
	elsif (/^Autoreply-File:\s*(.*)/) {
		push(@{$simple->{'autoreply_file'}}, $1);
		}
	elsif (/^Autoreply-Start:\s*(\d+)/) {
		$simple->{'autoreply_start'} = $1;
		}
	elsif (/^Autoreply-End:\s*(\d+)/) {
		$simple->{'autoreply_end'} = $1;
		}
	elsif (/^From:\s*(.*)/) {
		$simple->{'from'} = $1;
		}
	elsif (/^Charset:\s*(\S+)/) {
		$simple->{'charset'} = $1;
		}
	elsif (/^Subject:\s*(\S.*)/) {
		$simple->{'subject'} = $1;
		}
	else {
		push(@lines, $_);
		}
	}
close(FILE);
$simple->{'autotext'} = join("", @lines);
}

# write_autoreply(&file, &simple)
# Writes the autoreply parts of a simple alias structure to a file
sub write_autoreply
{
local ($file, $simple) = @_;
&open_tempfile(AUTO, ">$file");
if ($simple->{'replies'}) {
	&print_tempfile(AUTO,
		"Reply-Tracking: $simple->{'replies'}\n");
	}
if ($simple->{'period'}) {
	&print_tempfile(AUTO,
		"Reply-Period: $simple->{'period'}\n");
	}
if ($simple->{'no_autoreply'}) {
	&print_tempfile(AUTO,
		"No-Autoreply: $simple->{'no_autoreply'}\n");
	}
foreach my $r (@{$simple->{'no_autoreply_regexp'}}) {
	&print_tempfile(AUTO, "No-Autoreply-Regexp: $r\n");
	}
foreach my $f (@{$simple->{'autoreply_file'}}) {
	&print_tempfile(AUTO, "Autoreply-File: $f\n");
	}
if ($simple->{'autoreply_start'}) {
	&print_tempfile(AUTO,
		"Autoreply-Start: $simple->{'autoreply_start'}\n");
	}
if ($simple->{'autoreply_end'}) {
	&print_tempfile(AUTO,
		"Autoreply-End: $simple->{'autoreply_end'}\n");
	}
if ($simple->{'from'}) {
	&print_tempfile(AUTO, "From: $simple->{'from'}\n");
	}
if ($simple->{'charset'}) {
	&print_tempfile(AUTO, "Charset: $simple->{'charset'}\n");
	}
if ($simple->{'subject'}) {
	&print_tempfile(AUTO, "Subject: $simple->{'subject'}\n");
	}
&print_tempfile(AUTO, $simple->{'autotext'});
&close_tempfile(AUTO);
}

1;


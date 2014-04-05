#!/usr/local/bin/perl
# search.cgi
# Find files under some directory

require './file-lib.pl';
$disallowed_buttons{'search'} && &error($text{'ebutton'});
&ReadParse();
&switch_acl_uid();
print "Content-type: text/plain\n\n";
if (!&can_access($in{'dir'})) {
	print $text{'search_eaccess'},"\n";
	}

$in{'dir'} =~ s/^\/+/\//g;
if ($in{'dir'} ne '/') {
	$in{'dir'} =~ s/\/$//;
	}
$cmd = "find ".quotemeta(&unmake_chroot($in{'dir'}))." -name ".quotemeta($in{'match'});
if ($in{'type'}) {
        $cmd .= " -type ".quotemeta($in{'type'});
        }
if ($in{'user'}) {
        $cmd .= " -user ".quotemeta($in{'user'});
        }
if ($in{'group'}) {
        $cmd .= " -group ".quotemeta($in{'group'});
        }
if ($in{'size'}) {
        $cmd .= " -size ".quotemeta($in{'size'});
        }
if ($in{'xdev'}) {
	$cmd .= " -mount";
	}

print "\n";
open(CMD, "$cmd 2>/dev/null |");
while($f = <CMD>) {
	chop($f);
	if (defined($in{'cont'})) {
		# Check the file contents for the given pattern
		$found = 0;
		if ($f =~ /\.pdf$/i && &has_command("pdftotext")) {
			# Convert PDF to text
			open(FILE, "pdftotext -raw ".quotemeta($f)." - |");
			}
		else {
			open(FILE, $f);
			}
		while(<FILE>) {
			if (/\Q$in{'cont'}\E/i) {
				$found = 1;
				last;
				}
			}
		close(FILE);
		next if (!$found);
		}
	local $rf = &make_chroot($f);
	local $fil = &file_info_line($f, $rf);
	print $fil,"\n" if (defined($fil));
	}
close(CMD);


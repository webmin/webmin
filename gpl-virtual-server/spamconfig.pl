#!/usr/local/bin/perl
# For each domain with spam enabled, update the links in it's spamassassin
# config directory to match the global config.
# Also, delete /tmp/clamav-* directories that have not been accessed in more
# than 1 day.

package virtual_server;
$main::no_acl_check++;
$no_virtualmin_plugins = 1;
require './virtual-server-lib.pl';

# Create spamassassin config links
foreach my $d (grep { $_->{'spam'} } &list_domains()) {
	&create_spam_config_links($d);
	}

# Cleanup ClamAV crap in /tmp
$cutoff = time() - 24*60*60;
opendir(TMP, "/tmp");
foreach my $f (readdir(TMP)) {
	$path = "/tmp/$f";
	if ($f =~ /^clamav-([0-9a-f]+)$/ && -d $path) {
		# A clamav-* directory .. have any files in it been
		# accessed lately?
		my $newest = 0;
		opendir(CLAM, $path);
		foreach my $c (readdir(CLAM)) {
			next if ($c eq "." || $c eq "..");
			$cpath = "$path/$c";
			@st = stat($cpath);
			$newest = $st[8] if ($st[8] > $newest);
			$newest = $st[9] if ($st[9] > $newest);
			$newest = $st[10] if ($st[10] > $newest);
			}
		closedir(CLAM);
		if ($newest < $cutoff) {
			# This whole directory needs to go
			&execute_command("rm -rf ".quotemeta($path));
			}
		}
	}
closedir(TMP);

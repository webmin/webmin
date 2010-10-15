#!/usr/local/bin/perl
# install.cgi
# Install the GRUB boot loader

require './grub-lib.pl';
&error_setup($text{'install_err'});
&ReadParse();

# Find out which partition the menu file is on
@st = stat($config{'menu_file'});
&foreign_require("mount", "mount-lib.pl");
foreach $d (sort { length($a->[0]) <=> length($b->[0]) }
		 &mount::list_mounted()) {
	@fst = stat($d->[0]);
	$mount = $d->[0] if ($fst[0] == $st[0]);
	}
$mount =~ s/\/$//;
$menu_file = $config{'menu_file'};
$menu_file =~ s/^\Q$mount\E//;

# Ask grub where the menu.lst file is
$temp = &transname();
open(TEMP, ">$temp");
print TEMP "find $menu_file\n";
close(TEMP);
open(GRUB, "$config{'grub_path'} --batch <$temp |");
while(<GRUB>) {
	if (/find\s+(\S+)/ && $1 eq $menu_file) {
		$out .= $_;
		$_ = <GRUB>;
		if (/^\s*(\(\S+\))/) {
			$root = $1;
			}
		}
	$out .= $_;
	}
close(GRUB);
unlink($temp);
if (!$root || $?) {
	# Didn't find it!
	&error($text{'install_efind'},"<pre>",$out,"</pre>");
	}

# Setup on the chosen device
&ui_print_header(undef, $text{'install_title'}, "");
print &text('install_desc', $in{'dev'}, "<tt>root $root</tt>",
	    "<tt>setup $config{'install'}</tt>"),"<p>\n";
print "<pre>";
open(TEMP, ">$temp");
print TEMP "root $root\n";
print TEMP "setup $config{'install'}\n";
close(TEMP);
open(GRUB, "$config{'grub_path'} --batch <$temp |");
while(<GRUB>) {
	if (/\d+\s+sectors\s+are\s+embedded/i) {
		$embedded++;
		}
	elsif (/error/) {
		$error++;
		}
	print &html_escape($_);
	}
close(GRUB);
print "</pre>\n";
if (!$embedded || $? || $error) {
	print "$text{'install_failed'}<p>\n";
	}
else {
	print "$text{'install_ok'}<p>\n";
	}

&webmin_log("install");
&ui_print_footer("", $text{'index_return'});


#!/usr/local/bin/perl
# cpan.cgi
# Display known perl modules and categories

require './cpan-lib.pl';
&ReadParse();

# re-fetch modules list if non-existant or it timeout has expired
@st = $packages_file;
$now = time();
if (!-r $packages_file ||
    $st[9]+$config{'refresh_days'}*24*60*60 < $now) {
	&download_packages_file();
	}

# Read the modules list
open(LIST, "gunzip -c $packages_file |");
while(<LIST>) {
	s/\r|\n//g;
	if ($_ eq '') { $found_blank++; }
	elsif ($found_blank && /^(\S+)\s+(\S+)\s+(.*)/) {
		#next if ($donefile{$3}++);
		$mod = $1; $ver = $2;
		next if ($mod eq 'about');
		local @mod = split(/::/, $mod);
		if (@mod > 1) {
			local @cat = @mod[0 .. $#mod-1];
			if (!$donecat{join("::", @cat)}++) {
				push(@mods, { 'name' => \@cat,
					      'cat' => 1 } );
				}
			}
		push(@mods, { 'name' => \@mod,
			      'full' => $mod,
			      'ver' => $ver eq 'undef' ? '' : $ver } );
		}
	}
close(LIST);

# Display the current level of modules
$bgcolor = defined($gconfig{'cs_page'}) ? $gconfig{'cs_page'} : "ffffff";
$link = defined($gconfig{'cs_link'}) ? $gconfig{'cs_link'} : "0000ee";
$text = defined($gconfig{'cs_text'}) ? $gconfig{'cs_text'} : "000000";
@sel = split(/\0/, $in{'sel'});
&PrintHeader();
print <<EOF;
<html>
<head><title>$text{'cpan_title'}</title>
<script>
function sel(m)
{
window.opener.ifield.value = m;
window.close();
return false;
}
</script>
</head><body bgcolor=#$bgcolor link=#$link vlink=#$link text=#$text>
EOF
if ($in{'search'}) {
	# Search for modules matching some name
	print "<b>",&text('cpan_match', "<tt>$in{'search'}</tt>"),"</b><p>\n";
	print "<table width=100% cellpadding=1 cellspacing=1>\n";
	foreach $m (@mods) {
		if (!$m->{'cat'} && $m->{'full'} =~ /$in{'search'}/i) {
			$name = join("::",@{$m->{'name'}});
			print "<tr>\n";
			print "<td><a href='' onClick='sel(\"$name\")'><img src=images/mod.gif border=0></a></td>\n";
			print "<td><a href='' onClick='sel(\"$name\")'>",
				&html_escape($name),"</a></td>\n";
			print "<td align=right>",&html_escape($m->{'ver'}),"</td>\n";
			print "</tr>\n";
			$matches++;
			}
		}
	print "</table>\n";
	print "$text{'cpan_none'}<br>\n" if (!$matches);
	}
else {
	# Show module tree
	if (@sel) {
		print "<b>",&text('cpan_sel', join("::",@sel)),"</b><p>\n";
		}
	else {
		# Show search form
		print "<form action=cpan.cgi>\n";
		print "<input type=submit value='$text{'cpan_search'}'>\n";
		print "<input name=search size=15></form>\n";
		}
	print "<table width=100% cellpadding=1 cellspacing=1>\n";
	if (@sel) {
		local @up = @sel[0..$#sel-1];
		print "<tr>\n";
		print "<td><a href='cpan.cgi?",join("&",map { "sel=$_" } @up),"#",join("::",@sel),"'><img src=images/cat.gif border=0></a></td>\n";
		print "<td><a href='cpan.cgi?",join("&",map { "sel=$_" } @up),"#",join("::",@sel),"'>..</a></td>\n";
		print "</tr>\n";
		}
	MOD: foreach $m (@mods) {
		for($i=0; $i<@sel; $i++) {
			next MOD if ($sel[$i] ne $m->{'name'}->[$i]);
			}
		next if (scalar(@sel) != scalar(@{$m->{'name'}}-1));
		$name = join("::",@{$m->{'name'}});
		$pars = join("&",map { "sel=$_" } @{$m->{'name'}});
		print "<tr>\n";
		if ($m->{'cat'}) {
			print "<td><a name=$name><a href='cpan.cgi?$pars'><img src=images/cat.gif border=0></a></td>\n";
			print "<td><a href='cpan.cgi?$pars'>",&html_escape($name),"</a></td>\n";
			}
		else {
			print "<td><a href='' onClick='sel(\"$name\")'><img src=images/mod.gif border=0></a></td>\n";
			print "<td><a href='' onClick='sel(\"$name\")'>",&html_escape($name),"</a></td>\n";
			print "<td align=right>",&html_escape($m->{'ver'}),"</td>\n";
			}
		print "</tr>\n";
		}
	}
print "</table>\n";
print "</body></html>\n";


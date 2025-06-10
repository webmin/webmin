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

# Show page header and selection javascript
@sel = grep { /^[a-z0-9\-\_\:\.]+$/i } split(/\0/, $in{'sel'});
&popup_header($text{'cpan_title'});

print <<EOF;
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
	print "<b>",&text('cpan_match',
		"<tt>".&html_escape($in{'search'})."</tt>"),"</b><p>\n";
	print &ui_columns_start(undef, 100, 1);
	foreach $m (@mods) {
		if (!$m->{'cat'} && $m->{'full'} =~ /\Q$in{'search'}\E/i) {
			$name = join("::",@{$m->{'name'}});
			print &ui_columns_row([
				"<a href='' onClick='sel(\"$name\")'>".
				  "<img src=images/mod.gif border=0></a>",
				"<a href='' onClick='sel(\"$name\")'>".
				  &html_escape($name)."</a>",
				&html_escape($m->{'ver'}),
				]);
			$matches++;
			}
		}
	print &ui_columns_end();
	print "$text{'cpan_none'}<br>\n" if (!$matches);
	}
else {
	# Show module tree
	if (@sel) {
		print "<b>",&text('cpan_sel', join("::",@sel)),"</b><p>\n";
		}
	else {
		# Show search form
		print &ui_form_start("cpan.cgi");
		print &ui_submit($text{'cpan_search'});
		print &ui_textbox("search", undef, 20),&ui_form_end();
		}
	print &ui_columns_start(undef, 100, 1);
	if (@sel) {
		# Link to up one level
		local @up = @sel[0..$#sel-1];
		print &ui_columns_row([
			"<a href='cpan.cgi?".
			  join("&",map { "sel=$_" } @up),"#",join("::",@sel).
			  "'><img src=images/cat.gif border=0></a>",
			"<a href='cpan.cgi?".
			  join("&",map { "sel=$_" } @up)."#".
			  join("::",@sel)."'>..</a>",
			""
			]);
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
			# A category which can be opened
			print &ui_columns_row([
				"<a name=$name><a href='cpan.cgi?$pars'>".
				  "<img src=images/cat.gif border=0></a>",
				&ui_link("cpan.cgi?$pars",&html_escape($name)),
				""
				]);
			}
		else {
			# A module
			print &ui_columns_row([
				"<a href='' onClick='sel(\"$name\")'>".
				  "<img src=images/mod.gif border=0></a>",
				"<a href='' onClick='sel(\"$name\")'>".
				  &html_escape($name)."</a>",
				&html_escape($m->{'ver'}),
				], [ undef, undef, "align=right" ]);
			}
		}
	print &ui_columns_end();
	}
&popup_footer();


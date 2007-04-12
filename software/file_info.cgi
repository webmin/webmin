#!/usr/local/bin/perl
# file_info.cgi
# Display information about a file owned by the package management system

require './software-lib.pl';
&ReadParse();
$f = $in{'file'};
&ui_print_header(undef, $text{'file_title'}, "", "file_info");

$f =~ s/\/$//;
if ($f !~ /^\//) {
	# if the filename is not absolute, look for it
	foreach $p (split(/:/, $ENV{'PATH'})) {
		last if (&installed_file("$p/$f"));
		}
	}
else {
	# absolute path.. must exist in DB
	&installed_file($f);
	}

if (!%file) {
	print "<b>",&text('file_notfound', "<tt>$f</tt>"),"</b><p>\n";
	}
else {
	# display file info
	$nc = "width=10% nowrap";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'file_title'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td $nc><b>$text{'file_path'}</b></td>\n";
	print "<td colspan=3><font size=+1>$file{'path'}</font></td> </tr>\n";

	print "<tr> <td $nc><b>$text{'file_type'}</b></td>\n";
	print "<td>$type_map[$file{'type'}]</td>\n";

	if ($file{'type'} != 3 && $file{'type'} != 4) {
		print "<td $nc><b>$text{'file_perms'}</b></td>\n";
		print "<td>$file{'mode'}</td> </tr>\n";

		print "<tr> <td $nc><b>$text{'file_owner'}</b></td>\n";
		print "<td>$file{'user'}</td>\n";
		print "<td $nc><b>$text{'file_group'}</b></td>\n";
		print "<td>$file{'group'}</td> </tr>\n";

		if ($file{'type'} == 0) {
			print "<tr> <td $nc><b>$text{'file_size'}</b></td>\n";
			print "<td>$file{'size'}</td> </tr>\n";
			}
		}
	else {
		print "<td $nc><b>$text{'file_link'}</b></td>\n";
		print "<td>$file{'link'}</td> </tr>\n";
		}
	print "</table></tr> </tr></table><p>\n";

	# Show packages containing the file (usually only one)
	print &ui_columns_start([ $text{'file_pack'},
				  $text{'file_class'},
				  $text{'file_desc'} ], 100);
	@pkgs = split(/\s+/, $file{'packages'});
	@vers = split(/\s+/, $file{'versions'});
	$n = &list_packages(@pkgs);
	for($j=0; $j<@pkgs; $j++) {
		for($i=0; $i<$n; $i++) {
			next if ($vers[$i] &&
				 $packages{$i,'version'} ne $vers[$j] ||
				 $packages{$i,'name'} ne $pkgs[$j]);
			local @cols;
			push(@cols, "<a href=\"edit_pack.cgi?package=".
			      &urlize($pkgs[$j])."&version=".&urlize($vers[$j]).
			      "\">$pkgs[$j]</a>");
			$c = $packages{$i,'class'};
			push(@cols, $c || $text{'file_none'});
			push(@cols, $packages{$i,'desc'});
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	}

&ui_print_footer("", $text{'index_return'});


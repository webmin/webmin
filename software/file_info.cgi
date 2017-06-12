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
		last if (&installed_file("$p/$f") && %file);
		}
	}
else {
	# absolute path.. must exist in DB
	&installed_file($f);
	}

if (!%file) {
	print "<b>",&text('file_notfound',
			  "<tt>".&html_escape($f)."</tt>"),"</b><p>\n";
	}
else {
	# display file info
	$nc = "width=10% nowrap";
	print &ui_table_start($text{'file_title'}, "width=100%", 4);

	print &ui_table_row($text{'file_path'},
			    "<tt>".&html_escape($file{'path'})."</tt>", 3);

	print &ui_table_row($text{'file_type'},
			    $type_map[$file{'type'}]);

	if ($file{'type'} != 3 && $file{'type'} != 4) {
		print &ui_table_row($text{'file_perms'}, $file{'mode'});

		print &ui_table_row($text{'file_owner'}, $file{'user'});
		print &ui_table_row($text{'file_group'}, $file{'group'});

		if ($file{'type'} == 0) {
			print &ui_table_row($text{'file_size'}, $file{'size'});
			}
		}
	else {
		print &ui_table_row($text{'file_link'},
			"<tt>".&html_escape($file{'link'})."</tt>", 3);
		}
	print &ui_table_end();

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
			push(@cols, &ui_link("edit_pack.cgi?package=".
			      &urlize($pkgs[$j])."&version=".&urlize($vers[$j]), $pkgs[$j]) );
			$c = $packages{$i,'class'};
			push(@cols, $c || $text{'file_none'});
			push(@cols, $packages{$i,'desc'});
			print &ui_columns_row(\@cols);
			}
		}
	print &ui_columns_end();
	}

&ui_print_footer("", $text{'index_return'});


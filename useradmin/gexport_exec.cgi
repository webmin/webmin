#!/usr/local/bin/perl
# Actually output a group creation batch file

require './user-lib.pl';
&error_setup($text{'gexport_err'});
$access{'export'} || &error($text{'gexport_ecannot'});
&ReadParse();

# Validate inputs
if ($in{'to'}) {
	$access{'export'} == 2 || &error($text{'export_ecannot'});
	$in{'file'} =~ /^\/.+$/ || &error($text{'export_efile'});
	&is_under_directory($access{'home'}, $in{'file'}) ||
		&error($text{'export_efile2'});
	}
if ($in{'mode'} == 4) {
	$in{'gid'} =~ /^\d*$/ || &error($text{'gexport_egid'});
	$in{'gid2'} =~ /^\d*$/ || &error($text{'gexport_egid2'});
	}

# Open the output file
if ($in{'to'}) {
	&open_tempfile(OUT, ">$in{'file'}", 1) ||
		&error(&text('export_eopen', $!));
	$fh = "OUT";
	&ui_print_header(undef, $text{'gexport_title'}, "");
	}
else {
	print "Content-type: text/plain\n\n";
	$fh = "STDOUT";
	}

# Work out which groups are allowed and selected
@glist = &list_groups();
@glist = &list_allowed_groups(\%access, \@glist);
$faccess{'gedit_mode'} = $in{'mode'};
$faccess{'gedit'} = $in{'mode'} == 2 ? $in{'can'} :
		   $in{'mode'} == 3 ? $in{'cannot'} :
		   $in{'mode'} == 4 ? $in{'gid'} : "";
$faccess{'gedit2'} = $in{'mode'} == 4 ? $in{'gid2'} : "";
@glist = &list_allowed_groups(\%faccess, \@glist);

# Go through all allowed users
$count = 0;
foreach $g (@glist) {
	@line = ( $g->{'group'}, $g->{'pass'}, $g->{'gid'},
		  $g->{'members'} );
	if ($fh eq "STDOUT") {
		print $fh join(":", "create", @line),"\n";
		}
	else {
		&print_tempfile($fh, join(":", "create", @line),"\n");
		}
	$count++;
	}

if ($in{'to'}) {
	# All done
	&close_tempfile($fh);
	@st = stat($in{'file'});
	print "<p>",&text('export_done',
		  $count, "<tt>$in{'file'}</tt>", &nice_size($st[7])),"<p>\n";

	&ui_print_footer("", $text{'index_return'});
	}


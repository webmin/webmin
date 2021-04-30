#!/usr/local/bin/perl
# export_exec.cgi
# Actually output a user creation batch file

require './user-lib.pl';
&error_setup($text{'export_err'});
$access{'export'} || &error($text{'export_ecannot'});
&ReadParse();

# Validate inputs
if ($in{'to'}) {
	$access{'export'} == 2 || &error($text{'export_ecannot'});
	$in{'file'} =~ /^\/.+$/ || &error($text{'export_efile'});
	&is_under_directory($access{'home'}, $in{'file'}) ||
		&error($text{'export_efile2'});
	}
if ($in{'mode'} == 4) {
	$in{'uid'} =~ /^\d*$/ || &error($text{'export_euid'});
	$in{'uid2'} =~ /^\d*$/ || &error($text{'export_euid2'});
	}
elsif ($in{'mode'} == 5) {
	foreach $g (split(/\s+/, $in{'group'})) {
		&my_getgrnam($g) || &error(&text('export_egroup', $g));
		}
	}
elsif ($in{'mode'} == 8) {
	$in{'gid'} =~ /^\d*$/ || &error($text{'export_egid'});
	$in{'gid2'} =~ /^\d*$/ || &error($text{'export_egid2'});
	}

# Open the output file
if ($in{'to'}) {
	&open_tempfile(OUT, ">$in{'file'}", 1) ||
		&error(&text('export_eopen', $!));
	$fh = "OUT";
	&ui_print_header(undef, $text{'export_title'}, "");
	}
else {
	print "Content-type: text/plain\n\n";
	$fh = "STDOUT";
	}

# Work out which users are allowed and selected
@ulist = &list_users();
@ulist = &list_allowed_users(\%access, \@ulist);
$faccess{'uedit_mode'} = $in{'mode'};
$faccess{'uedit'} = $in{'mode'} == 2 ? $in{'can'} :
		   $in{'mode'} == 3 ? $in{'cannot'} :
		   $in{'mode'} == 4 ? $in{'uid'} :
		   $in{'mode'} == 8 ? $in{'gid'} :
		   $in{'mode'} == 5 ?
			join(" ", map { "".&my_getgrnam($_) }
			     split(/\s+/, $in{'group'})) : "";
$faccess{'uedit2'} = $in{'mode'} == 4 ? $in{'uid2'} :
		     $in{'mode'} == 8 ? $in{'gid2'} : undef;
$faccess{'uedit_sec'} = $in{'mode'} == 5 ? $in{'sec'} : undef;
@ulist = &list_allowed_users(\%faccess, \@ulist);

# Go through all allowed users
$count = 0;
$pft = $in{'pft'};
foreach $u (@ulist) {
	@line = ( $u->{'user'}, $u->{'pass'}, $u->{'uid'}, $u->{'gid'},
		  $u->{'real'}, $u->{'home'}, $u->{'shell'} );
	if ($pft == 1 || $pft == 6) {
		push(@line, $u->{'class'});
		push(@line, $u->{'change'});
		push(@line, $u->{'expire'});
		}
	elsif ($pft == 2) {
		push(@line, $u->{'min'}, $u->{'max'}, $u->{'warn'},
			    $u->{'inactive'}, $u->{'expire'});
		}
	elsif ($pft == 4) {
		local @flags;
		push(@flags, 'ADMIN') if ($u->{'admin'});
                push(@flags, 'ADMCHG') if ($u->{'admchg'});
                push(@flags, 'NOCHECK') if ($u->{'nocheck'});
		push(@line, $u->{'min'}, $u->{'max'},
			    $u->{'expire'}, join(" ", @flags));
		}
	elsif ($pft == 5) {
		push(@line, $u->{'min'}, $u->{'max'});
		}
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


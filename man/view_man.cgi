#!/usr/local/bin/perl
# view_man.cgi
# Display a single manual page

require './man-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'man_title'}, "");

if (&has_command($config{'man2html_path'})) {
	$ocmd = $in{'sec'} ? $config{'list_cmd_sect'}
			   : $config{'list_cmd'};
	}
else {
	$ocmd = $in{'sec'} ? $config{'man_cmd_sect'}
			   : $config{'man_cmd'};
	}
if ($config{'strip_letters'}) {
	$in{'sec'} =~ s/^(\d+).*$/$1/;
	}
&set_manpath($in{'opts'});

# Try various man commands, like :
# man -s 3x Foo, man -s 3x foo, man -s 3 Foo, man -s 3 foo
@sects = ( $in{'sec'} );
if ($in{'sec'} =~ /^(\d+)[^0-9]+$/) {
	push(@sects, $1);
	}
SECT: foreach $sec (@sects) {
	foreach $page ($in{'page'}, lc($in{'page'})) {
		$page =~ /\// && &error($text{'man_epath'});
		$qpage = quotemeta($page);
		$qsec = quotemeta($sec);
		$cmd = $ocmd;
		$cmd =~ s/PAGE/$qpage/;
		$cmd =~ s/SECTION/$qsec/;
		if ($< == 0) {
			$cmd = &command_as_user("nobody", 0, $cmd);
			}
		$out = &backquote_command($cmd." 2>&1", 1);
		if ($out !~ /^.*no manual entry/i && $out !~ /^.*no entry/i &&
		    $out !~ /^.*nothing appropriate/i) {
			# Found it
			$found++;
			last SECT;
			}
		}
	}
if (!$found) {
	print "<p><b>",&text('man_noentry',
		     "<tt>".&html_escape($in{'page'})."</tt>"),"</b><p>\n";
	}
else {
	if (&has_command($config{'man2html_path'})) {
		# Last line only
		@lines = split(/\r?\n/, $out);
		$out = $lines[$#lines];
                if ($out =~ /\(<--\s+(.*)\)/) {
                        # Output has cached file and original path
                        $out = $1;
                        }
		$out =~ s/ .*//;
		if( $out =~ /^.*\.gz/i ) {
			$cmd = "gunzip -c";
			}
		elsif ($out =~ /^.*\.(bz2|bz)/i) {
			$cmd = "bunzip2 -c";
			}
		else {
			$cmd = "cat";
			}
		$qout = quotemeta($out);
		$manout = &backquote_command("$config{'man2html_path'} -v 2>&1", 1);
		if ($manout =~ /Version:\s+([0-9\.]+)/i && $1 >= 3) {
			# New version uses a different syntax!
			$cmd .= " $qout | nroff -mman | $config{'man2html_path'} --cgiurl \"view_man.cgi?page=\\\${title}&sec=\\\${section}&opts=$in{'opts'}\" --bare";
			$out = &backquote_command("$cmd 2>&1", 1);
			}
		else {
			# Old version of man2html
			$cmd .= " $qout | $config{'man2html_path'} -H \"\" -M \"view_man.cgi\"";
			$out = &backquote_command("$cmd 2>&1", 1);
			$out =~ s/^.*Content-type:.*\n//i;
			$out =~ s/http:\/\///ig;
			$out =~ s/\?/\?sec=/ig;
			$out =~ s/\+/&opts=$in{'opts'}&page=/ig;
			$out =~ s/<HTML>.*<BODY>//isg;
			$out =~ s/<\/HTML>//ig;
			$out =~ s/<\/BODY>//ig;
			$out =~ s/<A HREF="file:[^"]+">([^<]+)<\/a>/$1/ig;
			$out =~ s/<A HREF="view_man.cgi">/<A HREF=\"\">/i;
			}
		&show_view_table(
			&text('man_header',
			      &html_escape($in{'page'}),
			      &html_escape($in{'sec'})),
			$out);
	} else {
		$out =~ s/.\010//g;
		$out =~ s/^(man:\s*)?(re)?formatting.*//i;
		&show_view_table(
			&text('man_header',
			      &html_escape($in{'page'}),
			      &html_escape($in{'sec'})),
			"<pre>".&html_escape($out)."</pre>");
		}
	}

&ui_print_footer("", $text{'index_return'});


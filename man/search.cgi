#!/usr/local/bin/perl
# search.cgi
# Search for manual pages, and display a list of matches or an exact page

require './man-lib.pl';
use Config;
&ReadParse();
$in{'for'} || &error($text{'search_efor'});

@for = split(/\s+/, $in{'for'});
@howto = split(/\s+/, $config{'howto_dir'});
@doc = split(/\s+/, $config{'doc_dir'});
foreach $s (split(/\0/, $in{'section'})) {
	if ($s =~ /^([^:]+):(.*)/) {
		$section{$1}++;
		$opts{$1} = $2;
		}
	else {
		$section{$s}++;
		}
	}
if ($in{'check'} && $config{'check'}) {
	@check = split(/\s+/, $config{'check'});
	foreach $s (keys %section) {
		delete($section{$s}) if (&indexof($s, @check) < 0);
		}
	}

if ($section{'doc'}) {
	# Look in the system documentation directory (usually /usr/doc)
	foreach $d (@doc) {
		push(@rv, map { [ $text{'search_doc'},
				   "view_doc.cgi?file=".&urlize($_->[0]),
				   substr($_->[0], length($d)+1),
				   $_->[1], 1 ] }
			     &find_contents($d, \@for,
					    $howto[0], 1, $in{'exact'}));
		}
	}
if ($section{'custom'}) {
	# Look in the custom documentation directory
	push(@rv, map { [ $text{'search_custom'},
			   "view_doc.cgi?file=".&urlize($_->[0]),
			   substr($_->[0], length($config{'custom_dir'})+1),
			   $_->[1], 1 ] }
		     &find_contents($config{'custom_dir'}, \@for,
				    $howto[0], 1, $in{'exact'}));
	}
if ($section{'howto'}) {
	# Look in the HOWTO directory
	foreach $h (@howto) {
		push(@rv, map { [ $text{'search_howto'},
			      "view_howto.cgi?file=".&urlize($_->[0]),
			      $_->[2], $_->[1], 2 ] }
		     &find_contents($h, \@for, undef, 0, $in{'exact'}));
		}
	@rv = grep { $_->[2] !~ /^index/i } @rv;
	}
if ($section{'kernel'}) {
	# Look in the linux kernel Documentation directory
	 push(@rv, map { [ $text{'search_kernel'},
			   "view_kernel.cgi?file=".&urlize($_->[0]),
			   substr($_->[0], length($config{'kernel_dir'})+1),
			   $_->[1], 1 ] }
		     &find_contents($config{'kernel_dir'}, \@for,
				    undef, 1, $in{'exact'}));
	}
if ($section{'kde'}) {
	# Look in the KDE documentation directory
	 push(@rv, map { [ $text{'search_kde'},
			   "view_kde.cgi?file=".&urlize($_->[0]),
			   substr($_->[0], length($config{'kde_dir'})+1),
			   $_->[1], 1 ] }
		     &find_contents($config{'kde_dir'}, \@for,
				    undef, 1, $in{'exact'}));
	}
if ($section{'perl'}) {
	if ($in{'exact'}) {
		# Check for an exact module name match
		local @f = $in{'and'} ? ( $for[0] ) : @for;
		foreach $f (@f) {
			chop($out = &backquote_command("$perl_doc -l ".quotemeta($f)." 2>/dev/null", 1));
			if ($out) {
				local $doc = &parse_perl_module($out);
				$doc->{'name'} =~ s/^\s*(\S+)\s+-\s+//;
				push(@rv, [ $text{'search_perl'},
					    "view_perl.cgi?mod=$f",
					    $f, $doc->{'name'}, 1 ]);
				}
			}
		}
	else {
		# Search the text of all perl modules
		foreach $d ($Config{'sitelib'}, $Config{'privlib'}) {
			&open_execute_command(FIND, "find $d -name '*.pm' -print", 1, 1);
			while($path = <FIND>) {
				chop($path);
				local $doc = &parse_perl_module($path);
				local ($any = 0, $all = 1);
				foreach $f (@for) {
					if ($doc->{'name'} !~ /$f/i &&
					    $doc->{'description'} !~ /$f/i) {
						$all = 0;
						}
					else {
						$any = 1;
						}
					}
				next if (!$all && $in{'and'} || !$any);

				$doc->{'name'} =~ s/^\s*(\S+)\s+-\s+//;
				local $modfile =
				   &backquote_command("$perl_doc -l ".quotemeta($doc->{'package'})." 2>/dev/null", 1);
				if ($doc->{'package'} && $modfile) {
					push(@rv, [ $text{'search_perl'},
					  "view_perl.cgi?mod=$doc->{'package'}",
					  $doc->{'package'}, $doc->{'name'},
					  1 ]);
					}
				}
			close(FIND);
			}
		}
	}
if ($section{'help'}) {
	# Look in the webmin module help pages
	opendir(DIR, $root_directory);
	foreach my $m (readdir(DIR)) {
		# Is this a module with help
		local $dir = "$root_directory/$m/help";
		next if (!-d $dir || $m =~ /^\./ || -l "$root_directory/$m");
		local %minfo = &get_module_info($m);
		next if (!%minfo || !&check_os_support(\%minfo));

		# Check the help pages
		local @pfx;
		opendir(DIR2, $dir);
		while($f = readdir(DIR2)) {
			push(@pfx, $1) if ($f =~ /^([^\.]+)\.html$/);
			}
		closedir(DIR2);
		HELP: foreach $p (&unique(@pfx)) {
			local $file = &help_file($m, $p);
			open(HELP, $file);
			local @st = stat($file);
			read(HELP, $help, $st[7]);
			close(HELP);
			if ($help =~ /<header>([^<]+)<\/header>/) {
				$header = $1;
				}
			else { next; }
			$help =~ s/<include\s+(\S+)>/inchelp($1, $m)/ge;
			$help =~ s/<[^>]+>//g;
			local $matches = 0;
			if ($in{'exact'}) {
				# Just check header
				foreach $f (@for) {
					$matches++ if ($header =~ /\Q$f\E/i);
					}
				}
			else {
				# Check entire body
				foreach $f (@for) {
					$matches++ if ($help =~ /\Q$f\E/i);
					}
				}
			if (($in{'and'} && $matches == @for) ||
			    (!$in{'and'} && $matches)) {
				push(@rv, [ $text{'search_help'},
					    "/help.cgi/$m/$p?x=1",
					    "$m/$p", $header,
					    2 ]);
				}
			}
		}
	}
if ($section{'man'}) {
	# Look in manual pages (searches are never exact)
	$cmd = $config{'search_cmd'};
	map { s/\\/\\\\/g; s/'/\\'/g; } @for;
	if ($in{'and'}) {
		local $qm = quotemeta($for[0]);
		$cmd =~ s/PAGE/$qm/;
		}
	else {
		local $fors = join(" ", map { quotemeta($_) } @for);
		$cmd =~ s/PAGE/$fors/;
		}
	&set_manpath($opts{'man'});
	&open_execute_command(MAN, $cmd, 1, 1);
	while(<MAN>) {
		$got .= $_;
		if (/(([^,\s]+).*)\s*\((\S+)\)\s+-\s+(.*)/ &&
		    !$done{$2,$3}++) {
			local ($page, $sect, $desc) = ($1, $3, $4);
			if ($page =~ /^(\S+)\s*\[(.+)\]/) {
				$page = "$1 $2";
				}
			local @pp = split(/[\s+,]/, $page);
			map { s/\((\S+)\)//; } @pp;

			# Keywords must be page name or desc
			local ($any = 0, $all = 1, $exact);
			foreach $f (@for) {
				if ($desc !~ /$f/i && $page !~ /$f/i &&
				    &indexof($f, @pp) < 0) {
					$all = 0;
					}
				else {
					$any = 1;
					}
				$exact++ if (&indexof($f, @pp) >= 0);
				}
			next if (!$all && $in{'and'} || !$any);

			push(@rv, [ $text{'search_man'},
				    "view_man.cgi?page=$pp[0]&sec=$3&opts=".
				    $opts{'man'}, "$pp[0] ($sect)", $desc,
				    $exact ? 4 : 3 ]);
			}
		}
	close(MAN);
	}
if ($section{'google'}) {
	# Try to call the Google search engine, once for general results and
	# once for doxfer
	local %doneurl;
	foreach my $host ("", "host:doxfer.webmin.com") {
		local ($grv, $error);
		local $j = $in{'and'} ? ' and ' : ' or ';
		&http_download($google_host, $google_port, "$google_page?q=".
			&urlize(join($j, @for)." ".$host).
			  "&sourceid=webmin&num=20",
		        \$grv, \$error);
		if (!$error) {
			# Parse the results
			while($grv =~ /(<p[^>]*>|<div[^>]*>|<h3[^>]*>)<a[^>]+href=([^>]+)>([\000-\377]+?)<\/a>([\000-\377]*)$/i) {
				$grv = $4;
				local ($url = $2, $desc = $3);
				$url =~ s/^"(.*)".*$/$1/;
				$url =~ s/^'(.*)'.*$/$1/;
				$desc =~ s/<\/?b>//g;
				local $matches = 0;
				foreach $f (@for) {
					$matches++ if ($desc =~ /\Q$f\E/i);
					}
				next if ($url =~ /^\/search/);	# More results
				if ($url =~ /^\/url\?(.*)/) {
					# Extract real URL
					local $qs = $1;
					if ($qs =~ /q=([^&]+)/) {
						$url = &un_urlize("$1");
						}
					}
				next if ($doneurl{$url}++);
				$msg = $host ? $text{'search_doxfer'}
					     : $text{'search_google'};
				if (!$in{'exact'} ||
				    ($in{'and'} && $matches == @for) ||
				    (!$in{'and'} && $matches)) {
					push(@rv, [ $msg, $url, length($url) > 60 ? substr($url, 0, 60)."..." : $url, $desc, $host ? 10 : 0.5 ]);
					}
				}
			}
		}
	}

if (@rv == 1 && !$in{'check'}) {
	# redirect to the exact page
	&redirect($in{'exact'} ? $rv[0]->[1]
			       : "$rv[0]->[1]&for=".&urlize($in{'for'}));
	exit;
	}

# Display search results
$for = join($in{'and'} ? " and " : " or ",
	    map { "<tt>".&html_escape($_)."</tt>" } @for);
&ui_print_header(&text('search_for', $for), $text{'search_title'}, "");
if (@rv) {
	#@rv = sort { $b->[4] <=> $a->[4] } @rv;
	@rv = sort { &ranking($b) <=> &ranking($a) } @rv;
	print &ui_columns_start([ $text{'search_file'},
				  $text{'search_type'},
				  $text{'search_desc'} ], 100);
	foreach $r (@rv) {
		local @cols;
		if ($r->[1] =~ /^(http|ftp|https):/) {
			push(@cols, &ui_link($r->[1], &html_escape($r->[2]), undef, "target=_blank") );
			}
		else {
			push(@cols, &ui_link($r->[1]."&for=".&urlize($in{'for'}), &html_escape($r->[2]) ) );
			}
		push(@cols, $r->[0]);
		push(@cols, &html_escape($r->[3]));
		print &ui_columns_row(\@cols, [ undef, "nowrap", undef ]);
		}
	print &ui_columns_end();
	}
else {
	print "<p><b>",&text('search_none', "<tt>".&html_escape($in{'for'})."</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

# find_contents(directory, &strings, [exclude], [descend], [nameonly])
# Find some string in a directory of files
sub find_contents
{
opendir(DIR, $_[0]);
local @f = readdir(DIR);
closedir(DIR);
local @rv;
foreach $f (@f) {
	next if ($f =~ /^\./);
	local $p = "$_[0]/$f";
	next if ($p eq $_[2]);
	if (-d $p) {
		# go into subdirectory
		push(@rv, &find_contents($p, $_[1], $_[2], $_[3], $_[4]))
			if ($_[3]);
		}
	else {
		# Skip non-text or HTML files
		local $ff = $f;
		$ff =~ s/\.(gz|bz|bz2)$//i;
		next if ($ff !~ /\.(txt|htm|html|doc)$/ &&
			 $ff =~ /\.[A-Za-z0-9]+$/);
		next if ($ff =~ /(^makefile$)|(^core$)/i);

		local $matches = 0;
		foreach $s (@{$_[1]}) {
			$matches++ if ($p =~ /\Q$s\E/i);
			}
		if ($_[4]) {
			# just compare filename
			if ($in{'and'} && $matches == @{$_[1]} ||
			    !$in{'and'} && $matches) {
				local ($desc, $data) = &read_doc_file($p);
				if ($desc !~ /^#!/ && $desc !~ /^#\%/) {
					push(@rv, [ $p, $desc, $f, $matches ]);
					}
				}
			}
		else {
			# compare file contents
			local ($desc, $data) = &read_doc_file($p);
			local $dmatches = 0;
			foreach $s (@{$_[1]}) {
				$dmatches++ if ($data =~ /\Q$s\E/i);
				}
			if (($in{'and'} && $dmatches == @{$_[1]} ||
			     !$in{'and'} && $dmatches) &&
			    $desc !~ /^#!/ && $desc !~ /^#\%/) {
				push(@rv, [ $p, $desc, $f, $matches ]);
				}
			}
		}
	}
return @rv;
}

# read_doc_file(filename)
# Returns desc, data
sub read_doc_file
{
local ($two, $first, $title, $data);
open(FILE, $_[0]);
read(FILE, $two, 2);
local $qm = quotemeta($_[0]);
if ($two eq "\037\213") {
	close(FILE);
	&open_execute_command(FILE, "gunzip -c $qm", 1, 1);
	}
elsif ($two eq "BZ") {
	close(FILE);
	&open_execute_command(FILE, "bunzip2 -c $qm", 1, 1);
	}
seek(FILE, 0, 0);
while(<FILE>) {
	$data .= $_;
	if (/[A-Za-z0-9]/ && !/\$\S+:/ && !$first) {
		chop($first = $_);
		$first =~ s/.\010//g;
		}
	}
close(FILE);
if ($data =~ /<\s*title\s*>([\000-\177]{0,200})<\s*\/\s*title\s*>/i) {
	$title = $1;
	}
return ($title ? $title : $first =~ /<.*>/ ? undef : $first, $data);
}

# parse_perl_module(file)
sub parse_perl_module
{
local (%doc, $inside);
open(MOD, $_[0]);
while(<MOD>) {
	if (/^\s*package\s+(\S+)\s*;/ && !$doc{'package'}) {
		$doc{'package'} = $1;
		}
	elsif (/^=head1\s+(\S+)/i) {
		$inside = $1;
		}
	elsif (/^=cut/i) {
		undef($inside);
		}
	elsif ($inside) {
		$doc{lc($inside)} .= $_;
		}
	}
close(MOD);
return \%doc;
}

# inchelp(path, module)
sub inchelp
{
local $inc;
local $ipath = &help_file($_[1], $_[0]);
open(INC, $ipath) || return "<i>".&text('search_einclude', $_[0])."</i><br>\n";
local @st = stat(INC);
read(INC, $inc, $st[7]);
close(INC);
return $inc;
}

sub ranking
{
local ($name = 0, $desc = 0);
foreach $f (@for) {
	$desc++ if ($_[0]->[3] =~ /$f/i);
	$name++ if ($_[0]->[1] =~ /$f/i);
	}
return $name ? $_[0]->[4] * 10 :
       $desc ? $_[0]->[4] :
	       $_[0]->[4] / 10;
}


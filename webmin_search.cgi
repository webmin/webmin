#!/usr/local/bin/perl
# Search Webmin modules and help pages and text and config.info

BEGIN { push(@INC, ".."); };
use WebminCore;

&init_config();
&ReadParse();

$prod = &get_product_name();
$ucprod = ucfirst($prod);
&ui_print_unbuffered_header(
	undef, &text('wsearch_title', $ucprod), "", undef, 0, 1);

# Validate search text
$re = $in{'search'};
if ($re !~ /\S/) {
	&error($text{'wsearch_esearch'});
	}
$re =~ s/^\s+//;
$re =~ s/\s+$//;

# Work out this Webmin's URL base
$urlhost = $ENV{'HTTP_HOST'};
if ($urlhost !~ /:/) {
	$urlhost .= ":".$ENV{'SERVER_PORT'};
	}
$urlbase = ($ENV{'HTTPS'} eq 'ON' ? 'https://' : 'http://').$urlhost;

# Start printing dots 
print &text('wsearch_searching', "<i>".&html_escape($re)."</i>"),"\n";

# Search module names and add to results list
@rv = ( );
@mods = sort { $b->{'longdesc'} cmp $a->{'longdesc'} }
	     grep { !$_->{'clone'} } &get_available_module_infos();
foreach $m (@mods) {
	if ($m->{'desc'} =~ /\Q$re\E/i) {
		# Module description match
		push(@rv, { 'mod' => $m,
			    'rank' => 10,
			    'type' => 'mod',
			    'link' => $m->{'dir'}.'/',
			    'text' => $m->{'desc'} });
		}
	elsif ($m->{'dir'} =~ /\Q$re\E/i) {
		# Module directory match
		push(@rv, { 'mod' => $m,
			    'rank' => 12,
			    'type' => 'dir',
			    'link' => $m->{'dir'}.'/',
			    'text' => $urlbase."/".$m->{'dir'}."/" });
		}
	&print_search_dot();
	}

# Search module configs and their help pages
foreach $m (@mods) {
	%access = &get_module_acl(undef, $m);
	next if ($access{'noconfig'});
	$file = $prod eq 'webmin' ? "$m->{'dir'}/config.info"
				  : "$m->{'dir'}/uconfig.info";
	%info = ( );
	@info_order = ( );
	&read_file($file, \%info, \@info_order);
	foreach $o (@lang_order_list) {
		&read_file("$file.$o", \%info);
		}
	$section = undef;
	foreach $c (@info_order) {
		@p = split(/,/, $info{$c});
		if ($p[1] == 11) {
			$section = $c;
			}
		if ($p[0] =~ /\Q$re\E/i) {
			# Config description matches
			push(@rv, { 'mod' => $m,
				    'rank' => 8,
				    'type' => 'config',
				    'link' => "config.cgi?module=$m->{'dir'}&".
					     "section=".&urlize($section)."#$c",
				    'text' => $p[0],
				  });
			}
		$hfl = &help_file($mod->{'dir'}, "config_".$c);
		($title, $help) = &help_file_match($hfl);
		if ($help) {
			# Config help matches
			push(@rv, { 'mod' => $m,
                                    'rank' => 6,
				    'type' => 'help',
				    'link' => "help.cgi/$m->{'dir'}/config_".$c,
				    'desc' => &text('wsearch_helpfor', $p[0]),
				    'text' => $help,
				    'cgis' => [ "/config.cgi?".
					        "module=$m->{'dir'}&section=".
						&urlize($section)."#$c" ],
				   });
			}
		}
	&print_search_dot();
	}

# Search other help pages
%lang_order_list = map { $_, 1 } @lang_order_list;
foreach $m (@mods) {
	$helpdir = &module_root_directory($m->{'dir'})."/help";
	%donepage = ( );
	opendir(DIR, $helpdir);
	foreach $f (sort { length($b) <=> length($a) } readdir(DIR)) {
		next if ($f =~ /^config_/);	# For config help, already done

		# Work out if we should grep this help page - don't do the same
		# page twice for different languages
		$grep = 0;
		if ($f =~ /^(\S+)\.([^\.]+)\.html$/) {
			($page, $lang) = ($1, $2);
			if ($lang_order_list{$lang} && !$donepage{$page}++) {
				$grep = 1;
				}
			}
		elsif ($f =~ /^(\S+)\.html$/) {
			$page = $1;
			if (!$donepage{$page}++) {
				$grep = 1;
				}
			}

		# If yes, search it
		if ($grep) {
			($title, $help) = &help_file_match("$helpdir/$f");
			if ($title) {
				my @cgis = &find_cgi_text(
					[ "hlink\\(.*'$page'",
					  "hlink\\(.*\"$page\"",
					  "header\\([^,]+,[^,]+,[^,]+,\\s*\"$page\"",
					  "header\\([^,]+,[^,]+,[^,]+,\\s*'$page'",
					], $m, 1);
				push(@rv, { 'mod' => $m,
					    'rank' => 6,
					    'type' => 'help',
					    'link' => "help.cgi/$m->{'dir'}/$page",
					    'desc' => $title,
					    'text' => $help,
					    'cgis' => \@cgis });
				}
			}
		&print_search_dot();
		}
	closedir(DIR);
	}

# Then do text strings
%gtext = &load_language("");
MODULE: foreach $m (@mods) {
	%mtext = &load_language($m->{'dir'});
	foreach $k (keys %mtext) {
		next if ($gtext{$k});	# Skip repeated global strings
		$mtext{$k} =~ s/\$[0-9]//g;
		if ($mtext{$k} =~ /\Q$re\E/i) {
			# Find CGIs that use this text
			my @cgis = &find_cgi_text(
				[ "\$text{'$k'}",
				  "\$text{\"$k\"}",
				  "\$text{$k}",
				  "&text('$k'",
				  "&text(\"$k\"" ], $m);
			if (@cgis) {
				push(@rv, { 'mod' => $m,
					    'rank' => 4,
					    'type' => 'text',
					    'text' => $mtext{$k},
					    'cgis' => \@cgis });
				}
			}
		}
	&print_search_dot();
	}

print &text('wsearch_found', scalar(@rv)),"<p>\n";

# Sort results by relevancy
# XXX can do better?
@rv = sort { $b->{'rank'} <=> $a->{'rank'} ||
	     lc($a->{'mod'}->{'desc'}) cmp lc($b->{'mod'}->{'desc'}) } @rv;

# Show in table
if (@rv) {
	print &ui_columns_start(
		[ $text{'wsearch_htext'}, $text{'wsearch_htype'},
		  $text{'wsearch_hmod'}, $text{'wsearch_hcgis'} ], 100);
	foreach my $r (@rv) {
		$hi = &highlight_text($r->{'text'});
		if ($r->{'link'}) {
			$hi = "<a href='$r->{'link'}'>$hi</a>";
			}
		@links = ( );
		foreach my $c (@{$r->{'cgis'}}) {
			($cmod, $cpage) = split(/\//, $c);
			($cpage, $cargs) = split(/\?/, $cpage);
			$ctitle = &cgi_page_title($cmod, $cpage) || $cpage;
			if ($r->{'mod'}->{'installed'}) {
				$cargs ||= &cgi_page_args($cmod, $cpage);
				}
			else {
				# For modules that aren't installed, linking
				# to a CGI is likely useless
				$cargs ||= "none";
				}
			if ($cargs eq "none") {
				push(@links, $ctitle);
				}
			else {
				$cargs = "?".$cargs if ($cargs ne '' &&
							$cargs !~ /^(\/|%2F)/);
				push(@links,
				   "<a href='$cmod/$cpage$cargs'>$ctitle</a>");
				}
			}
		if (@links > 2) {
			@links = ( @links[0..1], "..." );
			}
		print &ui_columns_row([
			$hi,
			$text{'wsearch_type_'.$r->{'type'}},
			"<a href='$r->{'mod'}->{'dir'}/'>$r->{'mod'}->{'desc'}</a>",
			&ui_links_row(\@links),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>",&text('wsearch_enone',
		"<tt>".&html_escape($re)."</tt>"),"</b><p>\n";
	}

&ui_print_footer();

# highlight_text(text, [length])
# Returns text with the search term bolded, and truncated to 60 characters
sub highlight_text
{
local ($str, $len) = @_;
$len ||= 50;
local $hlen = $len / 2;
$str =~ s/<[^>]*>//g;
if ($str =~ /(.*)(\Q$re\E)(.*)/i) {
	local ($before, $match, $after) = ($1, $2, $3);
	if (length($before) > $hlen) {
		$before = "...".substr($before, length($before)-$hlen);
		}
	if (length($after) > $hlen) {
		$after = substr($after, 0, $hlen)."...";
		}
	$str = $before."<b>".&html_escape($match)."</b>".$after;
	}
return $str;
}

# find_cgi_text(&regexps, module, re-mode)
# Returns the relative URLs of CGIs that matches some regexps, in the given
# module. Does not include those that don't call some header function, as
# they cannot be linked to normally
sub find_cgi_text
{
local ($res, $m, $remode) = @_;
local $mdir = &module_root_directory($m);
local @rv;
foreach my $f (glob("$mdir/*.cgi")) {
	local $found = 0;
	local $header = 0;
	open(CGI, $f);
	LINE: while(my $line = <CGI>) {
		if ($line =~ /(header|ui_print_header|ui_print_unbuffered_header)\(/) {
			$header++;
			}
		foreach my $r (@$res) {
			if (!$remode && index($line, $r) >= 0 ||
			    $remode && $line =~ /$r/) {
				$found++;
				last LINE;
				}
			}
		}
	close(CGI);
	if ($found && $header) {
		local $url = $f;
		$url =~ s/^\Q$root_directory\E\///;
		push(@rv, $url);
		}
	}
return @rv;
}

# help_file_match(file)
# Returns the title if some help file matches the current search
sub help_file_match
{
local ($f) = @_;
local $data = &read_file_contents($f);
local $title;
if ($data =~ /<header>([^<]*)<\/header>/) {
	$title = $1;
	}
$data =~ s/\s+/ /g;
$data =~ s/<p>/\n\n/gi;
$data =~ s/<br>/\n/gi;
$data =~ s/<[^>]+>//g;
if ($data =~ /\Q$re\E/i) {
	return ($title, $data);
	}
return ( );
}

# cgi_page_title(module, cgi)
# Given a CGI, return the text for its page title, if possible
sub cgi_page_title
{
local ($m, $cgi) = @_;
local $data = &read_file_contents(&module_root_directory($m)."/".$cgi);
local $rv;
if ($data =~ /(ui_print_header|ui_print_unbuffered_header)\([^,]+,[^,]*(\$text{'([^']+)'|\$text{"([^"]+)"|\&text\('([^']+)'|\&text\("([^"]+)")/) {
	# New header function, with arg before title
	local $msg = $3 || $4 || $5 || $6;
	local %mtext = &load_language($m);
	$rv = $mtext{$msg};
	}
elsif ($data =~ /(^|\s)header\(\s*(\$text{'([^']+)'|\$text{"([^"]+)"|\&text\('([^']+)'|\&text\("([^"]+)")/) {
	# Old header function
	local $msg = $3 || $4 || $5 || $6;
	local %mtext = &load_language($m);
	$rv = $mtext{$msg};
	}
if ($cgi eq "index.cgi" && !$rv) {
	# If no title was found for an index.cgi, use module title
	local %minfo = &get_module_info($m);
	$rv = $minfo{'desc'};
	}
return $rv;
}

# cgi_page_args(module, cgi)
# Given a module and CGI name, returns a string of URL parameters that can be
# used for linking to it. Returns "none" if parameters are needed, but cannot
# be determined.
sub cgi_page_args
{
local ($m, $cgi) = @_;
local $mroot = &module_root_directory($m);
if (-r "$mroot/cgi_args.pl") {
	# Module can tell us what args to use
	&foreign_require($m, "cgi_args.pl");
	$args = &foreign_call($m, "cgi_args", $cgi);
	if (defined($args)) {
		return $args;
		}
	}
if ($cgi eq "index.cgi") {
	# Index page is always safe to link to
	return undef;
	}
# Otherwise check if it appears to parse any args
local $data = &read_file_contents($mroot."/".$cgi);
if ($data =~ /(ReadParse|ReadParseMime)\(/) {
	return "none";
	}
return undef;
}

# print_search_dot()
# Print one dot per second
sub print_search_dot
{
local $now = time();
if ($now > $last_print_search_dot) {
	print ". ";
	$last_print_search_dot = $now;
	}
}


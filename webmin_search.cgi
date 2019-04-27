#!/usr/local/bin/perl
# Search Webmin modules and help pages and text and config.info

$trust_unknown_referers = 1;
BEGIN { push(@INC, "."); };
use WebminCore;

&init_config();
do "$root_directory/webmin-search-lib.pl";
&ReadParse();

$prod = &get_product_name();
$ucprod = ucfirst($prod);
&ui_print_unbuffered_header(undef,
	&html_escape($in{'title'}) || &text('wsearch_title', $ucprod), "", undef, 0, 1);

# Validate search text
$re = $in{'search'};
if ($re !~ /\S/) {
	&error($text{'wsearch_esearch'});
	}
$re =~ s/^\s+//;
$re =~ s/\s+$//;

# Find modules to search
$mods = undef;
if ($in{'mod'}) {
	$mods = [ ];
	my %infos = map { $_->{'dir'}, $_ } &get_all_module_infos();
	foreach my $mn (split(/\0/, $in{'mod'})) {
		my $minfo = $infos{$mn};
		push(@$mods, $minfo) if ($minfo);
		}
	}

# Do the search
print &text('wsearch_searching', "<i>".&html_escape($re)."</i>"),"\n";
@rv = &search_webmin($re, \&print_search_dot, $mods);
print &text('wsearch_found', scalar(@rv)),"<p>\n";

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
				# Don't print it two times, it's very confusing
				if (grep(/^$ctitle$/, @links)) {
				    my $i = 0;
				    my $c = scalar @links;
				    $i++ until $links[$i] eq $ctitle or $i == $c;
				    splice(@links, $i, 1);
					}
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
			&ui_links_row(\@links, 1),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>",&text('wsearch_enone',
		"<tt>".&html_escape($re)."</tt>"),"</b><p>\n";
	}

&ui_print_footer();

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


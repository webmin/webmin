#!/usr/local/bin/perl
# Search Webmin modules and help pages and text and config.info

do './web-lib.pl';
&init_config();
do './ui-lib.pl';
&ReadParse();

$prod = &get_product_name();
$ucprod = ucfirst($prod);
&ui_print_header(undef, &text('wsearch_title', $ucprod), "", undef, 0, 1);

$re = $in{'search'};
if ($re !~ /\S/) {
	&error($text{'wsearch_esearch'});
	}
$re =~ s/^\s+//;
$re =~ s/\s+$//;

# Search module names first
$count = 0;
@mods = grep { !$_->{'clone'} } &get_available_module_infos();
foreach $m (@mods) {
	if ($m->{'desc'} =~ /\Q$re\E/i || $m->{'dir'} =~ /\Q$re\E/i) {
		&match_row(
			$m,
			"<a href='$m->{'dir'}/'>$m->{'desc'}</a>",
			$text{'wsearch_mtitle'},
			undef,
			0,
			);
		}
	}

# Then do module configs
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
			&match_row(
			    $m,
			    "<a href='config.cgi?module=$m->{'dir'}&".
			     "section=".&urlize($section)."#$c'>$p[0]</a>",
			    $text{'wsearch_config_'.$prod},
			    $p[0],
			    1,
			    );
			}
		}
	}

# Then do help pages
%lang_order_list = map { $_, 1 } @lang_order_list;
foreach $m (@mods) {
	$helpdir = &module_root_directory($m->{'dir'})."/help";
	%donepage = ( );
	opendir(DIR, $helpdir);
	foreach $f (sort { length($b) <=> length($a) } readdir(DIR)) {
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
			$data = &read_file_contents("$helpdir/$f");
			if ($data =~ /<header>([^<]*)<\/header>/) {
				$title = $1;
				}
			else {
				$title = $f;
				}
			$data =~ s/\s+/ /g;
			$data =~ s/<p>/\n\n/gi;
			$data =~ s/<br>/\n/gi;
			$data =~ s/<[^>]+>//g;
			if ($data =~ /\Q$re\E/) {
				&match_row(
				    $m,
				    &hlink($title, $page, $m->{'dir'}),
				    $text{'wsearch_help'},
				    $data,
				    1,
				    );
				}
			}
		}
	closedir(DIR);
	}

# Then do text strings
foreach $m (@mods) {
	%mtext = &load_language($m->{'dir'});
	foreach $k (keys %mtext) {
		if ($mtext{$k} =~ /\Q$re\E/i) {
			&match_row(
			    $m,
			    "<a href='$m->{'dir'}/'>$m->{'desc'}</a>",
			    $text{'wsearch_text'},
			    $mtext{$k},
			    0,
			    );
			}
		}
	}

if (!$count) {
	print "<b>",&text('wsearch_enone', "<tt>$re</tt>"),"</b><p>\n";
	}

&ui_print_footer();

# Returns text with the search term bolded, and truncated to 60 characters
sub highlight_text
{
local ($str, $len) = @_;
$len ||= 90;
local $hlen = $len / 2;
if ($str =~ /(.*)(\Q$re\E)(.*)/i) {
	local ($before, $match, $after) = ($1, $2, $3);
	if (length($before) > $hlen) {
		$before = "...".substr($before, length($before)-$hlen);
		}
	if (length($after) > $hlen) {
		$after = substr($after, 0, $hlen)."...";
		}
	$str = $before."<b>".$match."</b>".$after;
	}
return $str;
}

sub match_row
{
local ($m, $link, $what, $text, $module_link) = @_;
print "<font size=+1>$link</font>\n";
if ($module_link) {
	print " (".&text('wsearch_inmod',
		    	 "<a href='$m->{'dir'}/'>$m->{'desc'}</a>").")";
	}
print "<br>\n";
if ($text) {
	print &highlight_text($text),"<br>\n";
	}
print "<font color=#4EBF37>$m->{'desc'} - $what</font><br>&nbsp;<br>\n";
$count++;
}


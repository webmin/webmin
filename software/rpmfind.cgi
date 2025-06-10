#!/usr/local/bin/perl
# rpmfind.cgi
# Display a search window for rpmfind.net

require './software-lib.pl';
&ReadParse();

$rpmfind_host = "rpmfind.net";
$rpmfind_port = 80;
$rpmfind_page = "/linux/rpm2html/search.php?query=";

&header();
print <<EOF;
<script>
function sel(m)
{
window.opener.ifield.value = m;
window.close();
return false;
}
</script>
EOF

# Search form
print &ui_form_start("rpmfind.cgi");
print &ui_submit($text{'rpm_search'});
print &ui_textbox("search", $in{'search'}, 20);
print &ui_form_end();

if ($in{'search'}) {
	# Call the rpmfind.net website to get matches
	print &ui_hr();
	$out = "";
	&http_download($rpmfind_host, $rpmfind_port,
		       $rpmfind_page.&urlize($in{'search'}), \$out);
	while($out =~ /<tr[^>]*>.*?<td[^>]*>([^<]*)<\/td>.*?<td[^>]*>([^<]*)<\/td>.*?((ftp|http|https):[^>]+\.rpm).*?<\/tr>([\000-\377]*)/i) {
		local $pkg = { 'url' => $3,
			       'dist' => $2,
			       'desc' => $1 };
		$out = $5;
		$pkg->{'source'}++ if ($pkg->{'url'} =~ /\.src\.rpm$/ ||
				       $pkg->{'url'} =~ /\.srpm$/);
		if ($pkg->{'url'} =~ /\/(([^\/]+)-([^\-\/]+)-([^-\/]+).([^-\/]+)\.rpm)$/) {
			$pkg->{'file'} = $1;
			$pkg->{'prefix'} = $2;
			$pkg->{'version'} = $3;
			$pkg->{'release'} = $4;
			$pkg->{'arch'} = $5;
			if ($pkg->{'version'} =~ /^(\d+)\.([0-9\.]+)$/){
				local ($v1 = $1, $v2 = $2);
				$v2 =~ s/\.//g;
				$pkg->{'version'} = "$v1.$v2";
				}
			}
		elsif ($pkg->{'file'} =~ /\/([^\/]+)$/) {
			$pkg->{'file'} = $1;
			}
		push(@rv, $pkg);
		}

	# Show the search results
	@rv = grep { !$_->{'source'} } @rv;
	@rv = sort { local $vc = $b->{'version'} <=> $a->{'version'};
		     local $rc = $b->{'version'} <=> $a->{'version'};
		     return $vc ? $vc : $rc } @rv;
	if (@rv) {
		print "<table width=100%>\n";
		print &ui_columns_start([ $text{'rpm_findrpm'},
					  $text{'rpm_finddistro'},
					  $text{'rpm_finddesc'} ], 100);
		foreach $r (@rv) {
			print &ui_columns_row([
				&ui_link("#", $r->{'file'}, undef, "onClick='sel(\"$r->{'url'}\");'"),
				$r->{'dist'},
				$r->{'desc'}
				]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'rpm_none'}</b> <p>\n";
		}
	}

&ui_print_footer();


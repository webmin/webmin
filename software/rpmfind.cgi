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

print "<form action=rpmfind.cgi>\n";
print "<input type=submit value='$text{'rpm_search'}'>\n";
print "<input name=search size=20 value='$in{'search'}'><br>\n";
print "</form><hr>\n";

if ($in{'search'}) {
	# Call the rpmfind.net website
	local $temp = &transname();
	&http_download($rpmfind_host, $rpmfind_port,
		       $rpmfind_page.&urlize($in{'search'}), $temp);
	local $out = `cat $temp`;
	unlink($temp);
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

	@rv = grep { !$_->{'source'} } @rv;
	@rv = sort { local $vc = $b->{'version'} <=> $a->{'version'};
		     local $rc = $b->{'version'} <=> $a->{'version'};
		     return $vc ? $vc : $rc } @rv;
	if (@rv) {
		print "<table width=100%>\n";
		foreach $r (@rv) {
			print "<tr>\n";
			print "<td><a href='' onClick='sel(\"$r->{'url'}\")'>",
			      "$r->{'file'}</a></td>\n";
			print "<td>$r->{'dist'}</td>\n";
			print "<td>$r->{'desc'}</td>\n";
			print "</tr>\n";
			}
		print "</table>\n";
		}
	else {
		print "<b>$text{'rpm_none'}</b> <p>\n";
		}
	}

&ui_print_footer();


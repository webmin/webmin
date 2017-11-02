#!/usr/local/bin/perl
# edit_host.cgi
# Show details of a managed host, and all the packages on it

require './cluster-software-lib.pl';
&foreign_require("servers", "servers-lib.pl");
&ReadParse();
&ui_print_header(undef, $text{'host_title'}, "", "edit_host");

@hosts = &list_software_hosts();
($host) = grep { $_->{'id'} eq $in{'id'} } @hosts;
$server = &foreign_call("servers", "get_server", $in{'id'});
@packages = @{$host->{'packages'}};

# Show host details
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'host_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'host_name'}</b></td>\n";
if ($server->{'id'}) {
	$h = $server->{'realhost'} || $server->{'host'};
	printf &ui_link("/servers/link.cgi/%s/","%s")."</td>\n",
		$server->{'id'}, $server->{'desc'} ? "$server->{'desc'} ($h:$server->{'port'})" : "$h:$server->{'port'}";
	}
else {
	print "<td><a href=/>$text{'this_server'}</a></td>\n";
	}

if ($server->{'id'}) {
	print "<td><b>$text{'host_type'}</b></td> <td>\n";
	foreach $t (@servers::server_types) {
		print $t->[1] if ($t->[0] eq $server->{'type'});
		}
	print "</td>\n";
	}
print "</tr>\n";

print "<tr> <td><b>$text{'host_count'}</b></td>\n";
printf "<td>%d</td>\n", scalar(@packages);

print "<td><b>$text{'host_os'}</b></td>\n";
print "<td>$host->{'real_os_type'} $host->{'real_os_version'}</td> </tr>\n";

print "<tr> <td><b>$text{'host_system'}</b></td>\n";
$system = $host->{'package_system'} || $software::config{'package_system'};
print "<td>",uc($system),"</td>\n";

print "</tr>\n";

print "</table></td></tr></table>\n";

# Show delete and refresh buttons
print "<table width=100%><tr>\n";
print "<form action=delete_host.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<td><input type=submit value='$text{'host_delete'}'></td>\n";
print "</form>\n";

print "<form action=refresh.cgi>\n";
print "<input type=hidden name=id value=$in{'id'}>\n";
print "<td align=right><input type=submit value='$text{'host_refresh'}'></td>\n";
print "</form>\n";
print "</tr></table>\n";

# Show tree of packages
$heir{""} = "";
foreach $c (sort { $a cmp $b } &unique(map { $_->{'class'} } @packages)) {
	if (!$c) { next; }
	@w = split(/\//, $c);
	$p = join('/', @w[0..$#w-1]);
	if (!defined($heir{$p})) {
		$pp = join('/', @w[0..$#w-2]);
		$heir{$pp} .= "$p\0";
		}
	$heir{$p} .= "$c\0";
	$hasclasses++;
	}

# get the current open list
%heiropen = map { $_, 1 } &get_heiropen($in{'id'});
$heiropen{""}++;

# traverse the hierarchy
$spacer = "&nbsp;"x3;
print &ui_hr();
print &ui_subheading($text{'host_installed'});
print "<table width=100%>\n";
&traverse("", 0);
print "</table>\n";
if ($hasclasses) {
	print &ui_link("closeall.cgi?id=$in{'id'}",$text{'host_close'}),"\n";
	print &ui_link("openall.cgi?id=$in{'id'}",$text{'host_open'}),"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});

sub traverse
{
local($s, $act, $i);
print "<tr> <td>", $spacer x $_[1];
if ($_[0]) {
	print "<a name=\"$_[0]\"></a>\n";
	$act = $heiropen{$_[0]} ? "close" : "open";
	print "<a href=\"$act.cgi?id=$in{'id'}&what=",&urlize($_[0]),"\">";
	$_[0] =~ /([^\/]+)$/;
	print "<img border=0 src=images/$act.gif></a>&nbsp; $1</td>\n",
	}
else { print "<img src=images/close.gif> <i>$text{'host_all'}</i></td>\n"; }
print "<td><br></td> </tr>\n";
if ($heiropen{$_[0]}) {
	# print sub-folders followed by packages
	foreach $i (@packages) {
		if ($i->{'class'} eq $_[0]) {
			print "<tr> <td>", $spacer x ($_[1]+1);
			print "<img border=0 src=images/pack.gif></a>&nbsp;\n";
			print "<a href=\"edit_pack.cgi?package=",
			     &urlize($i->{'name'}),"\">$i->{'name'}</a></td>\n";
			print "<td>$i->{'desc'}</td>\n";
			print "</tr>\n";
			}
		}
	foreach $s (&unique(split(/\0+/, $heir{$_[0]}))) {
		&traverse($s, $_[1]+1);
		}
	}
}


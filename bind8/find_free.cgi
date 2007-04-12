#!/usr/local/bin/perl
# find_free.cgi
# Looks for free IP numbers
# by Ivan Andrian, <ivan.andrian@elettra.trieste.it>, 11/07/2000

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'view'} ne '') {
	$conf = $conf->[$in{'view'}]->{'members'};
	}
$zconf = $conf->[$in{'index'}]->{'members'};
$type = &find("type", $zconf)->{'value'};
$file = &find("file", $zconf)->{'value'};
$dom = $conf->[$in{'index'}]->{'value'};
if (!$access{'findfree'}) {&error($text{'findfree_nofind'})};
$desc = &text('findfree_header', &arpa_to_ip($dom));
&ui_print_header($desc, &text('findfree_title'), "");

my $cf=1;
if (@in == 2) {
	&find_ips ($in{'index'}, $in{'from'});
}
elsif (@in == 3) {
	&find_ips ($in{'index'}, $in{'from'}, $in{'to'});
}
elsif (@in == 4) {
	$cf=$in{'cf'};
	&find_ips ($in{'index'}, $in{'from'}, $in{'to'}, $in{'cf'});
}
else {
	&find_ips ($in{'index'});
}

if (@in >= 3) { #we need to do the search!

   @recs = &read_zone_file($file, $dom);
   @recs = grep { ($_->{'type'} eq 'A') || ($_->{'type'} eq 'PTR')} @recs;
   my $freeXXXcount=0;
   my $freemaccount=0;
   if (@recs) {
	@recs = &sort_records(@recs);
	my %frecs = &build_iprange($in{'from'}, $in{'to'});

	for($i=0; $i<@recs; $i++) {
		my $hip;	# host IP
		my $hname;	# hostname
		
		if ($recs[$i]->{'type'} eq 'A') {
			$hip=$recs[$i]->{'values'}->[0]; 		# IP no. in 'values' field
			$hname=$recs[$i]->{'name'};				# name   in 'name' field
		}
		else {
			$hip=&arpa_to_ip($recs[$i]->{'name'});	# IP no. in 'name' field
			$hname=$recs[$i]->{'values'}->[0];		# name   in 'values' field
		}
		
#	print "evaluating ", $hip, " ", $hname, "...<BR>"; #debug
		
		if($cf & ($hname=~ /^free.*/) & exists $frecs{$hip}) {	# 'freeXXX' hostnames are free IP's!
			# update
#	print "&nbsp;&nbsp;updating: ",$hip, "... <BR>"; #debug
			$frecs{$hip}->{'ttl'}=$recs[$i]->{'ttl'};
			$frecs{$hip}->{'name'}=$hname;
			$freeXXXcount++;
			if($hname=~ /^freemac.*/) {$freemaccount++;}
		}
		else {
#	print "&nbsp;&nbsp;deleting: ",$hip, "... <BR>"; #debug
			delete $frecs{$hip};
		}
	}
	
	

	my @frecs=sort ffree_ip_sort_func values %frecs; 
	my $mid = int((@frecs+1)/2);
	print "<P align = \"center\"><STRONG>Found <BIG>" . @frecs . "</BIG> free IP number" . (@frecs==1?"\n":"s\n");
	if ($cf) {
		print " (<BIG>$freeXXXcount</BIG> ". ($freeXXXcount==1?" is":"are") .
				" <EM>`freeXXX'</EM>" .
				" of which <BIG>$freemaccount</BIG> ". ($freemaccount==1?" is":"are") . 
				" <EM>`freemac'</EM>)" ;
	print "</STRONG></P>\n";
	}
	print "<table width=100%><tr><td width=50% valign=top>\n";
	&frecs_table(@frecs[0 .. $mid-1]);
	print "</td><td width=50% valign=top>\n";
	if ($mid < @frecs) { &frecs_table(@frecs[$mid .. $#frecs]); }
	print "</td></tr></table><p>\n";
	print "<p>\n";

    } # if(@recs)
} # if(@in >= 3)

&ui_print_footer("edit_$type.cgi?index=$in{'index'}&view=$in{'view'}",
	$text{'recs_return'});

# build_iprange(fromIP, toIP)
# Returns a list of IP numbers from fromIP to toIP
sub build_iprange
{
$_[0] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
my @from = ($1, $2, $3, $4);
return @from if (@from != 4); #I want a correct IPv4 #
$_[1] =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
my @to = ($1, $2, $3, $4);
return @to if (@to != 4);

for ($i=0;$i<4;$i++) {
	$from[$i]=$from[$i]==0?1:$from[$i];
	$to[$i]=$to[$i]==255?254:$to[$i];
}

my %frecs;

for ($byte0=$from[0]; $byte0<=$to[0]; $byte0++) {
	for ($byte1=$byte0==$from[0]?$from[1]:1;
			$byte1<=(($byte0==$to[0]?$to[1]:254));
			$byte1++) {
		##print "================<BR>";
		for ($byte2=($byte0==$from[0])&&($byte1==$from[1])?$from[2]:1;
				$byte2<=(($byte0==$to[0])&&($byte1==$to[1])?$to[2]:254);
				$byte2++) {
			##print "----------------<BR>";
			for ($byte3=($byte0==$from[0])&&($byte1==$from[1])&&($byte2==$from[2])?$from[3]:1;
					$byte3<=(($byte0==$to[0])&&($byte1==$to[1])&&($byte2==$to[2])?$to[3]:254);
					$byte3++) {
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'ip'}="$byte0.$byte1.$byte2.$byte3";
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'ttl'}=$text{'default'};
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'name'}='';
				##push(@frecs, "$byte0.$byte1.$byte2.$byte3");
				##print "$byte0.$byte1.$byte2.$byte3<BR>";
			} #for $byte3
		} #for $byte2
	} #for $byte1
} #for $byte0

return %frecs;
} # sub build_iprange












# find_ips (zoneindex, from_ip, to_ip, consider_freeXX_names)
# Display a form for searching for free IP nos
sub find_ips
{
print "<form action=find_free.cgi>\n";
print "<input type=hidden name=index value='$_[0]'>\n";
print "<input type=hidden name=view value='$in{'view'}'>\n";

print "<table border>\n";
print "<tr $tb><td><b>$text{'findfree_sopt'}</b></td> </tr>\n";
print "<tr $cb><td><table>\n";

print "<tr> <td><b>$text{'findfree_IPrange'}</b></td>\n";
print "<td><b>$text{'findfree_from'}</b></td>\n";
if (@_ >= 2) { # there is a "from" field on the URL
	print "<td> <input name=from value=\"$_[1]\" size=30></td> </tr>\n";
	}
else {
	print "<td> <input name=from value=\"\" size=30></td> </tr>\n";
	}

print "<tr> <td>&nbsp;</td>\n";
print "<td><b>$text{'findfree_to'}</b></td>\n";
if (@_ >= 3) { # there is a "to" field on the URL
	print "<td> <input name=to value=\"$_[2]\" size=30></td> </tr>\n";
	}
else {
	print "<td> <input name=to value=\"\" size=30></td> </tr>\n";
	}

print "<tr> <td colspan=3 nowrap><b>$text{'findfree_cf'}</b>\n";

$cfy=$cf?'checked':'';
$cfn=(!$cf)?'checked':'';

print " &nbsp; <input type=radio name=cf value=1 $cfy> $text{'yes'}\n";
print "<input type=radio name=cf value=0 $cfn> $text{'no'}</td></tr>\n";

print "<tr colspan=3><td><input type=submit value=\"$text{'findfree_search'}\"></td></tr>\n";
print "</table></td></tr></table></form>\n";

} #	end of find_ips










# frecs_table(array_of_freerecords)
sub frecs_table
{
print "<table border width=100%>\n";
print "<tr $tb> <td><b>", $text{'recs_addr'},"</b></td>",
	"<td><b>$text{'recs_ttl'}</b></td>\n",
	"<td><b>$text{'recs_name'}</b></td>\n",
	"</tr>\n";

for($i=0; $i<@_; $i++) {
	$r = $_[$i];
	print "<tr $cb> <td>$r->{'ip'}</td>\n",
	"<td>",$r->{'ttl'} ? $r->{'ttl'} : $text{'default'},"</td>\n",
	"<td>",$r->{'name'}?$r->{'name'}:'&nbsp;',"</td>\n",
	"</tr>\n";
	}
	print "</table>\n";
}




sub ffree_ip_sort_func
{
$a->{'ip'} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
local ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
$b->{'ip'} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
return	$a1 < $1 ? -1 :
	$a1 > $1 ? 1 :
	$a2 < $2 ? -1 :
	$a2 > $2 ? 1 :
	$a3 < $3 ? -1 :
	$a3 > $3 ? 1 :
	$a4 < $4 ? -1 :
	$a4 > $4 ? 1 : 0;
}


#EOF

#!/usr/local/bin/perl
# find_free.cgi
# Looks for free IP numbers
# by Ivan Andrian, <ivan.andrian@elettra.trieste.it>, 11/07/2000
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();

my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
my $file = $zone->{'file'};
my $type = $zone->{'type'};

if (!$access{'findfree'}) {&error($text{'findfree_nofind'})};
my $desc = &text('findfree_header', &arpa_to_ip($dom));
&ui_print_header($desc, &text('findfree_title'), "",
		 undef, undef, undef, undef, &restart_links($zone));

&find_ips($in{'zone'}, $in{'from'}, $in{'to'}, $in{'cf'});

if ($in{'from'} && $in{'to'}) {
   # Do the search
   my @allrecs = &read_zone_file($file, $dom);
   my @recs = grep { ($_->{'type'} eq 'A') || ($_->{'type'} eq 'PTR')} @allrecs;
   my @gens = grep { $_->{'generate'} } @allrecs;
   foreach my $g (@gens) {
        my ($start, $end, $skip);
	my @gv = @{$g->{'generate'}};
	if ($gv[0] =~ /^(\d+)-(\d+)\/(\d+)$/) {
		$start = $1; $end = $2; $skip = $3;
		}
	elsif ($gv[0] =~ /^(\d+)-(\d+)$/) {
		$start = $1; $end = $2; $skip = 1;
		}
	else { next; }
	for(my $i=$start; $i<=$end; $i+=$skip) {
		my $lhs = $gv[1];
		$lhs =~ s/\$\$/\0/g;
		$lhs =~ s/\$/$i/g;
		$lhs =~ s/\0/\$/g;
		my $lhsfull = $lhs =~ /\.$/ ? $lhs :
			    $dom eq "." ? "$lhs." : "$lhs.$dom";

		my $rhs = $gv[3];
		$rhs =~ s/\$\$/\0/g;
		$rhs =~ s/\$/$i/g;
		$rhs =~ s/\0/\$/g;
		my $rhsfull = &check_ipaddress($rhs) ? $rhs :
			   $rhs =~ /\.$/ ? $rhs :
			    $dom eq "." ? "$rhs." : "$rhs.$dom";
		push(@recs, { 'name' => $lhsfull,
			      'values' => [ $rhsfull ],
			      'type' => $gv[2],
			      'class' => 'IN' });
		}
	}

   my $freeXXXcount=0;
   my $freemaccount=0;
   if (@recs) {
	@recs = &sort_records(@recs);
	my %frecs = &build_iprange($in{'from'}, $in{'to'});

	for(my $i=0; $i<@recs; $i++) {
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
		
		if($in{'cf'} & ($hname=~ /^free.*/) & exists $frecs{$hip}) {	# 'freeXXX' hostnames are free IP's!
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
	
	
        # Show a message
	my @frecs=sort ffree_ip_sort_func values %frecs; 
	print "<b>",&text('findfree_msg', scalar(@frecs)),"\n";
	if ($in{'cf'}) {
		print &text('findfree_msg2', $freeXXXcount, $freemaccount),"\n";
		}
	print "...</b><p>\n";

	# Show all the IPs
	&frecs_table(@frecs);

    } # if(@recs)
} # if(@in >= 3)

&ui_print_footer("edit_$type.cgi?zone=$in{'zone'}&view=$in{'view'}",
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

for (my $i=3;$i>=0;$i--) {
	my $e = 0;
	if ($from[$i] == 0) {
		$from[$i] = 1;
		$e++;
		}
	if ($to[$i] == 255) {
		$to[$i] = 254;
		$e++;
		}
	last if ($e);
	}

my %frecs;

for (my $byte0=$from[0]; $byte0<=$to[0]; $byte0++) {
	for (my $byte1=$byte0==$from[0]?$from[1]:1;
			$byte1<=(($byte0==$to[0]?$to[1]:254));
			$byte1++) {
		for (my $byte2=($byte0==$from[0])&&($byte1==$from[1])?$from[2]:1;
				$byte2<=(($byte0==$to[0])&&($byte1==$to[1])?$to[2]:254);
				$byte2++) {
			for (my $byte3=($byte0==$from[0])&&($byte1==$from[1])&&($byte2==$from[2])?$from[3]:1;
					$byte3<=(($byte0==$to[0])&&($byte1==$to[1])&&($byte2==$to[2])?$to[3]:254);
					$byte3++) {
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'ip'}="$byte0.$byte1.$byte2.$byte3";
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'ttl'}=$text{'default'};
				$frecs{"$byte0.$byte1.$byte2.$byte3"}->{'name'}='';
			} #for $byte3
		} #for $byte2
	} #for $byte1
} #for $byte0

return %frecs;
} # sub build_iprange

# find_ips (zonename, from_ip, to_ip, consider_freeXX_names)
# Display a form for searching for free IP nos
sub find_ips
{
print &ui_form_start("find_free.cgi");
print &ui_hidden("zone", $_[0]);
print &ui_hidden("view", $in{'view'});
print &ui_table_start($text{'findfree_sopt'}, undef, 2);

# Range start
print &ui_table_row($text{'findfree_fromip'},
	&ui_textbox("from", $_[1], 20));

# Range end
print &ui_table_row($text{'findfree_toip'},
	&ui_textbox("to", $_[2], 20));

# Handle freeXXX hostnames?
print &ui_table_row($text{'findfree_cf'},
	&ui_yesno_radio("cf", $_[3]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'findfree_search'} ] ]);
}

# frecs_table(array_of_freerecords)
sub frecs_table
{
print &ui_grid_table(
	[ map { &ui_link("edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=A&newvalue=$_->{'ip'}", $_->{'ip'}) } @_ ],
	4, 100, [ "width=25%", "width=25%", "width=25%", "width=25%" ]);
}

sub ffree_ip_sort_func
{
$a->{'ip'} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)/;
my ($a1, $a2, $a3, $a4) = ($1, $2, $3, $4);
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


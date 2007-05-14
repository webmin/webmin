#!/usr/local/bin/perl
# raid_form.cgi
# Display a form for creating a raid device

require './raid-lib.pl';
&foreign_require("mount", "mount-lib.pl");
&foreign_require("lvm", "lvm-lib.pl");
&ReadParse();
$conf = &get_raidtab();

# Display headers
$max = 0;
foreach $c (@$conf) {
	if ($c->{'value'} =~ /md(\d+)$/ && $1 >= $max) {
		$max = $1+1;
		}
	}
&ui_print_header(undef, $text{'create_title'}, "");
$raid = { 'value' => "/dev/md$max",
	  'members' => [ { 'name' => 'raid-level',
			   'value' => $in{'level'} },
			 { 'name' => 'persistent-superblock',
			   'value' => 1 }
		       ] };

# Find available partitions
$disks = &find_free_partitions(undef, 1, 1);
if (!$disks) {
	print "<p><b>$text{'create_nodisks'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<form action=create_raid.cgi>\n";
print "<input type=hidden name=idx value='$in{'idx'}'>\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'create_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";

print "<tr> <td><b>$text{'create_device'}</b></td>\n";
print "<td><tt>$raid->{'value'}</tt></td> </tr>\n";
print "<input type=hidden name=device value='$raid->{'value'}'>\n";

$lvl = &find_value('raid-level', $raid->{'members'});
print "<tr> <td><b>$text{'create_level'}</b></td>\n";
print "<td>",$lvl eq 'linear' ? $text{'linear'}
			      : $text{"raid$lvl"},"</td> </tr>\n";
print "<input type=hidden name=level value='$lvl'>\n";

$super = &find_value('persistent-superblock', $raid->{'members'});
print "<tr> <td><b>$text{'create_super'}</b></td>\n";
printf "<td><input name=super type=radio value=1 %s> %s\n",
	$super ? 'checked' : '', $text{'yes'};
printf "<input name=super type=radio value=0 %s> %s</td> </tr>\n",
	$super ? '' : 'checked', $text{'no'};

if ($lvl >= 5) {
	$parity = &find_value('parity-algorithm', $raid->{'members'});
	print "<tr> <td><b>$text{'create_parity'}</b></td>\n";
	print "<td><select name=parity>\n";
	foreach $a ('', 'left-asymmetric', 'right-asymmetric',
		    'left-symmetric', 'right-symmetric') {
		printf "<option value='%s' %s>%s\n",
			$a, $parity eq $a ? 'selected' : '',
			$a ? $a : $text{'default'};
		}
	print "</select></td> </tr>\n";
	}

$chunk = &find_value('chunk-size', $raid->{'members'});
print "<tr> <td><b>$text{'create_chunk'}</b></td>\n";
print "<td><select name=chunk>\n";
for($i=4; $i<=4096; $i*=2) {
	printf "<option value=%d %s>%d kB\n",
		$i, $chunk == $i ? 'selected' : '', $i;
	}
print "</select></td> </tr>\n";

# Display partitions in raid, spares and parity
print "<tr> <td valign=top><b>$text{'create_disks'}</b></td>\n";
print "<td><select name=disks multiple size=4>\n";
print $disks;
print "</select></td> </tr>\n";

if ($lvl >= 4) {
	print "<tr> <td valign=top><b>$text{'create_spares'}</b></td>\n";
	print "<td><select name=spares multiple size=4>\n";
	print $disks;
	print "</select></td> </tr>\n";
	}

if ($lvl == 4 && $raid_mode ne 'mdadm') {
	print "<tr> <td valign=top><b>$text{'create_pdisk'}</b></td>\n";
	print "<td><select name=pdisk>\n";
	print "<option value='' selected>$text{'create_auto'}\n";
	print $disks;
	print "</select></td> </tr>\n";
	}

print "<tr> <td><b>$text{'create_force'}</b></td>\n";
print "<td><input type=radio name=force value=1> $text{'yes'}\n";
print "<input type=radio name=force value=0 checked> $text{'no'}\n";
print "</td> </tr>\n";

print "</table></td></tr></table>\n";

print "<input type=submit value='$text{'create'}'></form>\n";

&ui_print_footer("", $text{'index_return'});


#!/usr/local/bin/perl
# save_gsync.cgi
# Save default quotas for groups

require './quota-lib.pl';
&ReadParse();
$access{'ro'} && &error($text{'suser_efs'});
$access{'default'} && &can_edit_filesys($in{'filesys'}) ||
	&error($text{'ssync_ecannot'});
grep { $_->[0] eq $in{'filesys'} } &list_filesystems() or &error($text{'suser_efs'});
$bsize = &block_size($in{'filesys'});
&lock_file("$module_config_directory/config");
@fields = qw(sblocks hblocks sfiles hfiles);
@limits = map { /blocks$/ ? &quota_parse($_, $bsize) :
			    $in{$_."_def"} ? 0 : $in{$_} } @fields;
$v = join(' ', @limits);
# All zeroes remove the automatic quota.
if ($v ne "0 0 0 0") {
	for (my $i = 0; $i < @fields; $i++) {
		&check_quota_limit($fields[$i], $limits[$i]);
		}
	}
$k = "gsync_$in{'filesys'}";
if ($v eq "0 0 0 0") { delete($config{$k}); }
else { $config{$k} = $v; }
&write_file("$module_config_directory/config", \%config);
&unlock_file("$module_config_directory/config");
&webmin_log("sync", "group", $in{'filesys'}, \%in);
&redirect("list_groups.cgi?dir=".&urlize($in{'filesys'}));


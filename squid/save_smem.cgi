#!/usr/local/bin/perl
# save_smem.cgi
# Save simple memory usage options

require './squid-lib.pl';
$access{'musage'} || &error($text{'emem_ecannot'});
&ReadParse();
&lock_file($config{'squid_conf'});
$conf = &get_config();
$whatfailed = $text{'smem_ftsmo'};

if ($squid_version < 2) {
	&save_opt("cache_mem", \&check_size, $conf);
	&save_opt("cache_swap", \&check_size, $conf);
	}
else {
	&save_opt_bytes("cache_mem", $conf);
	&save_opt("fqdncache_size", \&check_size, $conf);
	}
if ($squid_version < 2) {
	&save_opt("maximum_object_size", \&check_obj_size, $conf);
	}
else {
	&save_opt_bytes("maximum_object_size", $conf);
	}
&save_opt("ipcache_size", \&check_size, $conf);

if ($in{'cache_dir_def'}) {
	&save_directive($conf, "cache_dir", [ ]);
	}
else {
	for($i=0; defined($dir = $in{"cache_dir_$i"}); $i++) {
		if ($squid_version >= 2.4) {
			$lv1 = $in{"cache_lv1_$i"}; $lv2 = $in{"cache_lv2_$i"};
			$size = $in{"cache_size_$i"};
			$type = $in{"cache_type_$i"};
			$opts = $in{"cache_opts_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			&check_error(\&check_dir, $dir);
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $type, $dir, $size,
						   $lv1, $lv2, $opts ] });
			}
		elsif ($squid_version >= 2.3) {
			$lv1 = $in{"cache_lv1_$i"}; $lv2 = $in{"cache_lv2_$i"};
			$size = $in{"cache_size_$i"};
			$type = $in{"cache_type_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			&check_error(\&check_dir, $dir);
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $type, $dir, $size,
						   $lv1, $lv2 ] });
			}
		elsif ($squid_version >= 2) {
			$lv1 = $in{"cache_lv1_$i"}; $lv2 = $in{"cache_lv2_$i"};
			$size = $in{"cache_size_$i"};
			next if (!$dir && !$lv1 && !$lv2 && !$size);
			&check_error(\&check_dir, $dir);
			&check_error(\&check_dirsize, $size);
			&check_error(\&check_dircount, $lv1);
			&check_error(\&check_dircount, $lv2);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $dir, $size, $lv1, $lv2 ] });
			}
		else {
			next if (!$dir);
			&check_error(\&check_dir, $dir);
			push(@chd, { 'name' => 'cache_dir',
				     'values' => [ $dir ] });
			}
		}
	if (!@chd) {
		&error($text{'scache_emsg0'});
		}
	&save_directive($conf, "cache_dir", \@chd);
	}
if ($squid_version < 2) {
	&save_opt("swap_level1_dirs", \&check_dircount, $conf);
	&save_opt("swap_level2_dirs", \&check_dircount, $conf);
	&save_opt("store_avg_object_size", \&check_objsize, $conf);
	}
else {
	&save_opt_bytes("store_avg_object_size", $conf);
	}
&save_opt("store_objects_per_bucket", \&check_bucket, $conf);

&flush_file_lines();
&unlock_file($config{'squid_conf'});
&webmin_log("mem", undef, undef, \%in);
&redirect("");

sub check_size
{
return $_[0] =~ /^\d+$/ ? undef : &text('smem_emsg1',$_[0]);
}

sub check_high
{
return $_[0] =~ /^\d+$/ && $_[0] > 0 && $_[0] <= 100
		? undef : &text('smem_emsg2',$_[0]);
}

sub check_low
{
return $_[0] =~ /^\d+$/ && $_[0] > 0 && $_[0] <= 100
		? undef : &text('smem_emsg3',$_[0]);
}

sub check_obj_size
{
return $_[0] =~ /^\d+$/ ? undef : &text('smem_emsg4',$_[0]);
}


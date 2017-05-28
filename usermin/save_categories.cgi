#!/usr/local/bin/perl
# save_categories.cgi

require './usermin-lib.pl';
$access{'categories'} || &error($text{'acl_ecannot'});
&get_usermin_miniserv_config(\%miniserv);
&read_file("$miniserv{'root'}/lang/en", \%utext);
&read_file("$miniserv{'root'}/ulang/en", \%utext);
&ReadParse();
&error_setup($text{'categories_err'});

# Save built-in categories
foreach $t (keys %utext) {
	$t =~ s/^category_// || next;
	$field = $t || "other";
	if (!$in{$field."_def"}) {
		$in{$field} ||
			&error(&text('categories_edesc', $t ? $t : 'other'));
		$catnames{$t} = $in{$field};
		}
	}

# Save custom categories
for($i=0; defined($in{"cat_$i"}); $i++) {
	if ($in{"cat_$i"} && $in{"desc_$i"}) {
		$realcat{$in{"cat_$i"}} &&
			&error(&text('categories_ecat', $in{"cat_$i"}));
		$catnames{$in{"cat_$i"}} = $in{"desc_$i"};
		}
	}

&lock_file("$config{'usermin_dir'}/webmin.catnames");
&write_file("$config{'usermin_dir'}/webmin.catnames", \%catnames);
&unlock_file("$config{'usermin_dir'}/webmin.catnames");
&webmin_log("categories", undef, undef, \%in);
&flush_modules_cache();
&redirect("");

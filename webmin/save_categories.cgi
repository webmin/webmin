#!/usr/local/bin/perl
# save_categories.cgi

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'categories_err'});

# Save built-in categories
foreach $t (keys %text) {
	$t =~ s/^category_// || next;
	$field = $t || "other";
	if (!$in{$field."_def"}) {
		$in{$field} || &error(&text('categories_edesc', $t || 'other'));
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

# Write out the file
$file = "$config_directory/webmin.catnames";
$file .= ".".$in{'lang'} if ($in{'lang'});
&lock_file($file);
&write_file($file, \%catnames);
&unlock_file($file);
&webmin_log("categories", undef, $in{'lang'}, \%in);
&flush_webmin_caches();
&redirect("index.cgi?refresh=1");
